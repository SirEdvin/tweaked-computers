"""Original editable industrial artwork. Dimensions are tiles, heights are tiles.

Pillow draws authored polygons at final high resolution, without antialiasing or
system fonts. Source geometry rotates before projection; contacts are exported
from the production Lua and deliberately stay at their native world positions.
No Greg Flavored model, texture or promotional image is sampled here.
"""
import math
from typing import cast
from PIL import Image, ImageDraw

PALETTE = {'ink':'#171d1e','steel':'#626a68','edge':'#9a9f90',
           'side':'#3d4645','dark':'#252b2c','brass':'#aa8550',
           'amber':'#d8ad62','glass':'#111d20','key':'#80877a'}


def rotate(x,z,d):
    for _ in range(d):
        x,z=-z,x
    return x,z


class Drawing:
    def __init__(self,size,direction):
        self.size,self.direction=size,direction
        self.image=Image.new('RGBA',(size,size))
        self.draw=ImageDraw.Draw(self.image)

    def point(self,x,z,h=0):
        x,z=rotate(x,z,self.direction)
        return (round(self.size/2+64*x-48*h),round(self.size/2+64*z-128*h))

    def polygon(self,points,fill,outline=None):
        self.draw.polygon([self.point(*p) for p in points],fill=PALETTE.get(fill,fill),
                          outline=PALETTE.get(outline,outline) if outline is not None else None)

    def line(self,points,fill,width=1):
        self.draw.line([self.point(*p) for p in points],fill=PALETTE.get(fill,fill),width=width)

    def panel(self,x,z,X,Z,h,fill,outline='ink'):
        self.polygon([(x,z,h),(X,z,h),(X,Z,h),(x,Z,h)],fill,outline)

    def box(self,x,z,X,Z,h,top='steel',base=0,front=None):
        # Grounded lower shell; upper-left light remains fixed in world space.
        faces=[([(x,z,base),(x,Z,base),(x,Z,h),(x,z,h)],(-1,0)),
               ([(X,z,base),(X,Z,base),(X,Z,h),(X,z,h)],(1,0)),
               ([(x,z,base),(X,z,base),(X,z,h),(x,z,h)],(0,-1)),
               ([(x,Z,base),(X,Z,base),(X,Z,h),(x,Z,h)],(0,1))]
        for points,normal in faces:
            nx,nz=rotate(*normal,self.direction)
            if -0.75*nx+2*nz>0:
                self.polygon(points,front or ('side' if nx<0 else 'dark'),'ink')
        self.panel(x,z,X,Z,h,top)
        self.line([(x,z,h),(X,z,h)],'edge')

    def circle(self,x,z,r,h,fill,outline='ink'):
        self.polygon([(x+math.cos(a*math.pi/16)*r,z+math.sin(a*math.pi/16)*r,h) for a in range(32)],fill,outline)

    def bolts(self,x,z,X,Z,h):
        for a,b in ((x,z),(X,z),(x,Z),(X,Z)):
            px,py=self.point(a,b,h)
            self.draw.rectangle((px-1,py-1,px+1,py+1),fill=PALETTE['ink'])
            self.draw.point((px,py-1),fill=PALETTE['edge'])

    def result(self):
        return self.size,self.size,list(zip(*[iter(self.image.tobytes())]*4))


