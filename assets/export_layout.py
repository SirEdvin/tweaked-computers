#!/usr/bin/env python3
"""Export production Lua socket coordinates using the pinned official engine."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent
DEFINITIONS = ROOT.parent / 'scripts/device-definitions.lua'


def export(engine, output):
    output = output.resolve()
    if output.exists() or output.is_relative_to(ROOT.parent):
        raise ValueError('fresh external output directory required')
    version = subprocess.check_output([str(engine), '--version'], text=True)
    assert version.startswith('Version: 2.1.23 '), version
    mod = output / 'mods/tc-art-layout_0.0.1'
    (mod / 'scripts').mkdir(parents=True)
    (mod / 'assets').mkdir()
    shutil.copy2(DEFINITIONS, mod / 'scripts/device-definitions.lua')
    shutil.copy2(ROOT / 'layout-data.lua', mod / 'assets/layout-data.lua')
    (mod / 'info.json').write_text(json.dumps(dict(name='tc-art-layout', version='0.0.1',
        title='Socket export fixture', author='TC', factorio_version='2.1', dependencies=['base = 2.1.23'])))
    (mod / 'data.lua').write_text('log("TC_ART_LAYOUT "..require("assets.layout-data").json())\n')
    (output / 'mods/mod-list.json').write_text(json.dumps({'mods':[
        {'name':name,'enabled':name in ('base','tc-art-layout')} for name in
        ('base','tc-art-layout','space-age','quality','elevated-rails','recycler')]}))
    write = output / 'write'
    write.mkdir()
    cfg = output / 'config.ini'
    cfg.write_text('[path]\nread-data='+str(engine.resolve().parents[2] / 'data')+
        '\nwrite-data='+str(write)+'\n[other]\ncheck-updates=false\n')
    command = [str(engine),'--config',str(cfg),'--mod-directory',str(output / 'mods'),
        '--create',str(output / 'layout.zip'),'--map-gen-seed','1']
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
    (output / 'engine.log').write_text(result.stdout)
    assert result.returncode == 0, result.stdout
    lines = [line.split('TC_ART_LAYOUT ',1)[1] for line in result.stdout.splitlines() if 'TC_ART_LAYOUT ' in line]
    assert len(lines) == 1
    layout = json.loads(lines[0])
    layout['source'] = {'path':'scripts/device-definitions.lua','sha256':hashlib.sha256(DEFINITIONS.read_bytes()).hexdigest()}
    layout['engine'] = '2.1.23'
    (ROOT / 'socket-layout.json').write_text(json.dumps(layout, indent=2, sort_keys=True)+'\n')
    print(json.dumps({'exported':str(ROOT / 'socket-layout.json'),'engine':'2.1.23','source':layout['source']}))


if __name__ == '__main__':
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--factorio',required=True,type=Path)
    ap.add_argument('--output',required=True,type=Path)
    args=ap.parse_args()
    export(args.factorio,args.output)
