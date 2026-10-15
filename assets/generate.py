#!/usr/bin/env python3
"""Deterministic original industrial family and independently authored glyphs.

Editable device geometry is in industrial.py. Socket coordinates are exported
from production Lua by export_layout.py. No upstream image is sampled; historical
approved Greg Flavored inputs/notices remain byte-exact for source continuity.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parent
INPUT_TRACE = set()
DIRECTIONS = ('north', 'east', 'south', 'west')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def png_read(data):
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    pos, compressed, header = 8, bytearray(), None
    while pos < len(data):
        size = struct.unpack('>I', data[pos:pos + 4])[0]
        tag, chunk = data[pos + 4:pos + 8], data[pos + 8:pos + 8 + size]
        assert zlib.crc32(tag + chunk) & 0xffffffff == struct.unpack('>I', data[pos + 8 + size:pos + 12 + size])[0]
        pos += size + 12
        if tag == b'IHDR': header = struct.unpack('>IIBBBBB', chunk)
        elif tag == b'IDAT': compressed.extend(chunk)
        elif tag == b'IEND': break
    assert header is not None
    w, h, depth, color, compression, filtering, interlace = header
    assert (depth, color, compression, filtering, interlace) == (8, 6, 0, 0, 0)
    raw = zlib.decompress(compressed)
    assert len(raw) == h * (1 + w * 4)
    out, previous = [], [0] * (w * 4)
    for y in range(h):
        offset = y * (1 + w * 4)
        kind, row = raw[offset], list(raw[offset + 1:offset + 1 + w * 4])
        assert kind in range(5)
        for x in range(w * 4):
            a, b, c = (row[x - 4] if x >= 4 else 0), previous[x], (previous[x - 4] if x >= 4 else 0)
            p = a + b - c
            pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
            predictors = (0, a, b, (a + b) // 2, a if pa <= pb and pa <= pc else b if pb <= pc else c)
            row[x] = (row[x] + predictors[kind]) & 255
        out.extend(tuple(row[x:x + 4]) for x in range(0, w * 4, 4))
        previous = row
    return w, h, out


def png_write(image):
    w, h, pixels = image
    def chunk(tag, value):
        return struct.pack('>I', len(value)) + tag + value + struct.pack('>I', zlib.crc32(tag + value) & 0xffffffff)
    raw = b''.join(b'\0' + bytes(c for p in pixels[y * w:(y + 1) * w] for c in p) for y in range(h))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def canvas(w, h):
    return w, h, [(0, 0, 0, 0)] * (w * h)


def paint(image, x, y, color):
    w, h, pixels = image
    if 0 <= x < w and 0 <= y < h:
        old, alpha = pixels[y * w + x], color[3]
        if alpha == 255 or old[3] == 0: pixels[y * w + x] = color
        elif alpha:
            total = alpha * 255 + old[3] * (255 - alpha)
            rgb = tuple((color[i] * alpha * 255 + old[i] * old[3] * (255 - alpha) + total // 2) // total for i in range(3))
            pixels[y * w + x] = rgb + ((total + 127) // 255,)


def glyph_patterns():
    INPUT_TRACE.add('assets/glyphs.txt')
    result = {}
    for line in (ROOT / 'glyphs.txt').read_text().splitlines():
        if not line or line.startswith('#'): continue
        byte, *rows = line.split()
        byte = int(byte)
        assert byte not in result and len(rows) == 7
        assert all(len(r) == 5 and set(r) <= {'0', '1'} for r in rows)
        result[byte] = rows
    assert set(result) == set(range(32, 127))
    return result


def glyph_image():
    patterns, image = glyph_patterns(), canvas(96, 144)
    for byte in range(256):
        x0, y0 = byte % 16 * 6, byte // 16 * 9
        for y in range(9):
            for x in range(6):
                if byte in patterns:
                    lit = 1 <= y <= 7 and x < 5 and patterns[byte][y - 1][x] == '1'
                elif 128 <= byte <= 159:
                    bit = y // 3 * 2 + x // 3
                    lit = bit < 5 and (byte - 128) & (1 << bit)
                else:
                    lit = (x in (0, 4) and 1 <= y <= 7) or (y in (1, 7) and x <= 4)
                if lit: paint(image, x0 + x, y0 + y, (255, 255, 255, 255))
    return image


def sheet(images):
    w,h,_=images[0]
    out=canvas(w*len(images),h)
    for i,image in enumerate(images):
        for y in range(h):
            out[2][y*out[0]+i*w:y*out[0]+(i+1)*w]=image[2][y*w:(y+1)*w]
    return out


def icon(image):
    w,h,pixels=image
    visible=[(i%w,i//w) for i,p in enumerate(pixels) if p[3]]
    left,top=min(x for x,y in visible),min(y for x,y in visible)
    right,bottom=max(x for x,y in visible)+1,max(y for x,y in visible)+1
    factor=56/max(right-left,bottom-top)
    out=canvas(64,64)
    iw,ih=round((right-left)*factor),round((bottom-top)*factor)
    for y in range(ih):
        for x in range(iw):
            paint(out,(64-iw)//2+x,(64-ih)//2+y,pixels[(top+int(y/factor))*w+left+int(x/factor)])
    return out


def generate(output):
    import industrial
    import PIL
    layout=json.loads((ROOT/'socket-layout.json').read_text())
    assert digest((ROOT.parent/layout['source']['path']).read_bytes())==layout['source']['sha256'], 'stale socket export; run export_layout.py'
    audit=json.loads((ROOT/'source-audit.json').read_text())
    records=audit['candidate_models']+audit['candidate_textures']
    records += [r['animation'] for r in audit['candidate_textures'] if 'animation' in r]
    inputs=[]
    for record in records:
        path=record['path'].split('/assets/',1)[1]
        data=(ROOT/'upstream'/path).read_bytes()
        assert digest(data)==record['sha256'], 'changed original: '+path
        entry={'path':'assets/upstream/'+path,'upstream_path':record['path'],'sha256':digest(data),'license':'MIT','notice':'assets/notices/Greg-Flavored-MIT.txt','usage':'retained historical source; not sampled by RD2'}
        if path.endswith('.png'):
            w,h,pixels=png_read(data)
            entry.update(width=w,height=h,rgba_sha256=digest(bytes(c for p in pixels for c in p)),alpha_sha256=digest(bytes(p[3] for p in pixels)))
        inputs.append(entry)
    assert digest((ROOT/'notices/Greg-Flavored-MIT.txt').read_bytes())==audit['greg_flavored']['evidence'][0]['sha256']
    output.mkdir(parents=True,exist_ok=True)
    outputs=[]
    INPUT_TRACE.clear()
    device_inputs={'assets/industrial.py','assets/socket-layout.json','scripts/device-definitions.lua','assets/layout-data.lua','assets/export_layout.py','assets/requirements.txt'}
    def emit(path,image,**metadata):
        data=png_write(image)
        target=output/path
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(data)
        input_paths=sorted(INPUT_TRACE | {'assets/generate.py'})
        outputs.append({'path':'assets/'+path,'sha256':digest(data),'width':image[0],'height':image[1],
            'input_paths':input_paths,'license':'MIT','notices':['assets/notices/Tweaked-Computers-MIT.txt'],
            'rgba_sha256':digest(bytes(c for p in image[2] for c in p)),
            'alpha_sha256':digest(bytes(p[3] for p in image[2])),**metadata})
        INPUT_TRACE.clear()
    devices={}
    for kind,entry in layout['devices'].items():
        width=entry['width']; size=160 if width==1 else 320
        devices[kind]={'footprint':[width,1],'directions':{}}
        for d,direction in enumerate(DIRECTIONS):
            prefix='sprites/'+kind+'-'+direction
            meta={'device':kind,'direction':direction,'frame_width':size,'frame_height':size,
                  'pivot':[size//2,size//2],'scale':0.5,'shift':[0,0]}
            roles=entry['directions'][direction]
            def emit_device(path,image,**metadata):
                INPUT_TRACE.update(device_inputs)
                emit(path,image,**metadata)
            emit_device(prefix+'-body.png',industrial.body(kind,d,size,roles),layer='body',**meta)
            emit_device(prefix+'-shadow.png',industrial.shadow(kind,d,size,width),layer='shadow',draw_as_shadow=True,**meta)
            state_paths={}
            for state in ('off','unpowered','powered','fault','blinking'):
                frames=[industrial.status(kind,d,size,state,f) for f in range(4 if state=='blinking' else 1)]
                emit_device(prefix+'-'+state+'.png',sheet(frames),layer='status',state=state,frame_count=len(frames),**meta)
                state_paths[state]=prefix+'-'+state+'.png'
            devices[kind]['directions'][direction]={'body':prefix+'-body.png','shadow':prefix+'-shadow.png',
                'states':state_paths,'frame_size':[size,size],'pivot':[size//2,size//2],
                'roles':roles}
        INPUT_TRACE.update(device_inputs)
        emit('icons/'+kind+'.png',icon(industrial.body(kind,2,size,entry['directions']['south'])),device=kind,layer='icon',icon_size=64)
        devices[kind]['icon']='icons/'+kind+'.png'
    emit('glyphs/atlas.png',glyph_image(),layer='glyph',cell=[6,9],columns=16,rows=16)
    # Opaque authored mask: sprites, unlike runtime rectangles, support layers.
    emit('glyphs/pixel.png',(1,1,[(255,255,255,255)]),layer='display-fill')
    authored=['assets/generate.py','assets/glyphs.txt',*sorted(device_inputs)]
    manifest={'format_version':2,'status':'implemented-client-verification-deferred',
        'repository':audit['greg_flavored']['repository'],'revision':audit['greg_flavored']['revision'],
        'permission_basis':'Original RD2 device geometry and independent glyphs are project MIT. Approved historical Greg Flavored originals/notices retained unchanged; not sampled by new art.',
        'inputs':inputs,'authored_inputs':[{'path':p,'sha256':digest((ROOT.parent/p).read_bytes())} for p in authored],
        'notices':[{'path':'assets/notices/'+p.name,'sha256':digest(p.read_bytes())} for p in sorted((ROOT/'notices').iterdir())],
        'transform':{'sampling':'Pillow integer polygon rasterization; no antialiasing; nearest-neighbour icon fitting',
            'projection':'64*x - 48*height, 64*z - 128*height; tile units; geometry rotated clockwise before projection; fixed world light',
            'monitor':'flat 64x64 logical units; interior 60x60; two-unit bezel; unchanged ground pivot',
            'contacts':'socket-layout.json exported from production defs.contact/offset in Factorio 2.0.77; projected at ground coordinates',
            'shadow':'footprint cast toward world southeast proportional to body height, alpha 85',
            'status':'grey dash stopped; amber slash unpowered; green powered; red fault cross; amber/steel four-frame activity',
            'encoder':'RGBA8 filter 0, zlib level 9, no ancillary chunks','zlib_version':zlib.ZLIB_VERSION,'pillow_version':PIL.__version__},
        'palette':industrial.PALETTE,'devices':devices,'outputs':outputs,
        'glyphs':{'path':'glyphs/atlas.png','cell':[6,9],'columns':16,'rows':16,'slots':256,
            'ascii':[32,126],'mosaic':[128,159],'mosaic_bits':'bits 0..4 row-major 3x3; bottom-right always background',
            'replacement':'all bytes outside ASCII/mosaic map to outlined box; byte 32 and 128 blank',
            'provenance':'glyphs.txt independently authored for Tweaked Computers; no font/image/system-font inputs',
            'foreground':'white opaque mask; transparent background; tint via runtime palette'},
        'deferred':['native client sprite alignment, normal zoom legibility, world glyph presentation, rotations and touch integration']}
    lua=['-- Generated by assets/generate.py; paths are mod-relative and immutable.','local prefix = "__tweaked-computers__/assets/"','local art = {devices = {}, glyphs = {}}']
    def sprite(path,w,h,extra=''):
        return '{filename = prefix .. '+json.dumps(path)+', width = '+str(w)+', height = '+str(h)+', scale = 0.5, shift = {0, 0}'+extra+'}'
    def lua_value(value):
        if isinstance(value, dict):
            return '{'+','.join('['+json.dumps(k)+']='+lua_value(v) for k,v in sorted(value.items()))+'}'
        if isinstance(value, list): return '{'+','.join(lua_value(v) for v in value)+'}'
        return json.dumps(value)
    for kind,entry in devices.items():
        lua.append('art.devices.'+kind+' = {icon = prefix .. '+json.dumps(entry['icon'])+', icon_size = 64}')
        for direction,entry_dir in entry['directions'].items():
            size=entry_dir['frame_size'][0]
            lua.append('art.devices.'+kind+'.'+direction+' = {roles = '+lua_value(entry_dir['roles'])+', body = '+sprite(entry_dir['body'],size,size)+', shadow = '+sprite(entry_dir['shadow'],size,size,', draw_as_shadow = true')+', states = {}}')
            for state,path in entry_dir['states'].items():
                lua.append('art.devices.'+kind+'.'+direction+'.states.'+state+' = '+sprite(path,size,size,', frame_count = 4, line_length = 4, animation_speed = 0.15' if state=='blinking' else ''))
    lua += ['for byte = 0, 255 do','  art.glyphs[byte] = {filename = prefix .. "glyphs/atlas.png", width = 6, height = 9,',
            '    x = (byte % 16) * 6, y = math.floor(byte / 16) * 9, scale = 1}', 'end','return art']
    (output/'sprites.lua').write_text('\n'.join(lua)+'\n')
    manifest['generated_metadata']=[{'path':'assets/sprites.lua','sha256':digest((output/'sprites.lua').read_bytes())}]
    (output/'manifest.json').write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n')
    print(json.dumps({'outputs':len(outputs),'inputs':len(inputs),'glyph_slots':256,'manifest_sha256':digest((output/'manifest.json').read_bytes())},sort_keys=True))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=ROOT)
    generate(parser.parse_args().output.resolve())
