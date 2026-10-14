#!/usr/bin/env python3
"""Small static contracts and reproducible output/notice ZIP check.

Use an external, fresh output directory. tweaked-computers_0.0.1.zip is an isolated test
mod containing these exact assets, not an installable gameplay release.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import subprocess
import sys
import zipfile
from generate import ROOT, digest, png_read, png_write, canvas, paint


def check(output):
    manifest = json.loads((ROOT / 'manifest.json').read_text())
    records = manifest['outputs']
    paths = [r['path'] for r in records]
    assert len(paths) == len(set(paths)) == 146
    for record in manifest['inputs']:
        assert digest((ROOT.parent / record['path']).read_bytes()) == record['sha256']
        if record['path'].endswith('.png'):
            w,h,pixels=png_read((ROOT.parent/record['path']).read_bytes())
            assert (w,h)==(record['width'],record['height'])
            assert digest(bytes(c for p in pixels for c in p))==record['rgba_sha256']
            assert digest(bytes(p[3] for p in pixels))==record['alpha_sha256']
    for record in manifest['authored_inputs'] + manifest['notices'] + manifest['generated_metadata']:
        assert digest((ROOT.parent / record['path']).read_bytes()) == record['sha256']
    assert set((ROOT / 'upstream').rglob('*.png')) == {
        ROOT.parent / r['path'] for r in manifest['inputs'] if r['path'].endswith('.png')}
    assert not any('font' in p.name.lower() for p in (ROOT / 'upstream').rglob('*'))
    for record in records:
        known_inputs={r['path'] for r in manifest['inputs']+manifest['authored_inputs']}
        known_notices={r['path'] for r in manifest['notices']}
        assert set(record['input_paths']) <= known_inputs
        assert set(record['notices']) <= known_notices
        if record['layer']=='glyph':
            assert record['input_paths']==['assets/generate.py','assets/glyphs.txt']
        data = (ROOT.parent / record['path']).read_bytes()
        assert digest(data) == record['sha256']
        image = png_read(data)
        w, h, pixels = image
        assert (w, h) == (record['width'], record['height'])
        assert digest(bytes(c for p in pixels for c in p)) == record['rgba_sha256']
        assert digest(bytes(p[3] for p in pixels)) == record['alpha_sha256']
        assert png_read(png_write(image)) == image
        if record['layer'] != 'glyph':
            assert all(pixels[x][3] == pixels[(h - 1) * w + x][3] == 0 for x in range(w))
            assert all(pixels[y * w][3] == pixels[y * w + w - 1][3] == 0 for y in range(h))
        alpha = Counter(p[3] for p in pixels)
        assert set(alpha) <= {0, 85, 255}
        if record.get('state') in ('off', 'unpowered'):
            assert alpha == {0: w * h}
        elif record['layer'] in ('body','shadow','icon'):
            assert alpha[0] and (alpha[85] if record['layer'] == 'shadow' else alpha[255])
        if record['layer'] == 'shadow':
            assert all(p[:3] == (0,0,0) for p in pixels)
    # Check the byte mapping independently of the renderer's source branches.
    w, h, pixels = png_read((ROOT / 'glyphs/atlas.png').read_bytes())
    assert (w,h) == (96,144)
    def slot(byte):
        return tuple(pixels[(byte//16*9+y)*w+byte%16*6+x][3] for y in range(9) for x in range(6))
    replacement = slot(0)
    assert sum(a == 255 for a in replacement) == 20
    for byte in range(256):
        cell = slot(byte)
        if 32 <= byte <= 126:
            assert not any(cell[y*6+5] for y in range(9))
            assert not any(cell[:6]) and not any(cell[48:])
            assert any(cell) == (byte != 32)
        elif 128 <= byte <= 159:
            expected = []
            for y in range(9):
                for x in range(6):
                    index = y//3*2 + x//3
                    expected.append(255 if index<5 and (byte-128) & 2**index else 0)
            assert cell == tuple(expected)
        else:
            assert cell == replacement
    fresh = output / 'regenerated'
    subprocess.run([sys.executable, str(ROOT/'generate.py'), '--output', str(fresh)], check=True)
    for record in records:
        relative = Path(record['path']).relative_to('assets')
        assert (ROOT/relative).read_bytes() == (fresh/relative).read_bytes()
    for name in ('manifest.json','sprites.lua'):
        assert (ROOT/name).read_bytes() == (fresh/name).read_bytes()
    expected = {Path(r['path']).relative_to('assets') for r in records}
    actual = {p.relative_to(ROOT) for folder in ('sprites','icons','glyphs') for p in (ROOT/folder).glob('*.png')}
    assert actual == expected
    archive = output/'tweaked-computers_0.0.1.zip'
    with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as package:
        def add(name,data):
            entry=zipfile.ZipInfo('tweaked-computers_0.0.1/'+name,(1980,1,1,0,0,0))
            entry.compress_type=zipfile.ZIP_DEFLATED
            entry.external_attr=0o100644 << 16
            package.writestr(entry,data)
        info={'name':'tweaked-computers','version':'0.0.1','title':'TC02 asset registration fixture',
              'author':'Tweaked Computers contributors','factorio_version':'2.0',
              'dependencies':['base = 2.0.77','? space-age = 2.0.77']}
        add('info.json',json.dumps(info,sort_keys=True).encode())
        add('data.lua',(ROOT/'engine-data.lua').read_bytes())
        add('assets/engine-contract.lua',(ROOT/'engine-contract.lua').read_bytes())
        add('assets/sprites.lua',(ROOT/'sprites.lua').read_bytes())
        add('assets/manifest.json',(ROOT/'manifest.json').read_bytes())
        for name in ('README.md','source-audit.json','audit_sources.py','import_sources.py','check.py','engine-data.lua'):
            add('assets/'+name,(ROOT/name).read_bytes())
        for record in records+manifest['inputs']+manifest['notices']+manifest['authored_inputs']:
            add(record['path'],(ROOT.parent/record['path']).read_bytes())
    with zipfile.ZipFile(archive) as package:
        names=package.namelist()
        assert len(names)==len(set(names))
        for record in records+manifest['inputs']+manifest['notices']+manifest['authored_inputs']:
            assert digest(package.read('tweaked-computers_0.0.1/'+record['path']))==record['sha256']
        text=package.read('tweaked-computers_0.0.1/assets/notices/Greg-Flavored-MIT.txt')
        assert b'Copyright (c) 2024 BirbIrl' in text and b'Permission is hereby granted' in text
        assert not any('term_font' in n or 'CCPL.txt' in n for n in names)
    # Asset inspection contact sheet, NOT a client screenshot or acceptance.
    preview=canvas(640,800)
    kinds=('computer','kv','monitor','logic','configurator')
    for row,kind in enumerate(kinds):
        for column,direction in enumerate(('north','east','south','west')):
            base=png_read((ROOT/f'sprites/{kind}-{direction}-body.png').read_bytes())
            status=png_read((ROOT/f'sprites/{kind}-{direction}-powered.png').read_bytes())
            scale=1 if base[0]==160 else 2
            for y in range(160):
                for x in range(160):
                    paint(preview,column*160+x,row*160+y,base[2][y*scale*base[0]+x*scale])
                    paint(preview,column*160+x,row*160+y,status[2][y*scale*base[0]+x*scale])
    (output/'contact-sheet.png').write_bytes(png_write(preview))
    summary={'passed':True,'source_inputs':len(manifest['inputs']),'png_outputs':len(records),
             'glyph_slots':256,'ascii_slots':95,'mosaic_slots':32,'byte_exact_regeneration':True,
             'archive_sha256':digest(archive.read_bytes()),'archive':str(archive),
             'client_evidence':False,'static_checks':'source/output/decoded-alpha hashes, dimensions, transparent bounds, glyph masks, regeneration, ZIP notices/inventory'}
    (output/'static-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary,sort_keys=True))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args()
    output=args.output.resolve()
    assert not output.is_relative_to(ROOT.parent) and not output.exists(), 'fresh external output required'
    output.mkdir(parents=True)
    check(output)


if __name__=='__main__':
    main()
