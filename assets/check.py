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
from generate import ROOT, digest, png_read, png_write


def check(output):
    manifest = json.loads((ROOT / 'manifest.json').read_text())
    records = manifest['outputs']
    paths = [r['path'] for r in records]
    assert len(paths) == len(set(paths)) == 178
    # Frozen independent digest from every original selected-preview PNG,
    # including untouched statuses/glyphs/shadows, not from the new manifest.
    preview_paths=sorted(r['path'] for r in records if r['layer']!='technology')
    assert len(preview_paths)==176
    preview_inventory=''.join(p+' '+digest((ROOT.parent/p).read_bytes())+'\n' for p in preview_paths)
    assert digest(preview_inventory.encode())=='84f730ba63f28fd7aa6e451dafd1bbc2bf0c99a3ce446aded2650fb889dee29c', 'selected B PNG bytes changed'
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
        if record['layer'] == 'display-fill':
            assert record['path']=='assets/glyphs/pixel.png'
            assert (w,h,pixels)==(1,1,[(255,255,255,255)])
            assert record['input_paths']==['assets/generate.py']
        elif record['layer'] != 'glyph':
            assert all(pixels[x][3] == pixels[(h - 1) * w + x][3] == 0 for x in range(w))
            assert all(pixels[y * w][3] == pixels[y * w + w - 1][3] == 0 for y in range(h))
        alpha = Counter(p[3] for p in pixels)
        if record['layer'] in ('glyph','display-fill','status') or record.get('device')=='monitor':
            assert set(alpha) <= {0, 85, 255}
        elif record['layer']=='shadow':
            assert max(alpha)<=100, 'bounded antialiased mesh shadow'
        if record['layer'] in ('body','shadow','icon','status'):
            assert alpha[0] and (any(a>0 for a in alpha) if record['layer'] == 'shadow' else alpha[255])
        if record['layer'] == 'shadow':
            assert all(p[:3] == (0,0,0) for p in pixels)
    # Exact sprite/native geometry mapping, including monitor's half-open raster.
    layout=json.loads((ROOT/'socket-layout.json').read_text())
    contacts=0
    silhouettes={}
    for kind,device in manifest['devices'].items():
        for direction,view in device['directions'].items():
            assert view['roles']==layout['devices'][kind]['directions'][direction]
            w,h,pixels=png_read((ROOT/view['body']).read_bytes())
            for role,entry in view['roles'].items():
                for color,(x,y) in entry['contacts'].items():
                    px,py=round(w/2+x*64),round(h/2+y*64)
                    expected=(221,120,103,255) if color=='red' else (147,186,120,255)
                    assert pixels[py*w+px]==(expected if kind=='monitor' else (234,216,162,255)), (kind,direction,role,color)
                    contacts+=1
            if direction=='north':
                silhouettes[kind]=tuple(p[3] for p in pixels)
            if kind=='monitor':
                visible=[(i%w-w//2,i//w-h//2) for i,p in enumerate(pixels) if p[3]]
                assert (min(x for x,y in visible),max(x for x,y in visible),min(y for x,y in visible),max(y for x,y in visible))==(-36,35,-36,35)
                # Independently audit every alpha pixel, including the exact four
                # chamfered corners. Artwork overhang must not grow unchecked.
                expected={(x,y) for y in range(-36,36) for x in range(-36,36)
                          if x+y>=-68 and x-y<=67 and x+y<=66 and y-x<=67}
                assert set(visible)==expected
                for y in range(-30,30):
                    for x in range(-30,30): assert pixels[(h//2+y)*w+w//2+x]==(21,32,28,255)
            for state,path in view['states'].items():
                sw,sh,status_pixels=png_read((ROOT/path).read_bytes())
                for frame in range(sw//w):
                    lit=[(x-w//2,y-h//2) for y in range(h) for x in range(w) if status_pixels[y*sw+frame*w+x][3]]
                    assert 1<=len(lit)<=9
                    if kind=='monitor':
                        assert all(-32<=x<=31 and -32<=y<=31 and not (-30<=x<30 and -30<=y<30) for x,y in lit), (direction,state)
    assert contacts==72
    assert len(set(silhouettes.values()))==6, 'family must not reuse the same silhouette'
    for name,entry in manifest['technologies'].items():
        w,h,pixels=png_read((ROOT/entry['icon']).read_bytes())
        assert (w,h)==(256,256) and entry['icon_size']==256
        assert any(p[3] for p in pixels) and name in ('tc-circuit-computers','tc-recipe-searcher')
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
    differences=[]
    for record in records:
        relative = Path(record['path']).relative_to('assets')
        original,regenerated=(ROOT/relative).read_bytes(),(fresh/relative).read_bytes()
        if original!=regenerated:
            differences.append({'path':str(relative),'expected_sha256':digest(original),
                'actual_sha256':digest(regenerated),'decoded_equal':png_read(original)==png_read(regenerated)})
    (output/'regeneration-differences.json').write_text(json.dumps(differences,indent=2)+'\n')
    assert not differences, differences
    assert (ROOT/'sprites.lua').read_bytes()==(fresh/'sprites.lua').read_bytes()
    regenerated_manifest=json.loads((fresh/'manifest.json').read_text())
    # Compression-library build identity is factual host provenance, not an
    # authored input. Different builds may produce the same exact PNG bytes;
    # retain that observation, but never waive any image/source/output hash.
    environment={'original_zlib_version':manifest['transform']['zlib_version'],
                 'regenerated_zlib_version':regenerated_manifest['transform']['zlib_version']}
    (output/'regeneration-environment.json').write_text(json.dumps(environment,indent=2)+'\n')
    regenerated_manifest['transform']['zlib_version']=manifest['transform']['zlib_version']
    assert manifest==regenerated_manifest, 'regenerated manifest differs beyond observed host zlib version'
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
    # Complete correctly scaled contact sheets; wide devices are not shrunk.
    from contact_sheet import main as contact_sheet
    contact_sheet(output/'contact-sheets',None)
    summary={'passed':True,'source_inputs':len(manifest['inputs']),'png_outputs':len(records),
             'glyph_slots':256,'ascii_slots':95,'mosaic_slots':32,'byte_exact_regeneration':True,
             'archive_sha256':digest(archive.read_bytes()),'archive':str(archive),
             'contacts_checked':contacts,'distinct_silhouettes':len(silhouettes),
             'monitor_interior_pixels':60*60,'monitor_bezel_units':2,'monitor_skirt_overhang_units':4,
             'client_evidence':False,'static_checks':'source/output/decoded-alpha hashes, dimensions, transparent bounds, exact socket pixels, exact Foundry monitor skirt and unchanged interior, compact statuses, distinct silhouettes, glyph masks, regeneration, ZIP notices/inventory'}
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
