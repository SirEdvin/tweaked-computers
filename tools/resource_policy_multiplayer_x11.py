import ctypes as C
# Host-local helper reused from the verified speaker-client evidence harness.
import ctypes.util
import os
from pathlib import Path
import json

lib=C.CDLL(ctypes.util.find_library('X11'))
lib.XOpenDisplay.argtypes=[C.c_char_p]; lib.XOpenDisplay.restype=C.c_void_p
lib.XDefaultRootWindow.argtypes=[C.c_void_p]; lib.XDefaultRootWindow.restype=C.c_ulong
lib.XQueryTree.argtypes=[C.c_void_p,C.c_ulong,C.POINTER(C.c_ulong),C.POINTER(C.c_ulong),C.POINTER(C.POINTER(C.c_ulong)),C.POINTER(C.c_uint)]
lib.XFetchName.argtypes=[C.c_void_p,C.c_ulong,C.POINTER(C.c_char_p)]
lib.XFree.argtypes=[C.c_void_p]
lib.XFlush.argtypes=[C.c_void_p]
lib.XInternAtom.argtypes=[C.c_void_p,C.c_char_p,C.c_int]; lib.XInternAtom.restype=C.c_ulong
lib.XSendEvent.argtypes=[C.c_void_p,C.c_ulong,C.c_int,C.c_long,C.c_void_p]
lib.XSetInputFocus.argtypes=[C.c_void_p,C.c_ulong,C.c_int,C.c_ulong]
lib.XKeysymToKeycode.argtypes=[C.c_void_p,C.c_ulong]; lib.XKeysymToKeycode.restype=C.c_ubyte
lib.XStringToKeysym.argtypes=[C.c_char_p]; lib.XStringToKeysym.restype=C.c_ulong
class Data(C.Union):
    _fields_=[('b',C.c_char*20),('s',C.c_short*10),('l',C.c_long*5)]
class ClientMessage(C.Structure):
    _fields_=[('type',C.c_int),('serial',C.c_ulong),('send_event',C.c_int),('display',C.c_void_p),('window',C.c_ulong),('message_type',C.c_ulong),('format',C.c_int),('data',Data)]
class Event(C.Union):
    _fields_=[('client',ClientMessage),('pad',C.c_long*24)]
def connect():
    d=lib.XOpenDisplay(None)
    if not d: raise RuntimeError('Cannot open this isolated DISPLAY with its XAUTHORITY')
    return d
def windows(d):
    output=[]
    def walk(w,depth):
        name=C.c_char_p()
        if lib.XFetchName(d,w,C.byref(name)) and name.value:
            output.append((w,name.value.decode(errors='replace'))); lib.XFree(name)
        if depth>=3: return
        root=C.c_ulong(); parent=C.c_ulong(); kids=C.POINTER(C.c_ulong)(); count=C.c_uint()
        if lib.XQueryTree(d,w,C.byref(root),C.byref(parent),C.byref(kids),C.byref(count)):
            ids=[kids[i] for i in range(count.value)]
            if kids: lib.XFree(kids)
            for child in ids: walk(child,depth+1)
    walk(lib.XDefaultRootWindow(d),0)
    return output
def close_factorio():
    d=connect(); targets=[(w,n) for w,n in windows(d) if n.startswith('Factorio')]
    for w,name in targets:
        event=Event(); c=event.client; c.type=33; c.send_event=1; c.display=d; c.window=w
        c.message_type=lib.XInternAtom(d,b'WM_PROTOCOLS',0); c.format=32
        c.data.l[0]=lib.XInternAtom(d,b'WM_DELETE_WINDOW',0); c.data.l[1]=0
        lib.XSendEvent(d,w,0,0,C.byref(event))
    lib.XFlush(d); return targets
if __name__=='__main__':
    print(json.dumps(close_factorio()))
