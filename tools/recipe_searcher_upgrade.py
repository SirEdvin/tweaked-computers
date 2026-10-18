#!/usr/bin/env python3
"""Install Recipe Searcher into a populated, researched released 0.1.8 save."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import zipfile

from smoke import cold_phase

ROOT = Path(__file__).resolve().parents[1]
LEGACY_SHA256 = 'f37b1d44fb148a248a6bd73334612e49ee0d0729a3cb1357868923ae5ed406db'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    for name in ('factorio', 'legacy', 'archive', 'output'):
        ap.add_argument('--' + name, type=Path, required=True)
    args = ap.parse_args()
    assert digest(args.legacy) == LEGACY_SHA256, 'immutable published 0.1.8 required'
    assert not args.output.exists() and not args.output.resolve().is_relative_to(ROOT)
    args.output.mkdir(parents=True)
    version = subprocess.check_output([str(args.factorio), '--version'], text=True)
    assert version.startswith('Version: 2.0.77 ')
    with zipfile.ZipFile(args.archive) as z:
        prefix = next(n[:-len('info.json')] for n in z.namelist() if n.endswith('/info.json'))
        fixture = z.read(prefix + 'tests/recipe_searcher_upgrade_engine.lua')
        control = z.read(prefix + 'control.lua').decode()
    start = '-- Isolated recipe-searcher installation driver.'
    end = '-- Isolated released-save upgrade driver.'
    assert control.count(start) == control.count(end) == 1
    tail = '\n' + start + control.split(start, 1)[1].split(end, 1)[0]
    legacy_test = args.output / 'tweaked-computers_0.1.8.zip'
    with zipfile.ZipFile(args.legacy) as original, zipfile.ZipFile(legacy_test, 'w', zipfile.ZIP_DEFLATED) as patched:
        legacy_prefix = next(n[:-len('info.json')] for n in original.namelist() if n.endswith('/info.json'))
        for entry in original.infolist():
            value = original.read(entry.filename)
            if entry.filename.endswith('/control.lua'):
                value += tail.encode()
            patched.writestr(copy.copy(entry), value)
        patched.writestr(legacy_prefix + 'tests/recipe_searcher_upgrade_engine.lua', fixture)
    with zipfile.ZipFile(args.legacy) as original, zipfile.ZipFile(legacy_test) as patched:
        for name in original.namelist():
            if not name.endswith('/control.lua'):
                assert original.read(name) == patched.read(name), name
    cases = []
    summary = dict(legacy_sha256=LEGACY_SHA256, candidate_sha256=digest(args.archive),
                   fixture_sha256=hashlib.sha256(fixture).hexdigest(),
                   instrumentation='Legacy only: opt-in control hook plus fixture; all other original bytes unchanged. Candidate ZIP unchanged.', cases=cases)
    for mode in ('base', 'space-age'):
        folder = args.output / mode
        mods = folder / 'mods'
        write = folder / 'write'
        mods.mkdir(parents=True)
        (write / 'saves').mkdir(parents=True)
        companion = mods / 'tc-recipe-upgrade_0.0.1'
        companion.mkdir()
        info = dict(name='tc-recipe-upgrade', version='0.0.1', title='Recipe installation fixture',
                    author='test fixture', factorio_version='2.0', dependencies=['base', 'tweaked-computers'])
        (companion / 'info.json').write_text(json.dumps(info))
        (companion / 'control.lua').write_text('-- Owning mod executes the fixture.\n')
        enabled = [dict(name=n, enabled=True) for n in ('base', 'tweaked-computers', 'tc-recipe-upgrade')]
        enabled += [dict(name=n, enabled=mode == 'space-age') for n in ('space-age', 'quality', 'elevated-rails')]
        (mods / 'mod-list.json').write_text(json.dumps(dict(mods=enabled)))
        shutil.copy2(legacy_test, mods / legacy_test.name)
        cfg = folder / 'config.ini'
        cfg.write_text('[path]\nread-data=' + str(args.factorio.resolve().parents[2] / 'data') +
                       '\nwrite-data=' + str(write.resolve()) + '\n[other]\ncheck-updates=false\n')
        initial = folder / 'legacy.zip'
        command = [str(args.factorio), '--config', str(cfg), '--mod-directory', str(mods),
                   '--create', str(initial), '--map-gen-seed', '1']
        result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
        (folder / 'create-engine.log').write_text(result.stdout)
        assert result.returncode == 0 and 'TC_SMOKE_OK' in result.stdout, result.stdout
        snapshot = write / 'saves/tc03-snapshot.zip'
        phases = [cold_phase(args.factorio, cfg, mods, initial, folder, 'legacy-first', 'TC_COLD_SNAPSHOT_REQUESTED', snapshot)]
        upgraded = folder / 'installed.zip'
        shutil.copy2(snapshot, upgraded)
        (mods / legacy_test.name).unlink()
        shutil.copy2(args.archive, mods / args.archive.name)
        # Source version stays unchanged per task; a test-companion version change
        # explicitly triggers the real configuration event in the next process.
        info['version'] = '0.0.2'
        (companion / 'info.json').write_text(json.dumps(info))
        companion.rename(mods / 'tc-recipe-upgrade_0.0.2')
        phases.append(cold_phase(args.factorio, cfg, mods, upgraded, folder, 'installation', 'TC_UPGRADE_OK'))
        ordinary = folder / 'ordinary.zip'
        shutil.copy2(upgraded, ordinary)
        phases.append(cold_phase(args.factorio, cfg, mods, ordinary, folder, 'ordinary', 'TC_UPGRADE_ORDINARY_OK'))
        cases.append(dict(mode=mode, passed=all(p['passed'] for p in phases), phases=phases))
        (args.output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary))


if __name__ == '__main__':
    main()