def computer(p):
    # Chamfered low wedge, not an upright cube. Rear screen and front keybed.
    p.box(-.43,-.39,.43,.40,.07)
    p.polygon([(-.43,-.39,.07),(.43,-.39,.07),(.36,-.37,.23),(-.36,-.37,.23)],'side','ink')
    p.polygon([(-.43,.40,.07),(-.36,-.37,.23),(.36,-.37,.23),(.43,.40,.07)],'steel','ink')
    p.polygon([(-.30,-.31,.215),(.30,-.31,.215),(.33,.06,.138),(-.33,.06,.138)],'glass','ink')
    p.line([(-.24,-.245,.202),(.04,-.245,.202)],'amber')
    p.line([(-.24,-.145,.181),(.18,-.145,.181)],'key')
    p.line([(-.24,-.045,.160),(-.08,-.045,.160)],'key')
    p.panel(-.31,.16,.24,.34,.105,'dark')
    for z in (.19,.25,.30):
        for x in (-.26,-.17,-.08,.01,.10,.19):
            p.panel(x,z,x+.055,z+.025,.107,'key',None)
    p.panel(-.16,.35,.15,.375,.08,'dark')
    for z in (.16,.22,.28,.34):
        p.line([(.31,z,.10),(.38,z,.10)],'ink')
    p.bolts(-.38,-.34,.38,.37,.08)


def cabinet(p):
    # Tall ribbed storage bank. Exposed cartridge handles, no glass/keybed.
    p.box(-.39,-.39,.39,.39,.31,'dark')
    p.box(-.43,-.42,-.33,.42,.35)
    p.box(.30,-.42,.42,.42,.35)
    for z in (-.34,-.10,.14):
        p.box(-.29,z,.25,z+.19,.32,'steel',base=.29)
        p.panel(-.23,z+.04,.15,z+.13,.324,'dark')
        p.line([(-.15,z+.09,.325),(.10,z+.09,.325)],'edge',2)
        p.panel(.18,z+.05,.22,z+.11,.325,'brass')
    for z in (-.33,-.21,-.09,.03,.15,.27):
        p.line([(.34,z,.352),(.39,z,.352)],'ink')
    p.bolts(-.38,-.36,.36,.35,.355)
    # Cartridge fronts on the cabinet walls, with shaded folded-metal handles.
    # Only visible faces are painted, so a rear face cannot overpaint the top.
    for z,normal in ((-.395,(0,-1)),(.395,(0,1))):
        nx,nz=rotate(*normal,p.direction)
        if -.75*nx+2*nz>0:
            for h in (.045,.125,.205):
                p.polygon([(-.28,z,h),(.25,z,h),(.25,z,h+.055),(-.28,z,h+.055)],'dark','ink')
                p.line([(-.20,z,h+.035),(.12,z,h+.035)],'edge')
                p.line([(.19,z,h+.015),(.19,z,h+.045)],'brass')
    for x,normal in ((-.395,(-1,0)),(.395,(1,0))):
        nx,nz=rotate(*normal,p.direction)
        if -.75*nx+2*nz>0:
            for z in (-.27,-.13,.01,.15,.29):
                p.line([(x,z,.04),(x,z,.27)],'side',2)


def monitor(p):
    # Exactly 64 logical units, 60x60 cell area and two-unit bezel.
    # Pillow rectangle endpoints are inclusive: use half-open physical bounds
    # explicitly instead of accidentally creating a 65px panel / 61px interior.
    c=p.size//2
    p.draw.rectangle((c-32,c-32,c+31,c+31),fill=PALETTE['edge'])
    p.draw.rectangle((c-31,c-31,c+31,c+31),fill=PALETTE['steel'])
    p.draw.line((c+31,c-32,c+31,c+31,c-32,c+31),fill=PALETTE['dark'])
    p.draw.rectangle((c-30,c-30,c+29,c+29),fill=PALETTE['glass'])


