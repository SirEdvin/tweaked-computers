#!/usr/bin/env python3
"""One isolated archive-based official-engine smoke; no GUI or public server."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--factorio', required=True, type=Path)
    ap.add_argument('--archive', required=True, type=Path)
    ap.add_argument('--output', required=True, type=Path)
    ap.add_argument('--mode', choices=['base', 'space-age', 'both'], default='both')
    ap.add_argument('--fixture', default='tests.runtime_contract', help='Packaged Lua module exposing run()')
    args = ap.parse_args()
    args.output = args.output.resolve()
    if args.output.is_relative_to(ROOT) or args.output.exists():
        ap.error('use a fresh output directory outside git')
    args.output.mkdir(parents=True)
    version = subprocess.check_output([str(args.factorio), '--version'], text=True)
    (args.output / 'engine-version.txt').write_text(version)
    if not version.startswith('Version: 2.0.77 '):
        raise RuntimeError('exact Factorio 2.0.77 required')
    with zipfile.ZipFile(args.archive) as archive:
        info_path = next(n for n in archive.namelist() if n.endswith('/info.json'))
        info = json.loads(archive.read(info_path))
    summary = {'engine': '2.0.77', 'archive_sha256': hashlib.sha256(args.archive.read_bytes()).hexdigest(), 'cases': []}
    for mode in (['base','space-age'] if args.mode=='both' else [args.mode]):
        folder = args.output / mode
        mods,write = folder / 'mods',folder / 'write'
        mods.mkdir(parents=True); write.mkdir()
        shutil.copy2(args.archive, mods / args.archive.name)
        fixture = mods / 'tc-smoke_0.0.1'
        fixture.mkdir()
        (fixture / 'info.json').write_text(json.dumps({'name':'tc-smoke','version':'0.0.1','title':'TC isolated smoke', 'author':'test fixture','factorio_version':'2.0','dependencies':['base',info['name']]}))
        # Read fixture source from the same ZIP as production code.
        module = '__' + info['name'] + '__.' + args.fixture
        (fixture / 'control.lua').write_text('local test = require(' + json.dumps(module) + ')\nscript.on_init(function() test.run(); log("TC_SMOKE_OK") end)\n')
        enabled = [{'name':'base','enabled':True},{'name':info['name'],'enabled':True},{'name':'tc-smoke','enabled':True}]
        enabled += [{'name':name,'enabled':mode=='space-age'} for name in ('space-age','quality','elevated-rails')]
        (mods / 'mod-list.json').write_text(json.dumps({'mods':enabled}))
        cfg = folder / 'config.ini'
        cfg.write_text('[path]\nread-data='+str(args.factorio.resolve().parents[2] / 'data')+'\nwrite-data='+str(write)+'\n[other]\ncheck-updates=false\n')
        cmd = [str(args.factorio), '--config',str(cfg),'--mod-directory',str(mods),'--create',str(folder/'smoke.zip'),'--map-gen-seed','1']
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=120)
        (folder / 'engine.log').write_text(result.stdout)
        (folder / 'command.json').write_text(json.dumps(cmd,indent=2)+'\n')
        groups = re.findall(r'TC_CONTRACT ([^\r\n]+)', result.stdout)
        totals = [int(n) for n in re.findall(r'TC_CONTRACT_TOTAL (\d+)', result.stdout)]
        counts_match = not totals or (totals == [len(groups)] and len(groups) == len(set(groups)))
        passed = result.returncode==0 and 'TC_SMOKE_OK' in result.stdout and (folder/'smoke.zip').is_file() and counts_match
        summary['cases'].append({'mode':mode,'exit_code':result.returncode,'passed':passed,'contract_groups':len(groups)})
        (args.output / 'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
        print(json.dumps(summary['cases'][-1]),flush=True)
        if not passed:
            print(result.stdout)
            raise SystemExit(1)
    print(json.dumps(summary))

if __name__ == '__main__':
    main()
