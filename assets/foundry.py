"""Original MIT Foundry artwork selected from the client-reviewed design study.

Reuse the physical projection, contacts and status masks from industrial.py.
No external texture, model, random state or system font is sampled.
"""
import math
from PIL import Image, ImageDraw
import industrial as base

PALETTE = dict(steel='#716454', side='#4e4336', dark='#292b28',
               edge='#a39677', ink='#171a18', brass='#aa7442',
               amber='#dbb669', glass='#15201c', key='#9a8e71')
# Shared drawing primitives resolve named colors through this original module.
base.PALETTE.update(PALETTE)
status = base.status
shadow = base.shadow


class Drawing(base.Drawing):
    """Bevelled panels with directional light, clustered grime and edge wear."""
    def __init__(self, size, direction):
        super().__init__(size, direction)
        self.serial = 0

    def polygon(self, points, fill, outline=None):
        self.serial += 1
        vertices = [self.point(*p) for p in points]
        mask = Image.new('L', self.image.size)
        ImageDraw.Draw(mask).polygon(vertices, fill=255)
        box = mask.getbbox()
        if not box:
            return
        resolved = base.PALETTE.get(fill, fill)
        assert isinstance(resolved, str)
        color = tuple(bytes.fromhex(resolved.lstrip('#')))
        pixels, mp = self.image.load(), mask.load()
        assert pixels is not None and mp is not None
        left, top, right, bottom = box
        for y in range(top, bottom):
            for x in range(left, right):
                if not mp[x, y]:
                    continue
                noise = ((x*73856093 ^ y*19349663 ^ self.serial*83492791) % 15) - 7
                light = 7 - 16*(y-top)/max(1,bottom-top) - 7*(x-left)/max(1,right-left)
                pits = ((x*37 + y*19 + x*y*3) % 67 == 0)
                grime = 11*(math.sin(x*.19 + math.sin(y*.14)*3)*math.cos(y*.21) > .62)
                delta = noise + light - grime - 20*pits
                pixels[x,y] = tuple(max(0,min(255,round(c+delta))) for c in color) + (255,)
        if outline:
            self.draw.line(vertices+[vertices[0]], fill=base.PALETTE.get(outline, outline), width=1)
        # Discontinuous worn highlights, rather than clean continuous outlines.
        for a,b in zip(vertices,vertices[1:]+vertices[:1]):
            if b[0]-a[0] < 0 and b[1]-a[1] > 0:
                continue
            length = max(abs(b[0]-a[0]), abs(b[1]-a[1]))
            for j in range(2,length,7):
                t=j/max(1,length)
                x=round(a[0]+(b[0]-a[0])*t); y=round(a[1]+(b[1]-a[1])*t)
                self.draw.point((x,y), fill=base.PALETTE['edge'])

    def box(self,x,z,X,Z,h,top='steel',base=0,front=None):
        super().box(x,z,X,Z,h,top,base,front)
        if X-x > .14 and Z-z > .14:
            self.panel(x+.025,z+.025,X-.025,Z-.025,h+.004,top,'side')

    def screw(self,x,z,h,r=.024):
        self.circle(x,z,r,h,'dark','ink')
        self.line([(x-r*.55,z,h+.002),(x+r*.55,z,h+.002)],'edge',1)

    def bolts(self,x,z,X,Z,h):
        for a,b in ((x,z),(X,z),(x,Z),(X,Z)):
            self.screw(a,b,h)

    def vent(self,x,z,X,Z,h):
        self.panel(x,z,X,Z,h,'dark')
        for n in range(max(1,round((X-x)/.07))):
            a=x+.035+n*.07
            self.line([(a,z+.02,h+.003),(a,Z-.02,h+.003)],'ink',2)
            self.line([(a+.02,z+.02,h+.004),(a+.02,Z-.02,h+.004)],'side')

    def cable(self, points, color='brass'):
        self.line(points,'ink',4)
        self.line(points,color,2)

    def gauge(self,x,z,r,h):
        self.circle(x,z,r,h,'brass')
        self.circle(x,z,r*.79,h+.006,'key')
        self.circle(x,z,r*.65,h+.008,'dark')
        for i in range(6):
            a=math.pi*(.2+i*.12)
            self.line([(x+math.cos(a)*r*.48,z-math.sin(a)*r*.48,h+.011),(x+math.cos(a)*r*.64,z-math.sin(a)*r*.64,h+.011)],'key')
        self.line([(x,z,h+.012),(x+r*.45,z-r*.36,h+.012)],'amber',2)

    def keys(self,x,z,cols,rows,h):
        self.panel(x-.025,z-.025,x+cols*.09,z+rows*.075,h,'dark')
        for row in range(rows):
            for col in range(cols):
                self.box(x+col*.09,z+row*.075,x+col*.09+.055,z+row*.075+.045,h+.013,'key',base=h)

    def crt(self,x,z,X,Z,h):
        self.box(x-.035,z-.035,X+.035,Z+.035,h,'dark',base=max(0,h-.10))
        self.panel(x,z,X,Z,h+.005,'ink')
        self.panel(x+.025,z+.025,X-.025,Z-.025,h+.006,'glass')
        for n,length in enumerate((.62,.81,.37)):
            self.line([(x+.06,z+.06+n*.065,h+.008),(x+.06+(X-x-.12)*length,z+.06+n*.065,h+.008)],'amber' if n==0 else 'side')
        self.line([(x+.04,z+.025,h+.009),(X-.07,z+.025,h+.009)],'side')


