#!/usr/bin/env python3
"""Released-runtime migration in cold processes; only legacy test hooks injected."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

from smoke import cold_phase

ROOT = Path(__file__).resolve().parents[1]
LEGACY_SHA256 = '11d2bd0c1f5eb6c52bff3755f6ff66e3b1a235a2959e58e71d11774e485b0d08'
BASELINES = {'0.1.4': ('2.0.77', LEGACY_SHA256),
             '0.1.16': ('2.1.23', 'f7941bfcb8380222060112f1c8120d29efaf271085bb164cc96cc513340bd23d')}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def version_candidate(source, output, version):
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version):
        raise ValueError('numeric test version required')
    with zipfile.ZipFile(source) as src:
        info_path = next(n for n in src.namelist() if n.endswith('/info.json'))
        prefix = info_path[:-len('info.json')]
        info = json.loads(src.read(info_path))
        if tuple(map(int, version.split('.'))) <= tuple(map(int, info['version'].split('.'))):
            raise ValueError('test version must advance the candidate version')
        info['version'] = version
        info_bytes = (json.dumps(info, indent=2) + '\n').encode()
        manifest = json.loads(src.read(prefix + 'package-manifest.json'))
        manifest['version'] = version
        manifest['payload_sha256']['info.json'] = hashlib.sha256(info_bytes).hexdigest()
        replacements = {'info.json': info_bytes, 'package-manifest.json': (json.dumps(manifest, indent=2) + '\n').encode()}
        output.mkdir(parents=True)
        target = output / (info['name'] + '_' + version + '.zip')
        new_prefix = target.stem + '/'
        with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as dst:
            for entry in src.infolist():
                name = entry.filename.removeprefix(prefix)
                record = copy.copy(entry)
                record.filename = new_prefix + name
                dst.writestr(record, replacements.get(name, src.read(entry.filename)))
    with zipfile.ZipFile(source) as src, zipfile.ZipFile(target) as dst:
        assert all(src.read(n) == dst.read(new_prefix + n.removeprefix(prefix)) for n in src.namelist()
                   if n.removeprefix(prefix) not in replacements)
    return target


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--factorio', type=Path, required=True)
    ap.add_argument('--legacy-factorio', type=Path, required=True)
    ap.add_argument('--legacy', type=Path, required=True)
    ap.add_argument('--archive', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--baseline-version', choices=tuple(BASELINES), default='0.1.4')
    ap.add_argument('--test-version', help='Explicit metadata-only private candidate version; never edits source or supplied archives')
    args = ap.parse_args()
    assert subprocess.check_output([str(args.factorio), '--version'], text=True).startswith('Version: 2.1.23 ')
    legacy_version, legacy_sha = BASELINES[args.baseline_version]
    assert subprocess.check_output([str(args.legacy_factorio), '--version'], text=True).startswith('Version: ' + legacy_version + ' ')
    assert digest(args.legacy) == legacy_sha, 'not the immutable published ' + args.baseline_version + ' baseline'
    args.output = args.output.resolve()
    assert not args.output.exists() and not args.output.is_relative_to(ROOT), 'use a fresh output directory outside git'
    args.output.mkdir(parents=True)
    candidate = version_candidate(args.archive, args.output / 'candidate', args.test_version) if args.test_version else args.archive
    with zipfile.ZipFile(candidate) as z:
        candidate_info = json.loads(z.read(next(n for n in z.namelist() if n.endswith('/info.json'))))
    assert candidate_info['name'] == 'tweaked-computers' and tuple(map(int, candidate_info['version'].split('.'))) > tuple(map(int, args.baseline_version.split('.')))
    fixture = (ROOT / 'tests/monitor_upgrade_engine.lua').read_bytes()
    marker = '-- Isolated released-save upgrade driver.'
    control = (ROOT / 'control.lua').read_text()
    assert control.count(marker) == 1
    tail = '\n' + marker + control.split(marker, 1)[1]
    legacy_test = args.output / ('tweaked-computers_' + args.baseline_version + '.zip')
    legacy_prefix = legacy_test.stem + '/'
    with zipfile.ZipFile(args.legacy) as original, zipfile.ZipFile(legacy_test, 'w', zipfile.ZIP_DEFLATED) as patched:
        info = json.loads(original.read(legacy_prefix + 'info.json'))
        assert info['name'] == candidate_info['name'] and info['version'] == args.baseline_version
        for record in original.infolist():
            if record.filename == legacy_prefix + 'tests/monitor_upgrade_engine.lua':
                continue
            payload = original.read(record.filename)
            if record.filename == legacy_prefix + 'control.lua':
                payload = payload.split(marker.encode(), 1)[0] + tail.encode()
            patched.writestr(copy.copy(record), payload)
        patched.writestr(legacy_prefix + 'tests/monitor_upgrade_engine.lua', fixture)
    with zipfile.ZipFile(args.legacy) as original, zipfile.ZipFile(legacy_test) as patched:
        for name in original.namelist():
            if name not in (legacy_prefix + 'control.lua', legacy_prefix + 'tests/monitor_upgrade_engine.lua'):
                assert original.read(name) == patched.read(name), name
    summary = {'legacy_version': args.baseline_version, 'legacy_engine': legacy_version,
               'source_setup': 'stopped host data; candidate-only activation for notification checks' if args.baseline_version == '0.1.4' else 'function-capable baseline running source',
               'candidate_version': candidate_info['version'], 'test_version': args.test_version,
               'source_archive_sha256': digest(args.archive),
               'legacy_release_sha256': legacy_sha, 'instrumented_legacy_sha256': digest(legacy_test),
               'instrumentation': 'one opt-in control tail and one test fixture; all other released payload bytes unchanged',
               'candidate_sha256': digest(candidate), 'cases': []}
    for mode in ('base', 'space-age'):
        folder = args.output / mode
        mods = folder / 'mods'
        mods.mkdir(parents=True)
        write = folder / 'write'
        write.mkdir()
        (write / 'saves').mkdir()
        companion = mods / 'tc-buffer-upgrade_0.0.1'
        companion.mkdir()
        (companion / 'info.json').write_text(json.dumps({'name': 'tc-buffer-upgrade', 'version': '0.0.1',
            'title': 'Isolated monitor upgrade driver', 'author': 'test fixture', 'factorio_version': legacy_version.rsplit('.', 1)[0],
            'dependencies': ['base', 'tweaked-computers']}))
        (companion / 'control.lua').write_text('-- Owning mod executes the fixed fixture.\n')
        (companion / 'settings.lua').write_text("data:extend{{type='bool-setting',name='tc-buffer-upgrade-run',setting_type='startup',default_value=true}}\n")
        enabled = [{'name': 'base', 'enabled': True}, {'name': 'tweaked-computers', 'enabled': True},
                   {'name': 'tc-buffer-upgrade', 'enabled': True}]
        enabled += [{'name': n, 'enabled': mode == 'space-age'} for n in ('quality', 'elevated-rails', 'space-age')]
        if legacy_version.startswith('2.1.'):
            enabled.append(dict(name='recycler', enabled=mode == 'space-age'))
        (mods / 'mod-list.json').write_text(json.dumps({'mods': enabled}))
        shutil.copy2(legacy_test, mods / legacy_test.name)
        cfg = folder / 'config.ini'
        cfg.write_text('[path]\nread-data=' + str(args.legacy_factorio.resolve().parents[2] / 'data') +
                       '\nwrite-data=' + str(write.resolve()) + '\n[other]\ncheck-updates=false\n')
        initial = folder / 'legacy.zip'
        command = [str(args.legacy_factorio), '--config', str(cfg), '--mod-directory', str(mods),
                   '--create', str(initial), '--map-gen-seed', '1']
        (folder / 'create-command.json').write_text(json.dumps(command, indent=2) + '\n')
        result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
        (folder / 'create-engine.log').write_text(result.stdout)
        assert result.returncode == 0 and 'TC_SMOKE_OK' in result.stdout, result.stdout
        snapshot = write / 'saves/tc03-snapshot.zip'
        phases = [cold_phase(args.legacy_factorio, cfg, mods, initial, folder, 'legacy-first',
                             'TC_COLD_SNAPSHOT_REQUESTED', snapshot)]
        upgraded = folder / 'upgrade.zip'
        shutil.copy2(snapshot, upgraded)
        (mods / legacy_test.name).unlink()
        shutil.copy2(candidate, mods / candidate.name)
        info_path = companion / 'info.json'
        info = json.loads(info_path.read_text())
        info['factorio_version'] = '2.1'
        info_path.write_text(json.dumps(info))
        cfg.write_text(cfg.read_text().replace(str(args.legacy_factorio.resolve().parents[2] / 'data'), str(args.factorio.resolve().parents[2] / 'data')))
        if not any(m['name'] == 'recycler' for m in enabled):
            enabled.append(dict(name='recycler', enabled=mode == 'space-age'))
        (mods / 'mod-list.json').write_text(json.dumps(dict(mods=enabled)))
        phases.append(cold_phase(args.factorio, cfg, mods, upgraded, folder, 'configuration-change', 'TC_UPGRADE_OK'))
        ordinary = folder / 'ordinary.zip'
        shutil.copy2(upgraded, ordinary)
        phases.append(cold_phase(args.factorio, cfg, mods, ordinary, folder, 'ordinary', 'TC_UPGRADE_ORDINARY_OK'))
        summary['cases'].append({'mode': mode, 'passed': all(p['passed'] for p in phases), 'phases': phases})
        (args.output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary))


if __name__ == '__main__':
    main()
