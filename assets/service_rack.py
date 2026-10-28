"""Original MIT Service Rack geometry selected from AR2 candidate B.

Tile-unit editable meshes, depth-buffered facets, world-fixed lighting and
geometry-projected shadows. No reference pixels or models are sampled.
"""
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import foundry
import industrial

if not hasattr(math, 'fma'):
    raise RuntimeError('Service Rack offline regeneration requires Python 3.13+ (math.fma)')

MATERIALS = {
    'cast': (95, 91, 76), 'edge': (147, 139, 111),
    'iron': (65, 71, 69), 'black': (29, 34, 32),
    'copper': (155, 102, 59), 'brass': (170, 141, 81),
    'ceramic': (181, 174, 145), 'green': (91, 112, 91),
    'blue': (77, 100, 110), 'glass': (25, 57, 49),
    'phosphor': (120, 167, 122), 'paper': (161, 154, 125),
    'rubber': (33, 35, 31), 'rust': (104, 68, 47),
}
PALETTE = MATERIALS
status = industrial.status


def dot(a, b):
    # Fixed forward fused accumulation reproduces the selected preview's
    # three-component BLAS result without CPU-dispatched reduction variants.
    # Python 3.13+ math.fma has one correctly rounded result on every host.
    value = float(a[0]) * float(b[0])
    value = math.fma(float(a[1]), float(b[1]), value)
    return math.fma(float(a[2]), float(b[2]), value)


def magnitude(value):
    return math.sqrt(dot(value, value))


class Mesh:
    def __init__(self):
        self.faces = []

    def face(self, vertices, material):
        self.faces.append({'vertices': [list(p) for p in vertices], 'material': material})

    def prism(self, outline, bottom, top, material='cast', bevel=.025):
        cx = sum(p[0] for p in outline) / len(outline)
        cy = sum(p[1] for p in outline) / len(outline)
        inner = [(x + (cx-x)*bevel, y + (cy-y)*bevel) for x,y in outline]
        for i,(x,y) in enumerate(outline):
            X,Y = outline[(i+1) % len(outline)]
            a,b = inner[i]; A,B = inner[(i+1) % len(inner)]
            shoulder = max(bottom, top - .025)
            self.face([(x,y,bottom),(X,Y,bottom),(X,Y,shoulder),(x,y,shoulder)], material)
            self.face([(x,y,shoulder),(X,Y,shoulder),(A,B,top),(a,b,top)], 'edge' if material=='cast' else material)
        self.face([(x,y,top) for x,y in inner], material)

    def box(self, x,y,X,Y,bottom,top,material='cast',corner=.025):
        r = min(corner, (X-x)/3, (Y-y)/3)
        self.prism([(x+r,y),(X-r,y),(X,y+r),(X,Y-r),(X-r,Y),(x+r,Y),(x,Y-r),(x,y+r)], bottom, top, material)

    def cylinder(self, x,y,r,bottom,top,material='cast',sides=24, ratio=1.0):
        self.prism([(x+r*math.cos(i*math.tau/sides),y+r*ratio*math.sin(i*math.tau/sides)) for i in range(sides)],bottom,top,material,.035)

    def tube(self, a,b,r,material='iron',sides=12):
        a,b = np.array(a),np.array(b)
        axis=b-a; axis=axis/magnitude(axis)
        seed=np.array([0.,0.,1.]) if abs(axis[2])<.9 else np.array([1.,0.,0.])
        u=np.cross(axis,seed); u/=magnitude(u); v=np.cross(axis,u)
        ring=[r*(u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides)) for i in range(sides)]
        for i,p in enumerate(ring):
            q=ring[(i+1)%sides]
            self.face([a+p,a+q,b+q,b+p],material)
        self.face([b+p for p in ring],material)
        self.face([a+p for p in reversed(ring)],material)

    def cable(self, points, r=.025, material='copper'):
        for a,b in zip(points,points[1:]):
            self.tube(a,b,r,material)

    def bolt(self, x,y,h):
        self.cylinder(x,y,.026,h,h+.018,'iron',6)
        self.box(x-.016,y-.004,x+.016,y+.004,h+.018,h+.021,'black',0)

    def feet(self, width=1):
        for x in (-width/2+.13,width/2-.13):
            for y in (-.31,.31):
                self.box(x-.09,y-.09,x+.09,y+.09,0,.045,'rubber')
                self.bolt(x,y,.045)

    def dial(self,x,y,r,h):
        self.cylinder(x,y,r,h,h+.045,'brass')
        self.cylinder(x,y,r*.81,h+.045,h+.05,'ceramic')
        self.cylinder(x,y,r*.66,h+.05,h+.052,'black')
        for i in range(7):
            a=math.pi*(.15+i*.12)
            self.tube((x+r*.51*math.cos(a),y-r*.51*math.sin(a),h+.054),(x+r*.62*math.cos(a),y-r*.62*math.sin(a),h+.054),.006,'ceramic',6)
        self.tube((x,y,h+.058),(x+r*.42,y-r*.39,h+.058),.009,'phosphor',6)

    def keys(self,x,y,h,cols=5,rows=2):
        self.box(x-.03,y-.03,x+cols*.095,y+rows*.085,h,h+.01,'black')
        for row in range(rows):
            for col in range(cols):
                self.box(x+col*.095,y+row*.085,x+col*.095+.066,y+row*.085+.048,h+.01,h+.028,'ceramic',.006)

    def display(self,x,y,X,Y,h,material='glass'):
        self.box(x-.035,y-.035,X+.035,Y+.035,h-.05,h,'black')
        self.box(x,y,X,Y,h,h+.006,material)
        for i,width in enumerate((.65,.85,.45)):
            self.box(x+.03,y+.04+i*.06,x+.03+(X-x-.06)*width,y+.05+i*.06,h+.006,h+.008,'phosphor',0)