def logic(p):
    # A single low continuous instrument with common front rail and end cheeks.
    p.box(-1.44,-.42,1.44,.42,.13)
    p.box(-1.47,-.44,-1.37,.44,.19,'dark')
    p.box(1.37,-.44,1.47,.44,.19,'dark')
    for x in (-.50,.50):
        p.line([(x,-.36,.133),(x,.36,.133)],'dark')
    # Continuous case rails and recessed processing sockets, not separate boxes.
    p.line([(-1.32,-.37,.14),(1.32,-.37,.14)],'edge')
    for x in (-1.25,-1.13,-1.01,-.89,-.77,.77,.89,1.01,1.13,1.25):
        p.line([(x,-.34,.14),(x,-.23,.14)],'dark')
    p.panel(-.38,-.35,.38,-.19,.138,'glass')
    for x in (-.29,-.17,-.05,.07,.19,.29):
        p.line([(x,-.30,.14),(x,-.235,.14)],'amber')
    # Distinct signal traces/arrowheads in the end bays, not repeated consoles.
    for x in (-1.0,1.0):
        p.line([(x-.25,.23,.14),(x+.24,.23,.14)],'brass',2)
        p.line([(x+.10,.12,.14),(x+.24,.23,.14),(x+.10,.34,.14)],'edge',2)
        for z in (-.32,-.26):
            p.line([(x-.22,z,.14),(x+.22,z,.14)],'dark')
    p.panel(-.34,.17,.34,.33,.14,'dark')
    for x in (-.26,-.13,0,.13,.26):
        p.panel(x,.20,x+.055,.28,.145,'brass')
    p.line([(-1.34,.37,.14),(1.34,.37,.14)],'edge')
    p.bolts(-1.40,-.37,1.40,.37,.195)


def configurator(p):
    p.box(-.93,-.42,.93,.42,.15)
    p.box(-.97,-.44,-.87,.44,.20,'dark')
    p.box(.87,-.44,.97,.44,.20,'dark')
    p.line([(0,-.36,.153),(0,.36,.153)],'ink')
    # Service dial occupies the first bay; second bay is a factory terminal bank.
    p.circle(-.52,.22,.19,.17,'brass')
    p.circle(-.52,.22,.14,.175,'dark')
    p.line([(-.52,.22,.18),(-.45,.12,.18)],'amber',2)
    for x in (-.72,-.62,-.52,-.42,-.32):
        p.line([(x,-.31,.16),(x+.04,-.25,.16)],'key')
    p.panel(.13,.12,.77,.34,.16,'dark')
    for x in (.20,.37,.54,.69):
        for z in (.17,.28):
            p.panel(x,z,x+.055,z+.035,.165,'brass')
    p.panel(.16,-.33,.73,-.22,.16,'glass')
    p.line([(.23,-.28,.165),(.63,-.28,.165)],'amber')
    p.bolts(-.90,-.38,.90,.38,.205)


DESIGNS={'computer':computer,'kv':cabinet,'monitor':monitor,'logic':logic,'configurator':configurator}


def contacts(p,kind,layout):
    # Draw at native wire positions, without the body-height projection. The
    # terminal bridges mount on the near face of each instrument's role bay.
    for role,entry in layout.items():
        red,green=entry['contacts']['red'],entry['contacts']['green']
        a=p.point(0,0)  # Native contacts are already cardinally transformed.
        def xy(point):
            return round(a[0]+64*point[0]),round(a[1]+64*point[1])
        rx,ry=xy(red); gx,gy=xy(green)
        if kind=='monitor':
            # One high-resolution pixel fits the fixed 2-unit bezel.
            p.draw.point((rx,ry),fill='#dd7867')
            p.draw.point((gx,gy),fill='#93ba78')
            continue
        box=(min(rx,gx)-3,min(ry,gy)-3,max(rx,gx)+3,max(ry,gy)+3)
        p.draw.rectangle(box,fill=PALETTE['ink'],outline=PALETTE['brass'])
        for x,y,color in ((rx,ry,'#dd7867'),(gx,gy,'#93ba78')):
            p.draw.rectangle((x-1,y-1,x+1,y+1),fill=color)
            p.draw.point((x,y),fill='#ead8a2')
        # Orientation-aware role pictograms beside the bridge: diamond, incoming
        # chevron, outgoing double chevron or service crosshair. No letter labels.
        cx=(rx+gx)/2; cy=(ry+gy)/2
        dx,dy=rotate(0,.12,p.direction)
        cx+=dx*64; cy+=dy*64
        color=tuple(round(c*255) for c in entry['color'])+(255,)
        def line(points):
            coords=[]
            for x,y in points:
                x,y=rotate(x,y,p.direction)
                coords.append((round(cx+x),round(cy+y)))
            p.draw.line(coords,fill=color,width=1)
        if role=='network': line([(0,-3),(3,0),(0,3),(-3,0),(0,-3)])
        elif role=='input': line([(-2,-3),(1,0),(-2,3)])
        elif role=='output':
            for shift in (-2,1): line([(shift-1,-3),(shift+2,0),(shift-1,3)])
        else:
            line([(-3,0),(3,0)]); line([(0,-3),(0,3)])


