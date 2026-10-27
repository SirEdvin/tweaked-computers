#!/usr/bin/env python3
"""Same-engine additive Factoriopedia installation using immutable campaign baseline."""
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
BASELINE_SHA256 = '95fa7ef48ade7d1494a2f00ccb1ef75a943a87f92699205106ade6ad772ce826'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def payload(archive):
    with zipfile.ZipFile(archive) as package:
        prefix = next(n[:-len('info.json')] for n in package.namelist() if n.endswith('/info.json'))
        return {n.removeprefix(prefix): package.read(n) for n in package.namelist()}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('factorio', 'legacy', 'archive', 'output'):
        parser.add_argument('--'+name, type=Path, required=True)
    args = parser.parse_args()
    assert digest(args.legacy) == BASELINE_SHA256, 'immutable approved pre-feature baseline required'
    assert not args.output.exists() and not args.output.resolve().is_relative_to(ROOT)
    args.output.mkdir(parents=True)
    assert subprocess.check_output([str(args.factorio), '--version'], text=True).startswith('Version: 2.1.23 ')
    candidate = payload(args.archive)
    control = candidate['control.lua'].decode()
    start = '-- Isolated Factoriopedia installation driver.'
    end = '-- End isolated Factoriopedia installation driver.'
    assert control.count(start) == control.count(end) == 1
    hook = (start+control.split(start, 1)[1].split(end, 1)[0]+end+'\n').encode()
    fixture = candidate['tests/factoriopedia_upgrade_engine.lua']
    legacy_test = args.output / args.legacy.name
    with zipfile.ZipFile(args.legacy) as original, zipfile.ZipFile(legacy_test, 'w', zipfile.ZIP_DEFLATED) as patched:
        prefix = next(n[:-len('info.json')] for n in original.namelist() if n.endswith('/info.json'))
        for entry in original.infolist():
            value = original.read(entry.filename)
            if entry.filename == prefix+'control.lua': value += b'\n'+hook
            patched.writestr(copy.copy(entry), value)
        patched.writestr(prefix+'tests/factoriopedia_upgrade_engine.lua', fixture)
    baseline = payload(args.legacy); instrumented = payload(legacy_test)
    assert set(instrumented)-set(baseline) == {'tests/factoriopedia_upgrade_engine.lua'}
    assert [name for name in baseline if baseline[name] != instrumented[name]] == ['control.lua']
    assert instrumented['control.lua'] == baseline['control.lua']+b'\n'+hook
    # Test-only version distinction; production info.json and immutable packages are untouched.
    info = json.loads(candidate['info.json']); info['version'] = '0.1.17'
    modified = dict(candidate); modified['info.json'] = (json.dumps(info, indent=2)+'\n').encode()
    manifest = json.loads(candidate['package-manifest.json']); manifest['version'] = info['version']
    manifest['payload_sha256']['info.json'] = hashlib.sha256(modified['info.json']).hexdigest()
    modified['package-manifest.json'] = (json.dumps(manifest, indent=2, sort_keys=True)+'\n').encode()
    versioned = args.output / 'tweaked-computers_0.1.17.zip'
    with zipfile.ZipFile(versioned, 'w', zipfile.ZIP_DEFLATED) as package:
        for name, value in sorted(modified.items()): package.writestr('tweaked-computers_0.1.17/'+name, value)
    assert payload(versioned) == modified
    assert sorted(name for name in candidate if candidate[name] != modified[name]) == ['info.json','package-manifest.json']
    summary = dict(baseline_sha256=BASELINE_SHA256,candidate_sha256=digest(args.archive),
                   baseline_instrumented_sha256=digest(legacy_test),versioned_sha256=digest(versioned),
                   fixture_sha256=hashlib.sha256(fixture).hexdigest(),
                   test_only_candidate_differences=['ZIP prefix/version 0.1.17','info.json version','package-manifest version/info hash'],cases=[])
    for mode in ('base','space-age'):
        folder=args.output/mode; mods=folder/'mods'; write=folder/'write'
        mods.mkdir(parents=True); (write/'saves').mkdir(parents=True)
        companion=mods/'tc-factoriopedia-upgrade_0.0.1'; companion.mkdir()
        metadata=dict(name='tc-factoriopedia-upgrade',version='0.0.1',title='Same-engine installation fixture',author='test fixture',factorio_version='2.1',dependencies=['base','tweaked-computers'])
        (companion/'info.json').write_text(json.dumps(metadata)); (companion/'control.lua').write_text('-- Owning mod executes the fixture.\n')
        enabled=[dict(name=n,enabled=True) for n in ('base','tweaked-computers','tc-factoriopedia-upgrade')]
        enabled += [dict(name=n,enabled=mode=='space-age') for n in ('space-age','quality','elevated-rails','recycler')]
        (mods/'mod-list.json').write_text(json.dumps(dict(mods=enabled)))
        shutil.copy2(legacy_test,mods/legacy_test.name)
        cfg=folder/'config.ini'
        cfg.write_text('[path]\nread-data='+str(args.factorio.resolve().parents[2]/'data')+'\nwrite-data='+str(write.resolve())+'\n[other]\ncheck-updates=false\n')
        initial=folder/'baseline.zip'
        command=[str(args.factorio),'--config',str(cfg),'--mod-directory',str(mods),'--create',str(initial),'--map-gen-seed','1']
        result=subprocess.run(command,capture_output=True,text=True,timeout=120)
        (folder/'create-engine.log').write_text(result.stdout+result.stderr)
        assert result.returncode==0 and 'TC_SMOKE_OK' in result.stdout,(result.stdout,result.stderr)
        snapshot=write/'saves/tc03-snapshot.zip'
        phases=[cold_phase(args.factorio,cfg,mods,initial,folder,'baseline-first','TC_COLD_SNAPSHOT_REQUESTED',snapshot)]
        installed=folder/'installed.zip'; shutil.copy2(snapshot,installed)
        (mods/legacy_test.name).unlink(); shutil.copy2(versioned,mods/versioned.name)
        metadata['version']='0.0.2'; (companion/'info.json').write_text(json.dumps(metadata))
        renamed=mods/'tc-factoriopedia-upgrade_0.0.2'; companion.rename(renamed); companion=renamed
        after=write/'saves/tc-fp-installed.zip'
        phases.append(cold_phase(args.factorio,cfg,mods,installed,folder,'installation','TC_UPGRADE_OK',after))
        ordinary=folder/'ordinary.zip'; shutil.copy2(after,ordinary)
        phases.append(cold_phase(args.factorio,cfg,mods,ordinary,folder,'ordinary','TC_UPGRADE_ORDINARY_OK'))
        metadata['version']='0.0.3'; (companion/'info.json').write_text(json.dumps(metadata)); companion.rename(mods/'tc-factoriopedia-upgrade_0.0.3')
        later=folder/'later.zip'; shutil.copy2(after,later)
        phases.append(cold_phase(args.factorio,cfg,mods,later,folder,'later-reconciliation','TC_FACT_LATER_RECONCILIATION_OK'))
        summary['cases'].append(dict(mode=mode,create_exit=result.returncode,phases=phases,passed=all(p['passed'] for p in phases)))
        (args.output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary))

if __name__ == '__main__':
    main()