def service(kind):
    m=Mesh(); width={'logic':3,'configurator':2}.get(kind,1); m.feet(width)
    if kind=='computer':
        # Folded desk, hood, keyboard apron and asymmetric cooling hump.
        m.box(-.41,-.35,.39,.35,.04,.10,'green')
        m.box(-.38,-.32,.28,.02,.10,.28,'green')
        m.display(-.31,-.26,.21,-.04,.285)
        m.box(.29,-.32,.41,.16,.10,.32,'iron')
        for y in (-.25,-.15,-.05,.05): m.box(.31,y,.40,y+.035,.32,.325,'black')
        m.keys(-.31,.15,.105,6,2)
    elif kind=='kv':
        m.box(-.39,-.35,.39,.35,.04,.09,'iron')
        m.box(.23,-.33,.37,.31,.09,.39,'green')
        for i in range(3):
            h=.10+i*.105; x=-.34+i*.025
            m.box(x,-.31,.24,.25,h,h+.085,'green')
            m.box(x+.06,.25,.15,.33,h+.012,h+.06,'ceramic')
            m.box(x+.10,.272,.11,.337,h+.025,h+.045,'black')
        for y in (-.24,-.12,0,.12,.24): m.box(.26,y,.38,y+.028,.39,.40,'iron')
    elif kind=='logic':
        m.box(-1.43,-.12,1.43,.12,.04,.09,'iron')
        m.box(-.43,-.34,.43,.26,.09,.29,'green')
        m.display(-.31,-.24,.16,.02,.295)
        for x in (-1.12,-.79,.77,1.10):
            m.box(x-.13,-.26,x+.13,.26,.06,.12,'ceramic')
            for y in (-.17,.03):
                m.box(x-.07,y,x+.07,y+.10,.12,.15,'iron')
                m.bolt(x,y+.05,.15)
        for x in (-.60,.60): m.cable([(x,-.20,.12),(x,-.35,.14),(x/2,-.35,.22)],.035,'copper')
        m.box(-.35,.25,.30,.35,.08,.12,'green')
    elif kind=='configurator':
        m.box(-.91,-.34,.85,-.23,.04,.12,'green')
        m.box(-.91,-.34,-.70,.32,.04,.19,'green')
        m.box(.62,-.32,.84,.10,.04,.14,'green')
        m.box(-.70,-.16,-.24,.29,.04,.16,'iron')
        m.dial(-.46,.045,.22,.16)
        m.box(.17,-.03,.79,.26,.04,.09,'ceramic')
        for x in (.29,.46,.63): m.bolt(x,.12,.09)
    elif kind=='factoriopedia_interface':
        # Upright catalogue terminal with stepped reference cards and side dial.
        m.box(-.39,-.34,.39,.34,.04,.10,'iron')
        m.box(-.35,-.31,-.12,.26,.10,.42,'blue')
        m.display(-.29,-.25,-.17,.14,.425)
        for i in range(3):
            h=.11+i*.075
            m.box(-.08,-.26+i*.045,.31,.22,h,h+.055,'paper')
            m.box(.24,-.23+i*.045,.34,-.12+i*.045,h+.055,h+.07,'brass')
        m.dial(.12,.22,.105,.335)
    elif kind=='production_statistics':
        # Chart recorder: brass rollers, ruled paper and a raised twin-gauge head.
        m.box(-.40,-.34,.40,.34,.04,.12,'iron')
        m.box(-.35,-.31,.35,-.05,.12,.34,'green')
        m.dial(-.17,-.18,.115,.34)
        m.dial(.17,-.18,.115,.34)
        m.box(-.27,.01,.27,.29,.12,.14,'paper')
        for y in (.05,.12,.19,.26): m.box(-.25,y,.25,y+.008,.14,.143,'ceramic',0)
        m.cable([(-.24,.24,.15),(-.12,.17,.15),(0,.20,.15),(.12,.07,.15),(.24,.04,.15)],.012,'blue')
        for y in (0,.30): m.tube((-.32,y,.16),(.32,y,.16),.035,'brass')
    elif kind=='dashboard':
        m.box(-.41,-.35,.41,.35,.04,.10,'blue')
        m.box(-.36,-.31,.36,.02,.10,.27,'blue')
        m.display(-.29,-.25,.29,-.04,.275)
        for x,material in ((-.23,'green'),(0,'brass'),(.23,'ceramic')):
            m.cylinder(x,.20,.075,.10,.14,material,12)
        m.box(-.34,.30,.34,.34,.10,.13,'iron')
    elif kind=='recipe_searcher':
        for x in (-.36,.36): m.box(x-.045,-.36,x+.045,.33,.04,.10,'iron')
        m.box(-.29,-.30,.29,.31,.04,.08,'paper')
        m.box(-.40,-.10,.40,.04,.13,.24,'green')
        m.box(-.28,-.08,.28,-.025,.24,.25,'glass')
        m.box(-.32,.24,.32,.36,.08,.13,'iron')
        m.cable([(.34,-.25,.09),(.41,-.15,.12),(.36,-.04,.19)],.025,'copper')
    return m


