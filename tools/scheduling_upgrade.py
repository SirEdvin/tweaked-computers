#!/usr/bin/env python3
"""Mixed scheduling migration from a hash-pinned, function-capable old archive."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import zipfile

from monitor_upgrade import version_candidate
from smoke import cold_phase

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def candidate_archive(source, output, baseline_version):
    with zipfile.ZipFile(source) as z:
        info = json.loads(z.read(next(n for n in z.namelist() if n.endswith('/info.json') and n.count('/') == 1)))
    current = tuple(map(int, info['version'].split('.')))
    baseline = tuple(map(int, baseline_version.split('.')))
    assert current >= baseline, 'candidate predates the rollback archive'
    if current > baseline:
        return source, None
    private_version = '.'.join(map(str, (*baseline[:2], baseline[2] + 1)))
    return version_candidate(source, output, private_version), private_version


def install_fixture(source, output, payload):
    output.mkdir(parents=True)
    target = output / source.name
    with zipfile.ZipFile(source) as src, zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as dst:
        prefix = next(n[:-len('info.json')] for n in src.namelist() if n.endswith('/info.json') and n.count('/') == 1)
        hook = prefix + 'tests/monitor_upgrade_engine.lua'
        assert hook in src.namelist() and b'tc-buffer-upgrade' in src.read(prefix + 'control.lua')
        for entry in src.infolist():
            dst.writestr(copy.copy(entry), payload if entry.filename == hook else src.read(entry.filename))
    with zipfile.ZipFile(source) as src, zipfile.ZipFile(target) as dst:
        assert src.namelist() == dst.namelist()
        assert [n for n in src.namelist() if src.read(n) != dst.read(n)] == [hook]
    return target


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--factorio', required=True, type=Path)
    ap.add_argument('--baseline', required=True, type=Path)
    ap.add_argument('--baseline-sha256', required=True)
    ap.add_argument('--archive', required=True, type=Path)
    ap.add_argument('--output', required=True, type=Path)
    args = ap.parse_args()
    assert digest(args.baseline) == args.baseline_sha256
    assert subprocess.check_output([str(args.factorio), '--version'], text=True).startswith('Version: 2.1.23 ')
    folder = args.output.resolve()
    assert not folder.exists() and not folder.is_relative_to(ROOT)
    folder.mkdir(parents=True)
    with zipfile.ZipFile(args.archive) as z:
        prefix = next(n[:-len('info.json')] for n in z.namelist() if n.endswith('/info.json') and n.count('/') == 1)
        payload = z.read(prefix + 'tests/scheduling_upgrade_engine.lua')
    baseline = install_fixture(args.baseline, folder / 'baseline-test', payload)
    with zipfile.ZipFile(args.baseline) as z:
        baseline_info = json.loads(z.read(next(n for n in z.namelist() if n.endswith('/info.json') and n.count('/') == 1)))
    versioned, private_version = candidate_archive(args.archive, folder / 'candidate-version', baseline_info['version'])
    candidate = install_fixture(versioned, folder / 'candidate-test', payload)
    summary = {'baseline_sha256': digest(args.baseline), 'source_archive_sha256': digest(args.archive),
               'fixture_sha256': hashlib.sha256(payload).hexdigest(), 'baseline_test_sha256': digest(baseline),
               'candidate_test_sha256': digest(candidate), 'private_test_version': private_version,
               'test_only_replacement': 'tests/monitor_upgrade_engine.lua',
               'production_changes': 'private candidate info.json/package-manifest.json version only' if private_version else 'none', 'cases': []}
    for mode in ('base', 'space-age'):
        case = folder / mode
        mods, write = case / 'mods', case / 'write'
        mods.mkdir(parents=True); (write / 'saves').mkdir(parents=True)
        companion = mods / 'tc-buffer-upgrade_0.0.1'; companion.mkdir()
        (companion / 'info.json').write_text(json.dumps({'name': 'tc-buffer-upgrade', 'version': '0.0.1',
            'title': 'Private scheduling upgrade fixture', 'author': 'test fixture', 'factorio_version': '2.1',
            'dependencies': ['base', 'tweaked-computers']}))
        (companion / 'control.lua').write_text('-- Owning mod executes the existing opt-in upgrade hook.\n')
        (companion / 'settings.lua').write_text("data:extend{{type='bool-setting',name='tc-buffer-upgrade-run',setting_type='startup',default_value=true}}\n")
        (companion / 'data.lua').write_text("require('__tweaked-computers__.tests.native_circuit_data')\n")
        enabled = [{'name': n, 'enabled': True} for n in ('base', 'tweaked-computers', 'tc-buffer-upgrade')]
        enabled += [{'name': n, 'enabled': mode == 'space-age'} for n in ('quality', 'elevated-rails', 'space-age', 'recycler')]
        (mods / 'mod-list.json').write_text(json.dumps({'mods': enabled}))
        cfg = case / 'config.ini'
        cfg.write_text('[path]\nread-data=' + str(args.factorio.resolve().parents[2] / 'data') + '\nwrite-data=' + str(write) + '\n[other]\ncheck-updates=false\n')
        shutil.copy2(baseline, mods / baseline.name)
        initial = case / 'legacy.zip'
        command = [str(args.factorio), '--config', str(cfg), '--mod-directory', str(mods), '--create', str(initial), '--map-gen-seed', '1']
        (case / 'create-command.json').write_text(json.dumps(command, indent=2))
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=120)
        (case / 'create-engine.log').write_text(result.stdout)
        assert result.returncode == 0 and 'TC_SMOKE_OK' in result.stdout, result.stdout
        snapshot = write / 'saves/tc03-snapshot.zip'
        phases = [cold_phase(args.factorio, cfg, mods, initial, case, 'legacy-first', 'TC_COLD_SNAPSHOT_REQUESTED', snapshot)]
        rollback = case / 'rollback.zip'; shutil.copy2(snapshot, rollback)
        original_hash = digest(rollback)
        upgrade = case / 'upgrade.zip'; shutil.copy2(rollback, upgrade)
        (mods / baseline.name).unlink(); shutil.copy2(candidate, mods / candidate.name)
        phases.append(cold_phase(args.factorio, cfg, mods, upgrade, case, 'configuration-change', 'TC_UPGRADE_OK'))
        ordinary = case / 'ordinary.zip'; shutil.copy2(upgrade, ordinary)
        phases.append(cold_phase(args.factorio, cfg, mods, ordinary, case, 'ordinary', 'TC_UPGRADE_ORDINARY_OK'))
        assert digest(rollback) == original_hash and digest(args.baseline) == args.baseline_sha256
        summary['cases'].append({'mode': mode, 'passed': all(p['passed'] for p in phases), 'phases': phases, 'rollback_sha256': original_hash})
        (folder / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    assert len(summary['cases']) == 2
    print(json.dumps(summary))


if __name__ == '__main__':
    main()