def body(kind,direction,size,layout):
    p=Drawing(size,direction)
    DESIGNS[kind](p)
    # Deterministic fine cast-metal grain. No external textures, image noise or
    # mutable random state; preserve glass, symbols and precise contact pixels.
    surfaces={tuple(bytes.fromhex(PALETTE[key][1:])) for key in ('steel','side','dark')}
    pixels=p.image.load()
    assert pixels is not None
    for y in range(size):
        for x in range(size):
            rgba=cast(tuple[int,int,int,int],pixels[x,y])
            if rgba[:3] in surfaces:
                grain=((x*73856093 ^ y*19349663) % 9)-4
                pixels[x,y]=tuple(max(0,min(255,c+grain)) for c in rgba[:3])+(255,)
    contacts(p,kind,layout)
    return p.result()


def status(kind,direction,size,state,frame=0):
    p=Drawing(size,direction)
    h={'computer':.08,'kv':.355,'monitor':0,'logic':.14,'configurator':.16,'recipe_searcher':.13,'factoriopedia_interface':.1,'production_statistics':.12,'dashboard':.10}[kind]
    x,z=(.28,.48) if kind=='monitor' else ({'computer':-.34,'kv':.34,'logic':.40,'configurator':-.13,'recipe_searcher':-.27,'factoriopedia_interface':-.3,'production_statistics':-.35,'dashboard':-.34}[kind],.30)
    cx,cy=p.point(x,z,h)
    if kind=='monitor':
        # Bezel width is two units: compact line symbols along the edge.
        pixels={'off':[(0,0)],'unpowered':[(-1,0),(1,0)],'powered':[(-1,0),(0,0),(1,0)],
                'fault':[(-2,0),(0,0),(2,0)],'blinking':[(0,0)]}[state]
    else:
        pixels={'off':[(-1,0),(0,0),(1,0)],'unpowered':[(-1,1),(0,0),(1,-1)],
                'powered':[(-1,0),(0,-1),(0,0),(1,0),(0,1)],
                'fault':[(-2,-2),(-1,-1),(0,0),(1,1),(2,2),(-2,2),(-1,1),(1,-1),(2,-2)],
                'blinking':[(-1,0),(0,-1),(0,0),(1,0),(0,1)]}[state]
    color={'off':'#9a9f90','unpowered':'#d8ad62','powered':'#a8cf86','fault':'#ef6551','blinking':'#d8ad62'}[state]
    if state=='blinking' and frame%2: color='#626a68'
    for x,y in pixels:
        x,y=rotate(x,y,direction)
        p.draw.point((cx+x,cy+y),fill=color)
    return p.result()


def shadow(kind,direction,size,width):
    p=Drawing(size,direction)
    if kind=='monitor': height=.025
    else: height={'computer':.23,'kv':.35,'logic':.19,'configurator':.20,'recipe_searcher':.39}[kind]
    # Fixed world-space light, silhouette follows the footprint and body height.
    a,b=width/2-.04,.43
    points=[rotate(x,z,direction) for x,z in ((-a+.07,-b),(a-.07,-b),(a,-b+.07),
        (a,b-.07),(a-.07,b),(-a+.07,b),(-a,b-.07),(-a,-b+.07))]
    points=[(round(size/2+64*x+height*42),round(size/2+64*z+height*28)) for x,z in points]
    p.draw.polygon(points,fill=(0,0,0,85))
    return p.result()
