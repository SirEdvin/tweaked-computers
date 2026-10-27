#!/usr/bin/env python3
"""Check native installation (0.1.10) or radar tracking migration (0.1.15)."""
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
LEGACY_SHA256 = '5221365b208871d7d88e6fff3f39431cac3d7acd48eb2c5d82830015dbb64000'
TRACKING_SHA256 = '5205daa86f7fb63db4ac522144eb500603ebbd799f6c7a09d87df259628db1ab'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--carrier', choices=('radar', 'speaker', 'radar-tracking'), default='radar')
    for name in ('factorio', 'legacy-factorio', 'legacy', 'archive', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    carrier = args.carrier
    tracking = carrier == 'radar-tracking'
    legacy_version = '0.1.15' if tracking else '0.1.10'
    legacy_engine = '2.1.23' if tracking else '2.0.77'
    legacy_sha256 = TRACKING_SHA256 if tracking else LEGACY_SHA256
    fixture_name = carrier.replace('-', '_')
    assert digest(args.legacy) == legacy_sha256, 'immutable baseline ' + legacy_version + ' required'
    assert not args.output.exists() and not args.output.resolve().is_relative_to(ROOT)
    args.output.mkdir(parents=True)
    assert subprocess.check_output([str(args.factorio), '--version'], text=True).startswith('Version: 2.1.23 ')
    assert subprocess.check_output([str(args.legacy_factorio), '--version'], text=True).startswith('Version: ' + legacy_engine + ' ')
    with zipfile.ZipFile(args.archive) as z:
        prefix = next(n[:-len('info.json')] for n in z.namelist() if n.endswith('/info.json'))
        fixture = z.read(prefix + f'tests/{fixture_name}_upgrade_engine.lua')
        control = z.read(prefix + 'control.lua').decode()
    start = f'-- Isolated {carrier} installation driver.'
    end = f'-- End isolated {carrier} installation driver.'
    assert control.count(start) == control.count(end) == 1
    hook = '\n' + start + control.split(start, 1)[1].split(end, 1)[0] + end + '\n'
    legacy_test = args.output / f'tweaked-computers_{legacy_version}.zip'
    with zipfile.ZipFile(args.legacy) as original, zipfile.ZipFile(legacy_test, 'w', zipfile.ZIP_DEFLATED) as patched:
        legacy_prefix = next(n[:-len('info.json')] for n in original.namelist() if n.endswith('/info.json'))
        for entry in original.infolist():
            value = original.read(entry.filename)
            if entry.filename.endswith('/control.lua'):
                value += hook.encode()
            patched.writestr(copy.copy(entry), value)
        patched.writestr(legacy_prefix + f'tests/{fixture_name}_upgrade_engine.lua', fixture)
    with zipfile.ZipFile(args.legacy) as original, zipfile.ZipFile(legacy_test) as patched:
        for name in original.namelist():
            if not name.endswith('/control.lua'):
                assert original.read(name) == patched.read(name), name
    summary = {'carrier': carrier, 'legacy_sha256': legacy_sha256, 'candidate_sha256': digest(args.archive),
               'fixture_sha256': hashlib.sha256(fixture).hexdigest(),
               'instrumentation': 'Legacy only: opt-in control hook + fixture. Every other legacy byte and entire candidate ZIP unchanged.', 'cases': []}
    workloads = ('idle', 'connected') if tracking else ('installation',)
    for mode, workload in ((m, w) for m in ('base', 'space-age') for w in workloads):
        folder = args.output / mode / workload
        mods, write = folder / 'mods', folder / 'write'
        mods.mkdir(parents=True)
        (write / 'saves').mkdir(parents=True)
        companion = mods / f'tc-{carrier}-upgrade_0.0.1'
        companion.mkdir()
        info = dict(name=f'tc-{carrier}-upgrade', version='0.0.1', title=f'{carrier.title()} install fixture', author='test fixture', factorio_version='2.1' if tracking else '2.0', dependencies=['base', 'tweaked-computers'])
        (companion / 'info.json').write_text(json.dumps(info))
        if tracking:
            (companion / 'settings.lua').write_text("data:extend{{type='bool-setting',name='tc-radar-tracking-upgrade-idle',setting_type='startup',default_value=" + str(workload == 'idle').lower() + "}}\n")
        (companion / 'control.lua').write_text('-- Owning mod executes the fixture.\n')
        enabled = [dict(name=n, enabled=True) for n in ('base', 'tweaked-computers', f'tc-{carrier}-upgrade')]
        enabled += [dict(name=n, enabled=mode == 'space-age') for n in ('space-age', 'quality', 'elevated-rails')]
        if tracking:
            enabled.append(dict(name='recycler', enabled=mode == 'space-age'))
        (mods / 'mod-list.json').write_text(json.dumps(dict(mods=enabled)))
        shutil.copy2(legacy_test, mods / legacy_test.name)
        cfg = folder / 'config.ini'
        cfg.write_text('[path]\nread-data=' + str(args.legacy_factorio.resolve().parents[2] / 'data') + '\nwrite-data=' + str(write.resolve()) + '\n[other]\ncheck-updates=false\n')
        initial = folder / 'legacy.zip'
        command = [str(args.legacy_factorio), '--config', str(cfg), '--mod-directory', str(mods), '--create', str(initial), '--map-gen-seed', '1']
        result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
        (folder / 'create-engine.log').write_text(result.stdout)
        assert result.returncode == 0 and 'TC_SMOKE_OK' in result.stdout, result.stdout
        snapshot = write / 'saves/tc03-snapshot.zip'
        phases = [cold_phase(args.legacy_factorio, cfg, mods, initial, folder, 'legacy-first', 'TC_COLD_SNAPSHOT_REQUESTED', snapshot)]
        installed = folder / 'installed.zip'
        shutil.copy2(snapshot, installed)
        (mods / legacy_test.name).unlink()
        shutil.copy2(args.archive, mods / args.archive.name)
        info['version'] = '0.0.2'  # Explicit real configuration event; no production version fabrication.
        info['factorio_version'] = '2.1'
        cfg.write_text(cfg.read_text().replace(str(args.legacy_factorio.resolve().parents[2] / 'data'), str(args.factorio.resolve().parents[2] / 'data')))
        if not tracking:
            enabled.append(dict(name='recycler', enabled=mode == 'space-age'))
        (mods / 'mod-list.json').write_text(json.dumps(dict(mods=enabled)))
        (companion / 'info.json').write_text(json.dumps(info))
        companion.rename(mods / f'tc-{carrier}-upgrade_0.0.2')
        phases.append(cold_phase(args.factorio, cfg, mods, installed, folder, 'installation', 'TC_UPGRADE_OK'))
        ordinary = folder / 'ordinary.zip'
        shutil.copy2(installed, ordinary)
        phases.append(cold_phase(args.factorio, cfg, mods, ordinary, folder, 'ordinary', 'TC_UPGRADE_ORDINARY_OK'))
        summary['cases'].append(dict(mode=mode, workload=workload, passed=all(p['passed'] for p in phases), phases=phases))
        (args.output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary))

if __name__ == '__main__':
    main()
