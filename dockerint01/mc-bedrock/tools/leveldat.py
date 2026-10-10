"""Minimal Bedrock level.dat (little-endian NBT) reader/editor.
usage: leveldat.py FILE [key=byte | key:i=int | key:s=string ...]   (root tags only)"""
import struct, sys
def rs(b,o):
    n=struct.unpack_from('<H',b,o)[0]; return b[o+2:o+2+n].decode('utf-8','replace'),o+2+n
def rp(b,o,t):
    if t==1: return struct.unpack_from('<b',b,o)[0],o+1
    if t==2: return struct.unpack_from('<h',b,o)[0],o+2
    if t==3: return struct.unpack_from('<i',b,o)[0],o+4
    if t==4: return struct.unpack_from('<q',b,o)[0],o+8
    if t==5: return struct.unpack_from('<f',b,o)[0],o+4
    if t==6: return struct.unpack_from('<d',b,o)[0],o+8
    if t==7: n=struct.unpack_from('<i',b,o)[0]; return b[o+4:o+4+n],o+4+n
    if t==8: return rs(b,o)
    if t==9:
        et=b[o]; n=struct.unpack_from('<i',b,o+1)[0]; o+=5; l=[]
        for _ in range(n): v,o=rp(b,o,et); l.append(v)
        return (et,l),o
    if t==10:
        d={}
        while True:
            tt=b[o]; o+=1
            if tt==0: return d,o
            k,o=rs(b,o); v,o=rp(b,o,tt); d[k]=(tt,v)
    if t==11: n=struct.unpack_from('<i',b,o)[0]; return list(struct.unpack_from('<%di'%n,b,o+4)),o+4+4*n
    if t==12: n=struct.unpack_from('<i',b,o)[0]; return list(struct.unpack_from('<%dq'%n,b,o+4)),o+4+8*n
    raise ValueError(t)
def ws(s): e=s.encode(); return struct.pack('<H',len(e))+e
def wp(t,v):
    if t==1: return struct.pack('<b',v)
    if t==2: return struct.pack('<h',v)
    if t==3: return struct.pack('<i',v)
    if t==4: return struct.pack('<q',v)
    if t==5: return struct.pack('<f',v)
    if t==6: return struct.pack('<d',v)
    if t==7: return struct.pack('<i',len(v))+v
    if t==8: return ws(v)
    if t==9: et,l=v; return bytes([et])+struct.pack('<i',len(l))+b''.join(wp(et,x) for x in l)
    if t==10: return b''.join(bytes([tt])+ws(k)+wp(tt,vv) for k,(tt,vv) in v.items())+b'\0'
    if t==11: return struct.pack('<i',len(v))+struct.pack('<%di'%len(v),*v)
    if t==12: return struct.pack('<i',len(v))+struct.pack('<%dq'%len(v),*v)
f=sys.argv[1]; raw=open(f,'rb').read()
ver=struct.unpack_from('<i',raw,0)[0]; body=raw[8:]
assert body[0]==10
name,o=rs(body,1); root,_=rp(body,o,10)
edits=[a.split('=') for a in sys.argv[2:]]
if not edits:
    for k,(t,v) in sorted(root.items()):
        if t!=10: print(k,'=',v)
    sys.exit()
for k,v in edits:
    # key=v -> byte; key:i=v -> int; key:s=v -> string
    k,_,t=k.partition(':'); tag={'':1,'b':1,'i':3,'s':8}[t]
    old=root.get(k); assert old is None or old[0]==tag,(k,old)
    root[k]=(tag, v if tag==8 else int(v)); print(k,':',old and old[1],'->',v)
nb=bytes([10])+ws(name)+wp(10,root)
open(f,'wb').write(struct.pack('<ii',ver,len(nb))+nb)
