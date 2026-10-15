#!/usr/bin/env python3
"""Released-runtime migration in cold processes; only legacy test hooks injected."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import zipfile

from smoke import cold_phase

ROOT = Path(__file__).resolve().parents[1]
LEGACY_SHA256 = '11d2bd0c1f5eb6c52bff3755f6ff66e3b1a235a2959e58e71d11774e485b0d08'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--factorio', type=Path, required=True)
    ap.add_argument('--legacy', type=Path, required=True)
    ap.add_argument('--archive', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    assert digest(args.legacy) == LEGACY_SHA256, 'not the immutable published 0.1.4 baseline'
    assert not args.output.exists(), 'use a fresh output directory'
    args.output.mkdir(parents=True)
    with zipfile.ZipFile(args.archive) as z:
        candidate_info = json.loads(z.read(next(n for n in z.namelist() if n.endswith('/info.json'))))
    assert candidate_info['name'] == 'tweaked-computers' and candidate_info['version'] != '0.1.4'
    fixture = (ROOT / 'tests/monitor_upgrade_engine.lua').read_bytes()
    marker = '-- Isolated released-save upgrade driver.'
    control = (ROOT / 'control.lua').read_text()
    assert control.count(marker) == 1
    tail = '\n' + marker + control.split(marker, 1)[1]
    legacy_test = args.output / 'tweaked-computers_0.1.4.zip'
    with zipfile.ZipFile(args.legacy) as original, zipfile.ZipFile(legacy_test, 'w', zipfile.ZIP_DEFLATED) as patched:
        info = json.loads(original.read('tweaked-computers_0.1.4/info.json'))
        assert info['name'] == candidate_info['name'] and info['version'] == '0.1.4'
        for record in original.infolist():
            payload = original.read(record.filename)
            if record.filename.endswith('/control.lua'):
                payload += tail.encode()
            patched.writestr(record, payload)
        patched.writestr('tweaked-computers_0.1.4/tests/monitor_upgrade_engine.lua', fixture)
    with zipfile.ZipFile(args.legacy) as original, zipfile.ZipFile(legacy_test) as patched:
        for name in original.namelist():
            if not name.endswith('/control.lua'):
                assert original.read(name) == patched.read(name), name
    summary = {'legacy_release_sha256': LEGACY_SHA256, 'instrumented_legacy_sha256': digest(legacy_test),
               'instrumentation': 'one opt-in control tail and one test fixture; all other released payload bytes unchanged',
               'candidate_sha256': digest(args.archive), 'cases': []}
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
            'title': 'Isolated monitor upgrade driver', 'author': 'test fixture', 'factorio_version': '2.0',
            'dependencies': ['base', 'tweaked-computers']}))
        (companion / 'control.lua').write_text('-- Owning mod executes the fixed fixture.\n')
        (companion / 'settings.lua').write_text("data:extend{{type='bool-setting',name='tc-buffer-upgrade-run',setting_type='startup',default_value=true}}\n")
        enabled = [{'name': 'base', 'enabled': True}, {'name': 'tweaked-computers', 'enabled': True},
                   {'name': 'tc-buffer-upgrade', 'enabled': True}]
        enabled += [{'name': n, 'enabled': mode == 'space-age'} for n in ('quality', 'elevated-rails', 'space-age')]
        (mods / 'mod-list.json').write_text(json.dumps({'mods': enabled}))
        shutil.copy2(legacy_test, mods / legacy_test.name)
        cfg = folder / 'config.ini'
        cfg.write_text('[path]\nread-data=' + str(args.factorio.resolve().parents[2] / 'data') +
                       '\nwrite-data=' + str(write.resolve()) + '\n[other]\ncheck-updates=false\n')
        initial = folder / 'legacy.zip'
        result = subprocess.run([str(args.factorio), '--config', str(cfg), '--mod-directory', str(mods),
                                 '--create', str(initial), '--map-gen-seed', '1'],
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
        (folder / 'create-engine.log').write_text(result.stdout)
        assert result.returncode == 0 and 'TC_SMOKE_OK' in result.stdout, result.stdout
        snapshot = write / 'saves/tc03-snapshot.zip'
        phases = [cold_phase(args.factorio, cfg, mods, initial, folder, 'legacy-first',
                             'TC_COLD_SNAPSHOT_REQUESTED', snapshot)]
        upgraded = folder / 'upgrade.zip'
        shutil.copy2(snapshot, upgraded)
        (mods / legacy_test.name).unlink()
        shutil.copy2(args.archive, mods / args.archive.name)
        phases.append(cold_phase(args.factorio, cfg, mods, upgraded, folder, 'configuration-change', 'TC_UPGRADE_OK'))
        ordinary = folder / 'ordinary.zip'
        shutil.copy2(upgraded, ordinary)
        phases.append(cold_phase(args.factorio, cfg, mods, ordinary, folder, 'ordinary', 'TC_UPGRADE_ORDINARY_OK'))
        summary['cases'].append({'mode': mode, 'passed': all(p['passed'] for p in phases), 'phases': phases})
        (args.output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary))


if __name__ == '__main__':
    main()