def computer(p):
    p.box(-.44,-.40,.43,.43,.09,'dark')
    p.box(-.40,-.39,.39,.12,.29)
    p.crt(-.32,-.32,.26,.03,.30)
    p.box(-.40,.13,.40,.40,.105)
    p.keys(-.30,.18,6,2,.11)
    p.box(.31,-.33,.43,.04,.27,'brass')
    p.vent(.33,-.29,.42,.00,.274)
    p.bolts(-.37,-.36,.36,.37,.115)


def cabinet(p):
    p.box(-.41,-.39,.41,.40,.30,'dark')
    for x in (-.43,.33): p.box(x,-.43,x+.10,.43,.36)
    for z in (-.33,-.10,.13):
        p.box(-.29,z,.27,z+.19,.32)
        p.box(-.24,z+.07,.21,z+.12,.35,'brass',base=.32)
        p.panel(-.19,z+.08,.13,z+.105,.354,'ink')
        p.screw(.22,z+.03,.33)
    p.bolts(-.38,-.35,.37,.36,.365)


def monitor(p):
    # Keep the 60x60 active area and original contacts. Only the mechanical skirt
    # overhangs the tile, by four high-resolution pixels on each side.
    c=p.size//2
    p.draw.polygon([(c-32,c-36),(c+31,c-36),(c+35,c-32),(c+35,c+31),(c+31,c+35),(c-32,c+35),(c-36,c+31),(c-36,c-32)],fill=PALETTE['dark'],outline=PALETTE['ink'])
    p.draw.rectangle((c-34,c-34,c+33,c+33),outline='#8a7458',width=2)
    for x in (-34,32):
        for y in (-34,32): p.draw.rectangle((c+x,c+y,c+x+1,c+y+1),fill='#b6a27c')
    p.draw.rectangle((c-32,c-32,c+31,c+31),fill=PALETTE['dark'])
    for y in range(c-32,c+32):
        for x in range(c-32,c+32):
            if x<c-30 or x>=c+30 or y<c-30 or y>=c+30:
                n=(x*31+y*17)%19
                p.draw.point((x,y),fill=('#6f604c' if n<10 else '#8b7452' if n<15 else '#332b23'))
    p.draw.rectangle((c-30,c-30,c+29,c+29),fill=PALETTE['glass'])
    for x in (-31,30):
        for y in (-31,30): p.draw.point((c+x,c+y),fill='#171c18')


def logic(p):
    p.box(-1.46,-.40,1.46,.40,.075,'dark')
    for x in (-1.39,1.27): p.box(x,-.43,x+.12,.43,.15)
    p.box(-.40,-.36,.40,.36,.22)
    p.vent(-.32,-.31,.31,-.05,.226)
    p.gauge(.02,.20,.12,.23)
    for x in (-1.16,-.80,.72,1.08):
        p.box(x-.12,-.30,x+.13,.19,.14,'brass')
        for z in (-.24,-.15,-.06,.03,.12): p.line([(x-.11,z,.145),(x+.12,z,.145)],'dark',2)
        p.circle(x,.29,.06,.15,'key')
    p.cable([(-1.15,.33,.09),(-.55,.35,.10),(-.43,.15,.10)])
    p.cable([(.43,.15,.10),(.56,.35,.10),(1.12,.33,.09)])


def configurator(p):
    p.box(-.94,-.41,.94,.41,.10,'dark')
    p.box(-.85,-.36,-.10,.33,.23)
    p.gauge(-.50,-.01,.27,.24)
    p.box(.02,-.36,.83,.33,.16)
    for x in (.19,.46,.70):
        p.circle(x,.22,.07,.17,'dark')
        p.line([(x,.21,.18),(x+.02,.15,.18)],'key',2)
    p.vent(.13,-.29,.74,-.03,.17)
    p.bolts(-.87,-.35,.86,.35,.105)


def recipe_searcher(p):
    # Open archive bed and raised optical bridge, not another closed cabinet.
    p.box(-.44,-.42,.44,.42,.08,'dark')
    p.box(-.37,-.30,.37,.34,.13)
    p.panel(-.29,-.23,.28,.26,.135,'key','brass')
    for z in (-.16,-.08,0,.08,.16):
        p.line([(-.22,z,.14),(.18,z,.14)],'side')
    for x in (-.42,.32):
        p.box(x,-.39,x+.10,.34,.37,'brass')
    p.box(-.35,-.36,.35,-.20,.39)
    p.panel(-.26,-.31,.26,-.25,.397,'glass','dark')
    p.line([(-.24,-.28,.40),(.23,-.28,.40)],'amber',2)
    p.cable([(.36,-.28,.25),(.40,.12,.18),(.27,.28,.14)])
    p.bolts(-.38,-.37,.37,.36,.09)


DESIGNS={'computer':computer,'kv':cabinet,'monitor':monitor,'logic':logic,'configurator':configurator,
         'recipe_searcher':recipe_searcher}


def body(kind,direction,size,layout):
    p=Drawing(size,direction)
    DESIGNS[kind](p)
    base.contacts(p,kind,layout)
    return p.result()
