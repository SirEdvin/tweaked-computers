#!/usr/bin/env python3
"""Create a populated genuine alpha save, then cold-upgrade exact candidate bytes.

Only the baseline's opt-in fixture allowlist/test file is instrumented. Gameplay
code comes from the pinned Git object. Changing tc-smoke's version triggers the
candidate's real on_configuration_changed; the candidate ZIP is never rewritten.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import zipfile
from smoke import cold_phase

ROOT = Path(__file__).resolve().parents[1]
BASELINE = 'cb300e62ebad6a4a9a38a0679f21e251009f1d16'
FIXTURE = 'tests.rd1_upgrade_engine'


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--factorio', type=Path, required=True)
    ap.add_argument('--legacy-factorio', type=Path, required=True)
    ap.add_argument('--archive', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--mode', choices=['base', 'space-age', 'both'], default='both')
    ap.add_argument('--baseline', default=BASELINE, help='Pinned source commit for the populated old save')
    ap.add_argument('--fixture', choices=[FIXTURE, 'tests.peripheral_inspector_upgrade_engine', 'tests.native_circuit_upgrade_engine'], default=FIXTURE)
    args = ap.parse_args()
    args.output = args.output.resolve()
    if args.output.exists() or args.output.is_relative_to(ROOT):
        ap.error('use a fresh directory outside git')
    args.output.mkdir(parents=True)
    version = subprocess.check_output([str(args.factorio), '--version'], text=True)
    assert version.startswith('Version: 2.1.23 '), version
    assert subprocess.check_output([str(args.legacy_factorio), '--version'], text=True).startswith('Version: 2.0.77 ')
    (args.output / 'engine-version.txt').write_text(version)
    old = args.output / 'alpha-source'
    old.mkdir()
    content = subprocess.check_output(['git', 'archive', args.baseline], cwd=ROOT)
    with tarfile.open(fileobj=io.BytesIO(content)) as archive:
        archive.extractall(old, filter='data')
    control = old / 'control.lua'
    original = control.read_text()
    needle = "name=='tests.integration_engine'"
    assert original.count(needle) == 1
    control.write_text(original.replace(needle, needle + " or name=='" + args.fixture + "'"))
    fixture_path = args.fixture.replace('.', '/') + '.lua'
    shutil.copy2(ROOT / fixture_path, old / fixture_path)
    result = subprocess.run(['python3', str(old / 'tools/build.py'), '--output', str(args.output / 'alpha-artifact')],
                            capture_output=True, text=True, check=True)
    baseline = json.loads(result.stdout)
    summary = {'engine': '2.1.23', 'legacy_engine': '2.0.77', 'baseline_commit': args.baseline, 'fixture': args.fixture, 'instrumented_alpha': baseline,
               'candidate_sha256': hashlib.sha256(args.archive.read_bytes()).hexdigest(), 'cases': []}
    for mode in (['base', 'space-age'] if args.mode == 'both' else [args.mode]):
        folder = args.output / mode
        mods, write = folder / 'mods', folder / 'write'
        mods.mkdir(parents=True)
        (write / 'saves').mkdir(parents=True)
        archive_path = mods / Path(baseline['path']).name
        shutil.copy2(baseline['path'], archive_path)
        testmod = mods / 'tc-smoke_0.0.1'
        testmod.mkdir()
        info = {'name': 'tc-smoke', 'version': '0.0.1', 'title': 'RD1 isolated upgrade fixture',
                'author': 'test fixture', 'factorio_version': '2.0', 'dependencies': ['base', 'tweaked-computers']}
        (testmod / 'info.json').write_text(json.dumps(info))
        (testmod / 'control.lua').write_text('-- Fixture runs only in production storage.\n')
        (testmod / 'settings.lua').write_text("data:extend{{type='string-setting',name='tc-smoke-production-fixture',setting_type='startup',default_value='" + args.fixture + "',allowed_values={'" + args.fixture + "'}}}\n")
        enabled = [{'name': n, 'enabled': True} for n in ('base', 'tweaked-computers', 'tc-smoke')]
        enabled += [{'name': n, 'enabled': mode == 'space-age'} for n in ('space-age', 'quality', 'elevated-rails')]
        (mods / 'mod-list.json').write_text(json.dumps({'mods': enabled}))
        cfg = folder / 'config.ini'
        cfg.write_text('[path]\nread-data=' + str(args.legacy_factorio.resolve().parents[2] / 'data') + '\nwrite-data=' + str(write) + '\n[other]\ncheck-updates=false\n')
        create = subprocess.run([str(args.legacy_factorio), '--config', str(cfg), '--mod-directory', str(mods),
                                 '--create', str(folder / 'old.zip'), '--map-gen-seed', '1'],
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=120)
        (folder / 'alpha-create.log').write_text(create.stdout)
        if create.returncode != 0 or 'TC_SMOKE_OK' not in create.stdout:
            print(create.stdout)
            raise RuntimeError('alpha save creation failed')
        snapshot = write / 'saves/tc03-snapshot.zip'
        phases = [cold_phase(args.legacy_factorio, cfg, mods, folder / 'old.zip', folder,
                             'cold-first', 'TC_COLD_SNAPSHOT_REQUESTED', snapshot)]
        original_save = folder / 'untouched-alpha-save.zip'
        shutil.copy2(snapshot, original_save)
        ordinary = folder / 'ordinary-alpha.zip'
        shutil.copy2(snapshot, ordinary)
        phases.append(cold_phase(args.legacy_factorio, cfg, mods, ordinary, folder, 'cold-second', 'TC_COLD_OK'))
        # Replace only the isolated mod copy; assert the exact production bytes.
        archive_path.unlink()
        archive_path = mods / args.archive.name
        shutil.copy2(args.archive, archive_path)
        assert hashlib.sha256(archive_path.read_bytes()).hexdigest() == summary['candidate_sha256']
        info['version'] = '0.0.2'
        info['factorio_version'] = '2.1'
        cfg.write_text(cfg.read_text().replace(str(args.legacy_factorio.resolve().parents[2] / 'data'), str(args.factorio.resolve().parents[2] / 'data')))
        enabled.append(dict(name='recycler', enabled=mode == 'space-age'))
        (mods / 'mod-list.json').write_text(json.dumps(dict(mods=enabled)))
        (testmod / 'info.json').write_text(json.dumps(info))
        testmod.rename(mods / 'tc-smoke_0.0.2')
        candidate_save = folder / 'candidate-upgrade.zip'
        shutil.copy2(original_save, candidate_save)
        phases.append(cold_phase(args.factorio, cfg, mods, candidate_save, folder, 'upgrade', 'TC_UPGRADE_OK'))
        case = {'mode': mode, 'passed': all(p['passed'] for p in phases), 'phases': phases,
                'alpha_save_sha256': hashlib.sha256(original_save.read_bytes()).hexdigest()}
        summary['cases'].append(case)
        (args.output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(case), flush=True)
    print(json.dumps(summary))


if __name__ == '__main__':
    main()
