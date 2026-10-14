#!/usr/bin/env python3
"""Deterministic Greg Flavored adaptation and independently authored glyphs.

Python 3 stdlib only. Source PNGs remain byte-exact; outputs use RGBA8,
nearest-neighbour texture sampling, fixed oblique projection and fixed PNG
encoding (no timestamps, profiles, ancillary chunks or system fonts).
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parent
INPUT_TRACE = set()
DIRECTIONS = ('north', 'east', 'south', 'west')
FAMILY = {'computer': 1, 'kv': 1, 'monitor': 1, 'logic': 3, 'configurator': 2}
ROLES = {'computer': [('network', 0)], 'kv': [('network', 0)],
         'monitor': [('network', 0)],
         'logic': [('input', -1), ('network', 0), ('output', 1)],
         'configurator': [('network', -0.5), ('target', 0.5)]}
COLORS = {'network': (99, 213, 233), 'input': (249, 199, 96),
          'output': (173, 231, 128), 'target': (217, 159, 235)}


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
        if tag == b'IHDR':
            header = struct.unpack('>IIBBBBB', chunk)
        elif tag == b'IDAT':
            compressed.extend(chunk)
        elif tag == b'IEND':
            break
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
        if alpha == 255 or old[3] == 0:
            pixels[y * w + x] = color
        elif alpha:
            # Straight-alpha source-over, integer arithmetic and rounding.
            total = alpha * 255 + old[3] * (255 - alpha)
            rgb = tuple((color[i] * alpha * 255 + old[i] * old[3] * (255 - alpha) + total // 2) // total for i in range(3))
            pixels[y * w + x] = rgb + ((total + 127) // 255,)


def quad(image, corners, texture, uv=(0, 0, 16, 16), rotation=0, shade=255):
    # Affine inverse at pixel centres; all model faces are parallelograms.
    a, b, d = corners[0], corners[1], corners[3]
    ux, uy, vx, vy = b[0] - a[0], b[1] - a[1], d[0] - a[0], d[1] - a[1]
    determinant = ux * vy - uy * vx
    if abs(determinant) < 1e-9:
        return
    tw, th, pixels = texture
    for y in range(max(0, math.floor(min(p[1] for p in corners))), min(image[1], math.ceil(max(p[1] for p in corners)))):
        for x in range(max(0, math.floor(min(p[0] for p in corners))), min(image[0], math.ceil(max(p[0] for p in corners)))):
            dx, dy = x + 0.5 - a[0], y + 0.5 - a[1]
            u, v = (dx * vy - dy * vx) / determinant, (ux * dy - uy * dx) / determinant
            if 0 <= u < 1 and 0 <= v < 1:
                for _ in range(rotation // 90):
                    u, v = v, 1 - u
                tx = min(tw - 1, max(0, math.floor(uv[0] + u * (uv[2] - uv[0]))))
                ty = min(th - 1, max(0, math.floor(uv[1] + v * (uv[3] - uv[1]))))
                r, g, blue, alpha = pixels[ty * tw + tx]
                paint(image, x, y, (r * shade // 255, g * shade // 255, blue * shade // 255, alpha))


def rotate(x, z, direction):
    for _ in range(direction):
        x, z = -z, x
    return x, z


def project(x, height, z, size):
    return size / 2 + x * 4 - height * 0.75, size / 2 + z * 4 - height * 2


def face_points(lo, hi, face):
    x, h, z = lo
    X, H, Z = hi
    return {
        'north': [(X,H,z),(x,H,z),(x,h,z),(X,h,z)],
        'south': [(x,H,Z),(X,H,Z),(X,h,Z),(x,h,Z)],
        'east': [(X,H,Z),(X,H,z),(X,h,z),(X,h,Z)],
        'west': [(x,H,z),(x,H,Z),(x,h,Z),(x,h,z)],
        'up': [(x,H,z),(X,H,z),(X,H,Z),(x,H,Z)],
        'down': [(x,h,Z),(X,h,Z),(X,h,z),(x,h,z)],
    }[face]


def glyph_patterns():
    INPUT_TRACE.add('assets/glyphs.txt')
    result = {}
    for line in (ROOT / 'glyphs.txt').read_text().splitlines():
        if not line or line.startswith('#'):
            continue
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
                if lit:
                    paint(image, x0 + x, y0 + y, (255, 255, 255, 255))
    return image


def model(source, name):
    path = 'computercraft/models/block/' + name + '.json'
    INPUT_TRACE.add('assets/upstream/' + path)
    obj = json.loads((source / path).read_bytes())
    parent = obj.get('parent', '')
    textures, elements = {}, []
    if parent.startswith('computercraft:'):
        textures, elements = model(source, parent.split('/')[-1])
    textures = {**textures, **obj.get('textures', {})}
    return textures, obj.get('elements', elements)


def texture(source, bindings, name, frame=0):
    seen = set()
    while name.startswith('#'):
        assert name not in seen
        seen.add(name)
        name = bindings[name[1:]]
    namespace, path = name.split(':')
    INPUT_TRACE.add('assets/upstream/' + namespace + '/textures/' + path + '.png')
    w, h, pixels = png_read((source / namespace / 'textures' / (path + '.png')).read_bytes())
    assert w == 16 and h % 16 == 0
    offset = frame % (h // 16) * w * 16
    return w, 16, pixels[offset:offset + w * 16]


def body(source, kind, direction, size):
    image = canvas(size, size)
    bindings, elements = model(source, 'monitor_advanced' if kind == 'monitor' else 'computer_advanced_off')
    for tile in range(FAMILY[kind]):
        center = (tile - (FAMILY[kind] - 1) / 2) * 16
        if kind == 'monitor':
            # Screen-facing model north is deliberately remapped to a ground
            # plane, enabling uniform world-text and touch transforms.
            corners = [rotate(x, z, direction) for x,z in ((-8,-8),(8,-8),(8,8),(-8,8))]
            corners = [project(x,0,z,size) for x,z in corners]
            quad(image, corners, texture(source, bindings, '#case'))
            quad(image, corners, texture(source, bindings, '#overlay'))
            # Exactly two logical units of bezel, no per-tile raised lip.
            corners = [rotate(x,z,direction) for x,z in ((-7.5,-7.5),(7.5,-7.5),(7.5,7.5),(-7.5,7.5))]
            quad(image, [project(x,0,z,size) for x,z in corners], (1,1,[(17,17,17,255)]), uv=(0,0,1,1))
        else:
            # Original cube geometry, UVs, overlay and HV overrides retained.
            for element in elements:
                for face in ('north','east','south','west','up'):
                    if face not in element['faces']:
                        continue
                    normal = {'north':(0,-1),'east':(1,0),'south':(0,1),'west':(-1,0),'up':(0,0)}[face]
                    nx, nz = rotate(*normal, direction)
                    if face != 'up' and nx * -0.75 + nz * 2 <= 0:
                        continue
                    points = face_points(element['from'], element['to'], face)
                    corners = []
                    for x,h,z in points:
                        x,z = rotate(x - 8 + center,z - 8,direction)
                        corners.append(project(x,h,z,size))
                    desc = element['faces'][face]
                    quad(image, corners, texture(source, bindings, desc['texture']),
                         desc.get('uv',(0,0,16,16)), desc.get('rotation',0), 255 if face=='up' else 190)
    # Raised role badges have shapes as well as colors (I / diamond / O / T).
    for role, offset in ROLES[kind]:
        x,z = rotate(offset * 16, 7.75 if kind=='monitor' else 5, direction)
        px,py = project(x, 0 if kind=='monitor' else 16, z, size)
        radius = 0 if kind=='monitor' else 3
        for y in range(-radius,radius+1):
            for x in range(-radius,radius+1):
                lit = {'network': abs(x)+abs(y)==3,
                       'input': x==0 or (abs(y)==3 and abs(x)<=2),
                       'output': max(abs(x),abs(y))==3,
                       'target': y==-3 or x==0}[role]
                paint(image, int(px)+x,int(py)+y, COLORS[role]+(255,) if lit or kind=='monitor' else (26,30,33,255))
    # Independent device identity: etched K, L, C on the top face.
    letter = {'kv':75,'logic':76,'configurator':67}.get(kind)
    if letter:
        rows = glyph_patterns()[letter]
        for y,row in enumerate(rows):
            for x,c in enumerate(row):
                if c=='1':
                    rx,rz = rotate((x-2)/2, (y-3)/2-2,direction)
                    px,py = project(rx,16,rz,size)
                    paint(image,int(px),int(py),(224,235,240,255))
    return image


def status(source, kind, direction, size, state, frame=0):
    image = canvas(size,size)
    if state in ('off','unpowered'):
        return image
    bindings, _ = model(source,'computer_advanced_blinking' if state=='blinking' else 'computer_advanced_on')
    if kind=='computer' and state!='fault':
        # Source-authentic glow on the front when facing the camera.
        nx,nz = rotate(0,-1,direction)
        if nx * -0.75 + nz * 2 > 0:
            corners=[]
            for x,h,z in face_points([0,0,0],[16,16,16],'north'):
                x,z=rotate(x-8,z-8,direction)
                corners.append(project(x,h,z,size))
            quad(image,corners,texture(source,bindings,'#glow',frame),shade=255)
    # Visible status beacon even when front faces away. Fault is red cross;
    # powered is green beacon; its authored blink alternates alongside the
    # four original glow frames. Monitor beacons stay inside the 2-unit bezel.
    color = (239,82,73) if state=='fault' else (145,244,170)
    lit = state != 'blinking' or frame in (0,2)
    if lit:
        radius = 0 if kind=='monitor' else 2
        for y in range(-radius,radius+1):
            for x in range(-radius,radius+1):
                if state!='fault' or abs(x)==abs(y):
                    rx,rz=rotate(x/4, (-7.75 if kind=='monitor' else -5)+y/4,direction)
                    px,py=project(rx,0 if kind=='monitor' else 16,rz,size)
                    paint(image,int(px),int(py),color+(255,))
    return image


def shadow(kind,direction,size):
    image=canvas(size,size)
    width=FAMILY[kind]*8
    corners=[rotate(x,z,direction) for x,z in ((-width,-8),(width,-8),(width,8),(-width,8))]
    corners=[(size/2+x*4+12,size/2+z*4+8) for x,z in corners]
    quad(image,corners,(1,1,[(0,0,0,85)]),uv=(0,0,1,1))
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
    source=ROOT/'upstream'
    audit=json.loads((ROOT/'source-audit.json').read_text())
    records=audit['candidate_models']+audit['candidate_textures']
    records += [r['animation'] for r in audit['candidate_textures'] if 'animation' in r]
    inputs=[]
    for record in records:
        path=record['path'].split('/assets/',1)[1]
        data=(source/path).read_bytes()
        assert digest(data)==record['sha256'], 'changed original: '+path
        entry={'path':'assets/upstream/'+path,'upstream_path':record['path'],'sha256':digest(data),'license':'MIT','notice':'assets/notices/Greg-Flavored-MIT.txt'}
        if path.endswith('.png'):
            w,h,pixels=png_read(data)
            entry.update(width=w,height=h,rgba_sha256=digest(bytes(c for p in pixels for c in p)),alpha_sha256=digest(bytes(p[3] for p in pixels)))
        inputs.append(entry)
    notice=(ROOT/'notices/Greg-Flavored-MIT.txt').read_bytes()
    assert digest(notice)==audit['greg_flavored']['evidence'][0]['sha256']
    output.mkdir(parents=True,exist_ok=True)
    outputs=[]
    INPUT_TRACE.clear()
    def emit(path,image,**metadata):
        data=png_write(image)
        target=output/path
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(data)
        input_paths=sorted(INPUT_TRACE | {'assets/generate.py'})
        notices=['assets/notices/Tweaked-Computers-MIT.txt']
        if any(p.startswith('assets/upstream/') for p in input_paths):
            notices.append('assets/notices/Greg-Flavored-MIT.txt')
        outputs.append({'path':'assets/'+path,'sha256':digest(data),'width':image[0],'height':image[1],
                        'input_paths':input_paths,'license':'MIT','notices':notices,
                        'rgba_sha256':digest(bytes(c for p in image[2] for c in p)),
                        'alpha_sha256':digest(bytes(p[3] for p in image[2])),**metadata})
        INPUT_TRACE.clear()
    devices={}
    for kind,width in FAMILY.items():
        size=160 if width==1 else 320
        devices[kind]={'footprint':[width,1],'directions':{},'roles':ROLES[kind]}
        for direction_index,direction in enumerate(DIRECTIONS):
            prefix='sprites/'+kind+'-'+direction
            meta={'device':kind,'direction':direction,'frame_width':size,'frame_height':size,
                  'pivot':[size//2,size//2],'scale':0.5,'shift':[0,0]}
            base=body(source,kind,direction_index,size)
            emit(prefix+'-body.png',base,layer='body',**meta)
            emit(prefix+'-shadow.png',shadow(kind,direction_index,size),layer='shadow',draw_as_shadow=True,**meta)
            state_paths={}
            for state in ('off','unpowered','powered','fault','blinking'):
                frames=[status(source,kind,direction_index,size,state,f) for f in range(4 if state=='blinking' else 1)]
                emit(prefix+'-'+state+'.png',sheet(frames),layer='status',state=state,frame_count=len(frames),**meta)
                state_paths[state]=prefix+'-'+state+'.png'
            devices[kind]['directions'][direction]={'body':prefix+'-body.png','shadow':prefix+'-shadow.png',
                'states':state_paths,'frame_size':[size,size],'pivot':[size//2,size//2],
                'role_centers':{role:list(rotate(offset,(7.75 if kind=='monitor' else 5)/16,direction_index)) for role,offset in ROLES[kind]}}
        emit('icons/'+kind+'.png',icon(body(source,kind,2,size)),device=kind,layer='icon',icon_size=64)
        devices[kind]['icon']='icons/'+kind+'.png'
    emit('glyphs/atlas.png',glyph_image(),layer='glyph',license='MIT',notice='assets/notices/Tweaked-Computers-MIT.txt',cell=[6,9],columns=16,rows=16)
    manifest={'format_version':1,'status':'implemented-client-verification-deferred',
        'repository':audit['greg_flavored']['repository'],'revision':audit['greg_flavored']['revision'],
        'permission_basis':'User explicitly confirmed selected Greg Flavored files are MIT, not CC:Tweaked assets; no separate legal audit or permission letter claimed.',
        'inputs':inputs,'authored_inputs':[{'path':'assets/'+p,'sha256':digest((ROOT/p).read_bytes())} for p in ('generate.py','glyphs.txt')],
        'notices':[{'path':'assets/notices/'+p.name,'sha256':digest(p.read_bytes())} for p in sorted((ROOT/'notices').iterdir())],
        'transform':{'sampling':'nearest pixel centre','projection':'(4*x - 0.75*h, 4*z - 2*h); source units 1/16 tile; cardinal clockwise rotations',
            'monitor':'north face remapped to flat top, interior 60x60 logical units; 2-unit bezel; ground-centred square',
            'shadow':'ground footprint translated (+12,+8) high-resolution pixels, alpha 85',
            'status':'source computer glow plus authored top beacon; transparent off/unpowered; red-cross fault; four-frame blink',
            'encoder':'RGBA8 filter 0, zlib level 9, no ancillary chunks','zlib_version':zlib.ZLIB_VERSION},
        'devices':devices,'outputs':outputs,
        'glyphs':{'path':'glyphs/atlas.png','cell':[6,9],'columns':16,'rows':16,'slots':256,
            'ascii':[32,126],'mosaic':[128,159],'mosaic_bits':'bits 0..4 row-major 3x3; bottom-right always background',
            'replacement':'all bytes outside ASCII/mosaic map to outlined box; byte 32 and 128 blank',
            'provenance':'glyphs.txt independently authored for Tweaked Computers; no font/image/system-font inputs',
            'foreground':'white opaque mask; transparent background; tint via runtime palette'},
        'deferred':['native client sprite alignment, normal zoom legibility, world glyph presentation, rotations and touch integration']}
    lua=['-- Generated by assets/generate.py; paths are mod-relative and immutable.','local prefix = "__tweaked-computers__/assets/"','local art = {devices = {}, glyphs = {}}']
    def sprite(path,w,h,extra=''):
        return '{filename = prefix .. '+json.dumps(path)+', width = '+str(w)+', height = '+str(h)+', scale = 0.5, shift = {0, 0}'+extra+'}'
    for kind,entry in devices.items():
        lua.append('art.devices.'+kind+' = {icon = prefix .. '+json.dumps(entry['icon'])+', icon_size = 64}')
        for direction,entry_dir in entry['directions'].items():
            size=entry_dir['frame_size'][0]
            lua.append('art.devices.'+kind+'.'+direction+' = {body = '+sprite(entry_dir['body'],size,size)+', shadow = '+sprite(entry_dir['shadow'],size,size,', draw_as_shadow = true')+', states = {}}')
            for state,path in entry_dir['states'].items():
                lua.append('art.devices.'+kind+'.'+direction+'.states.'+state+' = '+sprite(path,size,size,', frame_count = 4, line_length = 4, animation_speed = 0.15' if state=='blinking' else ''))
    lua += ['for byte = 0, 255 do','  art.glyphs[byte] = {filename = prefix .. "glyphs/atlas.png", width = 6, height = 9,',
            '    x = (byte % 16) * 6, y = math.floor(byte / 16) * 9, scale = 1}', 'end','return art']
    (output/'sprites.lua').write_text('\n'.join(lua)+'\n')
    manifest['generated_metadata']=[{'path':'assets/sprites.lua','sha256':digest((output/'sprites.lua').read_bytes())}]
    (output/'manifest.json').write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n')
    print(json.dumps({'outputs':len(outputs),'inputs':len(inputs),'glyph_slots':256,'manifest_sha256':digest((output/'manifest.json').read_bytes())},sort_keys=True))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=ROOT)
    args=parser.parse_args()
    generate(args.output.resolve())


if __name__=='__main__':
    main()