def render(mesh, direction, size, supersample=3):
    """Orthographic barycentric depth rasterization; no painter-order occlusion."""
    s=supersample; n=size*s
    rgba=np.zeros((n,n,4),dtype=np.uint8)
    depth=np.full((n,n),-np.inf)
    shadows=Image.new('L',(n,n)); sd=ImageDraw.Draw(shadows)
    light=np.array([-.55,-.85,1.7]); light/=magnitude(light)
    view=np.array([.75,2.,1.]); view/=magnitude(view)
    def rotate(v):
        x,y,h=v
        for _ in range(direction): x,y=-y,x
        return np.array([x,y,h])
    def project(v):
        x,y,h=v
        return np.array([(size/2+64*x-48*h)*s,(size/2+64*y-128*h)*s,dot(v,view)])
    for fi,face in enumerate(mesh.faces):
        world=[rotate(p) for p in face['vertices']]
        shadow=[((size/2+64*(v[0]+v[2]*.65))*s,(size/2+64*(v[1]+v[2]*.45))*s) for v in world]
        sd.polygon(shadow,fill=86)
        normal=np.cross(world[1]-world[0],world[2]-world[0]); norm=magnitude(normal)
        if norm<1e-9: continue
        normal/=norm
        if dot(normal,view)<0: normal=-normal
        brightness=.49+.63*max(0,dot(normal,light))
        color=np.array(MATERIALS[face['material']],dtype=float)
        spec=max(0,dot(normal,(light+view)/magnitude(light+view)))**28
        metallic=face['material'] in ('copper','brass','iron','edge')
        color=color*brightness+spec*(32 if metallic else 8)
        vertices=[project(v) for v in world]
        for j in range(1,len(vertices)-1):
            a,b,c=vertices[0],vertices[j],vertices[j+1]
            lo=np.maximum(0,np.floor(np.minimum(np.minimum(a[:2],b[:2]),c[:2])).astype(int))
            hi=np.minimum(n-1,np.ceil(np.maximum(np.maximum(a[:2],b[:2]),c[:2])).astype(int))
            if np.any(hi<lo): continue
            yy,xx=np.mgrid[lo[1]:hi[1]+1,lo[0]:hi[0]+1]; px=xx+.5; py=yy+.5
            den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
            if abs(den)<1e-10: continue
            u=((b[1]-c[1])*(px-c[0])+(c[0]-b[0])*(py-c[1]))/den
            v=((c[1]-a[1])*(px-c[0])+(a[0]-c[0])*(py-c[1]))/den
            w=1-u-v; z=u*a[2]+v*b[2]+w*c[2]
            section=depth[lo[1]:hi[1]+1,lo[0]:hi[0]+1]
            mask=(u>=-1e-8)&(v>=-1e-8)&(w>=-1e-8)&(z>=section)
            section[mask]=z[mask]
            target=rgba[lo[1]:hi[1]+1,lo[0]:hi[0]+1]
            grain=((xx//s*31+yy//s*17+fi*13)%9-4)*.7
            shaded=np.clip(color[None,None,:]+grain[:,:,None],0,255).astype(np.uint8)
            target[mask,:3]=shaded[mask]; target[mask,3]=255
    image=Image.fromarray(rgba).resize((size,size),Image.Resampling.LANCZOS)
    shadow=Image.new('RGBA',(n,n),(0,0,0,0)); shadow.putalpha(shadows.filter(ImageFilter.GaussianBlur(s*.65)))
    return image,shadow.resize((size,size),Image.Resampling.LANCZOS)


def monitor_body(direction, size, roles):
    original = Image.frombytes('RGBA', (size, size), bytes(c for p in foundry.body('monitor', direction, size, roles)[2] for c in p))
    image = original.copy(); d = ImageDraw.Draw(image); c = size // 2
    d.rectangle((c-34,c-34,c+33,c+33),outline='#526453',width=2)
    for x in (-34,30):
        for y in (-34,30):
            d.line((c+x,c+y+3,c+x,c+y,c+x+3,c+y),fill='#a1ae91',width=2)
    image.putalpha(original.getchannel('A'))
    image.paste(original.crop((c-30,c-30,c+30,c+30)),(c-30,c-30))
    return image


def body(kind, direction, size, roles):
    image = monitor_body(direction, size, roles) if kind == 'monitor' else render(service(kind), direction, size)[0]
    contact = industrial.Drawing(size, direction)
    industrial.contacts(contact, kind, roles)
    image.paste(contact.image, (0, 0), contact.image)
    return size, size, list(image.getdata())


def shadow(kind, direction, size, width):
    if kind == 'monitor':
        return foundry.shadow(kind, direction, size, width)
    image = render(service(kind), direction, size)[1]
    return size, size, list(image.getdata())
