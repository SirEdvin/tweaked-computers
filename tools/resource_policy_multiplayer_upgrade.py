#!/usr/bin/env python3
"""Real released-archive save -> unchanged old reload -> candidate configuration change.

The baseline is a supplied immutable release ZIP. Only test files differ in the
instrumented copies. Never overwrite a player save; retain the untouched snapshot.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile
from resource_policy_multiplayer import ROOT, digest, instrument
from smoke import cold_phase

FIXTURE = 'tests.resource_policy_multiplayer_upgrade'
BASELINE_SHA256 = 'bb0548550cfee1ecf1accdcaf2aef3ad143dcebd5d878af0914df648ce61b982'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('factorio', 'baseline', 'archive', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--mode', choices=('base', 'space-age', 'both'), default='both')
    args = parser.parse_args()
    args.output = args.output.resolve()
    if args.output.exists() or args.output.is_relative_to(ROOT):
        parser.error('fresh output directory outside git required')
    if digest(args.baseline) != BASELINE_SHA256:
        parser.error('baseline bytes do not match the inspected supported 0.1.13 release')
    with zipfile.ZipFile(args.baseline) as archive:
        info = json.loads(archive.read('tweaked-computers_0.1.13/info.json'))
        assert info['name'] == 'tweaked-computers' and info['version'] == '0.1.13'
    args.output.mkdir(parents=True)
    (args.output / 'invocation.json').write_text(json.dumps([sys.executable] + sys.argv, indent=2))
    version = subprocess.check_output([str(args.factorio), '--version'], text=True)
    assert version.startswith('Version: 2.0.77 '), version
    (args.output / 'engine-version.txt').write_text(version)
    (args.output / 'engine-help.txt').write_text(subprocess.check_output([str(args.factorio), '--help'], text=True))
    old = args.output / 'baseline' / args.baseline.name
    candidate = args.output / 'candidate' / args.archive.name
    summary = {'passed': False, 'baseline': instrument(args.baseline, old, FIXTURE),
               'candidate': instrument(args.archive, candidate, FIXTURE), 'cases': []}
    try:
        for mode in (('base', 'space-age') if args.mode == 'both' else (args.mode,)):
            folder = args.output / mode
            mods = folder / 'mods'; mods.mkdir(parents=True)
            write = folder / 'write'; (write / 'saves').mkdir(parents=True)
            shutil.copy2(old, mods / old.name)
            companion = mods / 'tc-smoke_0.0.1'; companion.mkdir()
            meta = dict(name='tc-smoke', version='0.0.1', title='Resource policy legacy acceptance',
                        author='test fixture', factorio_version='2.0', dependencies=['base', 'tweaked-computers'])
            (companion / 'info.json').write_text(json.dumps(meta))
            (companion / 'control.lua').write_text('-- Run once in production storage.\n')
            (companion / 'settings.lua').write_text("data:extend{{type='string-setting',name='tc-smoke-production-fixture',setting_type='startup',default_value='tests.shell_client_engine',allowed_values={'tests.shell_client_engine'}}}\n")
            enabled = [dict(name=n, enabled=True) for n in ('base', 'tweaked-computers', 'tc-smoke')]
            enabled += [dict(name=n, enabled=mode == 'space-age') for n in ('space-age', 'quality', 'elevated-rails')]
            (mods / 'mod-list.json').write_text(json.dumps(dict(mods=enabled)))
            config = folder / 'config.ini'
            config.write_text('[path]\nread-data=' + str(args.factorio.resolve().parents[2] / 'data') + '\nwrite-data=' + str(write) + '\n[other]\ncheck-updates=false\n')
            create = [str(args.factorio), '--config', str(config), '--mod-directory', str(mods),
                      '--create', str(folder / 'old.zip'), '--map-gen-seed', '1']
            (folder / 'create-command.json').write_text(json.dumps(create))
            result = subprocess.run(create, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=120)
            (folder / 'create.log').write_text(result.stdout)
            assert result.returncode == 0 and 'TC_SMOKE_OK' in result.stdout, 'legacy scene creation failed'
            snapshot = write / 'saves/tc03-snapshot.zip'
            case = {'mode': mode, 'phases': []}; summary['cases'].append(case)
            case['phases'].append(cold_phase(args.factorio, config, mods, folder / 'old.zip', folder,
                                            'cold-first', 'TC_COLD_SNAPSHOT_REQUESTED', snapshot))
            original = folder / 'untouched-0.1.13-save.zip'; shutil.copy2(snapshot, original)
            case['legacy_save_sha256'] = digest(original)
            ordinary = folder / 'ordinary-copy.zip'; shutil.copy2(original, ordinary)
            case['phases'].append(cold_phase(args.factorio, config, mods, ordinary, folder, 'cold-second', 'TC_COLD_OK'))
            (mods / old.name).unlink(); shutil.copy2(candidate, mods / candidate.name)
            meta['version'] = '0.0.2'
            (companion / 'info.json').write_text(json.dumps(meta)); companion.rename(mods / 'tc-smoke_0.0.2')
            upgrade = folder / 'candidate-copy.zip'; shutil.copy2(original, upgrade)
            case['phases'].append(cold_phase(args.factorio, config, mods, upgrade, folder, 'upgrade', 'TC_UPGRADE_OK'))
            assert digest(original) == case['legacy_save_sha256'], 'untouched legacy save modified'
            case['passed'] = all(phase['passed'] for phase in case['phases'])
        summary['passed'] = all(case['passed'] for case in summary['cases'])
    except Exception as error:
        summary['error'] = str(error)
    finally:
        (args.output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary, indent=2))
    return 0 if summary['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
