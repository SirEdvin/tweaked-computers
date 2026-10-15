#!/usr/bin/env python3
"""Asset contact sheets, never native-client screenshots. Output outside git."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from generate import ROOT, DIRECTIONS

KINDS=('computer','kv','monitor','logic','configurator')
NAMES={'computer':'Operator console','kv':'Cartridge database','monitor':'Flat monitor',
       'logic':'Three-bay logic instrument','configurator':'Two-bay configurator'}


def font(size):
    # Pillow's bundled label font; no source artwork depends on this font.
    return ImageFont.load_default(size=size)


def background(w,h):
    image=Image.new('RGBA',(w,h),'#353c39')
    draw=ImageDraw.Draw(image)
    for x in range(0,w,16): draw.line((x,0,x,h),fill='#3a423e')
    for y in range(0,h,16): draw.line((0,y,w,y),fill='#3a423e')
    return image


def composite(kind,direction,state='powered',frame=0):
    prefix=ROOT/f'sprites/{kind}-{direction}'
    body=Image.open(str(prefix)+'-body.png').convert('RGBA')
    shadow=Image.open(str(prefix)+'-shadow.png').convert('RGBA')
    status=Image.open(str(prefix)+'-'+state+'.png').convert('RGBA')
    size=body.width
    status=status.crop((frame*size,0,(frame+1)*size,size))
    return Image.alpha_composite(Image.alpha_composite(shadow,body),status)


def place(image,sprite,cx,cy,scale):
    resized=sprite.resize((round(sprite.width*scale),round(sprite.height*scale)),Image.Resampling.NEAREST)
    image.alpha_composite(resized,(round(cx-resized.width/2),round(cy-resized.height/2)))


def label(image,xy,text,size=14):
    ImageDraw.Draw(image).text(xy,text,font=font(size),fill='#eee8d5')


def reference(image,x,y,tile):
    # Exact vanilla footprint/frame scale from 2.0.77 combinator-pictures.lua.
    # An outline is intentional: the official headless engine has no PNGs.
    draw=ImageDraw.Draw(image)
    draw.rectangle((x-tile/2,y-tile,x+tile/2,y+tile),outline='#d8ad62',width=1)
    draw.rectangle((x-36*tile/32,y-31*tile/32,x+36*tile/32,y+31*tile/32),outline='#80877a',width=1)
    label(image,(x+tile*1.3,y-18),'Vanilla arithmetic: 1 x 2 tiles',12)
    label(image,(x+tile*1.3,y),'144 x 124 frame, scale 0.5',12)
    label(image,(x+tile*1.3,y+18),'Bounds only; not rendered vanilla art',12)


def main(output,vanilla):
    assert not output.exists() and not output.resolve().is_relative_to(ROOT.parent)
    output.mkdir(parents=True)
    manifest=json.loads((ROOT/'manifest.json').read_text())
    products=[]
    def save(name,image):
        path=output/name; image.save(path,compress_level=9)
        products.append({'path':name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':list(image.size)})
    ordinary=background(1000,710)
    label(ordinary,(20,14),'Original industrial family / 32 pixels per tile (ordinary scale)',22)
    label(ordinary,(20,46),'Asset compositing only. Columns north, east, south, west. No native-client acceptance.',14)
    for row,kind in enumerate(KINDS):
        y=112+row*96
        label(ordinary,(16,y-28),NAMES[kind],14)
        for col,direction in enumerate(DIRECTIONS):
            place(ordinary,composite(kind,direction),360+col*165,y,.5)
    reference(ordinary,80,635,32)
    save('family-ordinary.png',ordinary)
    enlarged=background(1800,2790)
    label(enlarged,(24,18),'Industrial family / 128 pixels per tile (4x ordinary)',25)
    label(enlarged,(24,54),'North                         East                          South                         West',20)
    for row,kind in enumerate(KINDS):
        y=340+row*470
        label(enlarged,(24,y-235),NAMES[kind],22)
        for col,direction in enumerate(DIRECTIONS):
            place(enlarged,composite(kind,direction),225+col*450,y,2)
    reference(enlarged,200,2650,64)
    if vanilla:
        # Separately labelled illustration: wiki promotional framing is not a
        # calibrated world sprite and must not masquerade as a scale sample.
        image=Image.open(vanilla).convert('RGBA')
        image.thumbnail((180,120),Image.Resampling.NEAREST)
        enlarged.alpha_composite(image,(1100,2610))
        label(enlarged,(1000,2740),'Wiki arithmetic illustration (not scale-calibrated)',13)
    save('family-enlarged.png',enlarged)
    sockets=background(1600,1680)
    label(sockets,(24,18),'Wire/contact audit / 64 pixels per tile',25)
    label(sockets,(24,54),'Lines end at exported native contacts. Role pad bounds are thin blue outlines. Not client wiring.',16)
    for row,kind in enumerate(KINDS):
        y=250+row*285
        label(sockets,(24,y-140),NAMES[kind],19)
        for col,direction in enumerate(DIRECTIONS):
            cx=200+col*400; cy=y
            place(sockets,composite(kind,direction),cx,cy,1)
            draw=ImageDraw.Draw(sockets)
            roles=manifest['devices'][kind]['directions'][direction]['roles']
            for role,entry in roles.items():
                if role!='network':
                    x,z=entry['center']
                    draw.rectangle((cx+(x-.22)*64,cy+(z-.22)*64,cx+(x+.22)*64,cy+(z+.22)*64),outline='#72abc1')
                for color,(x,z) in entry['contacts'].items():
                    dx,dz=((0,-1),(1,0),(0,1),(-1,0))[col]
                    px,py=cx+x*64,cy+z*64
                    draw.line((px+dx*40,py+dz*40,px,py),fill='#f28477' if color=='red' else '#a8ce8a',width=1)
                    draw.ellipse((px-2,py-2,px+2,py+2),outline='#eee8d5')
    reference(sockets,160,1610,32)
    save('socket-overlay.png',sockets)
    states=('off','unpowered','powered','fault','blinking','blinking','blinking','blinking')
    state_sheet=background(1920,3460)
    label(state_sheet,(24,16),'Every device / direction / status frame, 64 pixels per tile',24)
    for col,state in enumerate(states):
        label(state_sheet,(col*240+20,62),state+(str(col-4) if col>=4 else ''),16)
    inventory=[]
    for row,(kind,direction) in enumerate((k,d) for k in KINDS for d in DIRECTIONS):
        cy=180+row*165
        label(state_sheet,(10,cy-78),kind+' / '+direction,13)
        for col,state in enumerate(states):
            frame=col-4 if col>=4 else 0
            place(state_sheet,composite(kind,direction,state,frame),120+col*240,cy,1)
            inventory.append([kind,direction,state,frame])
    save('all-status-frames.png',state_sheet)
    icons=background(1000,350)
    label(icons,(24,16),'Inventory icons / 32, 64 and 128 pixels',22)
    for col,kind in enumerate(KINDS):
        image=Image.open(ROOT/f'icons/{kind}.png').convert('RGBA')
        x=100+col*200
        label(icons,(x-70,60),kind,18)
        for cy,scale in ((105,.5),(165,1),(260,2)): place(icons,image,x,cy,scale)
    save('icons.png',icons)
    data={'native_client':False,'directions':list(DIRECTIONS),'devices':list(KINDS),
        'status_samples':inventory,'status_sample_count':len(inventory),
        'vanilla_scale_reference':'2.0.77 arithmetic-combinator footprint 1x2, sprite 144x124 at scale .5; outline only',
        'products':products}
    if vanilla:
        data['vanilla_illustration']={'source':'https://wiki.factorio.com/images/Arith_combinator_anim.png',
            'sha256':hashlib.sha256(vanilla.read_bytes()).hexdigest(),
            'notice':'Factorio artwork copyright Wube Software; external review illustration only, not shipped mod artwork; not calibrated'}
    (output/'index.json').write_text(json.dumps(data,indent=2)+'\n')
    (output/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>RD2 asset contact sheets</title>'
        '<style>body{background:#252b2c;color:#eee8d5;font:16px sans-serif;margin:24px}img{max-width:100%;height:auto}a{color:#d8ad62}</style>'
        '<h1>RD2 asset contact sheets</h1><p>Generated image inspection, not Factorio client screenshots. '
        'Native selection, wire alignment, monitor overlays and readability still require user review.</p>'+
        ''.join('<h2>'+r['path']+'</h2><a href="'+r['path']+'">Open full size</a><br><img src="'+r['path']+'">' for r in products))
    print(json.dumps({'output':str(output),'products':len(products),'status_samples':len(inventory)}))


if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--vanilla-illustration',type=Path)
    args=ap.parse_args(); main(args.output.resolve(),args.vanilla_illustration)
