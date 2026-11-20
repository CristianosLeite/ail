"""Rewrite an AIL source to use compare-and-jump statements and if blocks.

A comparison followed by jz/jnz on its result becomes one jump when the
result is not read afterwards on any path. A conditional jump forward to a
label that nothing else jumps to becomes a block, where blocks nest.
"""
import re, sys
src=open(sys.argv[1]).read().split('\n')
CMP={'eq','ne','lt','le','gt','ge','slt','sle','sgt','sge'}
INV={'eq':'ne','ne':'eq','lt':'ge','ge':'lt','le':'gt','gt':'le','slt':'sge','sge':'slt','sle':'sgt','sgt':'sle'}
JCC={'j'+c for c in CMP}
gvars=set()
for l in src:
    if l.startswith('var '): gvars|=set(l.split('#')[0].split()[1:])
def toks(l):
    if l is None: return []
    l=re.sub(r'"(\\.|[^"\\])*"','"s"',l.split('#')[0] if '"' not in l else re.sub(r'"(\\.|[^"\\])*"','"s"',l))
    if '#' in l: l=l.split('#')[0]
    return l.split()
def info(l):
    """(reads, writes, kind, target) of a line"""
    t=toks(l)
    if not t: return set(),set(),'none',None
    k=t[0]
    if k in ('label',): return set(),set(),'label',t[1]
    if k in ('fn','end','buf','data','var','const','use','local','else'): return set(),set(),k,None
    ops=t[1:]; w=set()
    if 'as' in ops:
        i=ops.index('as'); w=set(ops[i+1:]); ops=ops[:i]
    tgt=None
    if k=='jmp': tgt=ops[-1]; ops=[]
    elif k in ('jz','jnz') or k in JCC: tgt=ops[-1]; ops=ops[:-1]
    elif k in ('call','tail','ref'): ops=ops[1:]
    r={o for o in ops if re.match(r'^[a-z][a-z0-9_]*$',o)}
    kind='jmp' if k=='jmp' else 'jcc' if tgt else 'ret' if k in('ret','tail') else 'stmt'
    return r,w,kind,tgt
# scopes: list of lists of line indexes
scopes=[]; top=[]; cur=None
for i,l in enumerate(src):
    t=toks(l)
    if t and t[0]=='fn': cur=[i]; continue
    if cur is not None:
        cur.append(i)
        if t and t[0]=='end': scopes.append(cur); cur=None
    else: top.append(i)
scopes.append(top)
def dead_after(sc, starts, v):
    pos={}
    for n,i in enumerate(sc):
        r,w,k,t=info(src[i])
        if k=='label': pos[t]=n
    seen=set(); stack=list(starts)
    while stack:
        n=stack.pop()
        while True:
            if n>=len(sc) or n in seen: break
            seen.add(n)
            r,w,k,t=info(src[sc[n]])
            if v in r: return False
            if v in w: break
            if k=='ret' or k=='end': break
            if k=='jmp':
                if t not in pos: return False
                n=pos[t]; continue
            if k=='jcc':
                if t not in pos: return False
                stack.append(pos[t])
            n+=1
    return True
fused=0
for sc in scopes:
    pos={}
    for n,i in enumerate(sc):
        r,w,k,t=info(src[i])
        if k=='label': pos[t]=n
    n=0
    while n<len(sc)-1:
        a=src[sc[n]]; b=src[sc[n+1]]
        if a is None or b is None: n+=1; continue
        ma=re.match(r'^(\w+) (\S+) (\S+) as (\w+)$',a); mb=re.match(r'^(jz|jnz) (\w+) (\w+)$',b)
        if ma and mb and ma.group(1) in CMP and mb.group(2)==ma.group(4) and ma.group(4) not in gvars and mb.group(3) in pos:
            v=ma.group(4)
            if v not in (ma.group(2),ma.group(3)) and dead_after(sc,[n+2,pos[mb.group(3)]],v):
                op=ma.group(1) if mb.group(1)=='jnz' else INV[ma.group(1)]
                src[sc[n]]='j%s %s %s %s'%(op,ma.group(2),ma.group(3),mb.group(3)); src[sc[n+1]]=None
                fused+=1
        n+=1
src2=[]; 
# rebuild scopes after deletions
keep=[l for l in src if l is not None]
src=keep
scopes=[]; top=[]; cur=None
for i,l in enumerate(src):
    t=toks(l)
    if t and t[0]=='fn': cur=[i]; continue
    if cur is not None:
        cur.append(i)
        if t and t[0]=='end': scopes.append(cur); cur=None
    else: top.append(i)
scopes.append(top)
MAXLEN=16
KEEP=set('next tokend arg num str ident capture bufdef vardef constdef localdef usedef uend datadef labdef jtarget fndef fnend blkend elsedef atname fin'.split())
BLK={'jz':'if','jnz':'ifz'}
for c in CMP: BLK['j'+c]='if'+INV[c]
blocks=0
for sc in scopes:
    pos={}; refs={}
    for n,i in enumerate(sc):
        r,w,k,t=info(src[i])
        if k=='label': pos[t]=n
        if k in('jmp','jcc'): refs.setdefault(t,[]).append(n)
    cand=[]
    for t,rs in refs.items():
        if len(rs)==1 and t in pos and rs[0]<pos[t]:
            n=rs[0]; tk=toks(src[sc[n]])
            if tk[0] in BLK and '#' not in src[sc[n]] and src[sc[pos[t]]]=='label '+t and pos[t]-n<=MAXLEN and t not in KEEP and not any(src[sc[x]].startswith('#') or src[sc[x]]=='' for x in range(n,pos[t]+1)): cand.append((n,pos[t]))
    cand.sort(key=lambda x:x[1]-x[0]); acc=[]
    for a,b in cand:
        ok=True
        for c,d in acc:
            if not (b<c or d<a or (a<c and d<b) or (c<a and b<d)): ok=False; break
        if ok: acc.append((a,b))
    for a,b in acc:
        tk=toks(src[sc[a]])
        src[sc[a]]=' '.join([BLK[tk[0]]]+tk[1:-1]); src[sc[b]]='end'; blocks+=1
open(sys.argv[2],'w').write('\n'.join(src))
print('fused',fused,'blocks',blocks,file=sys.stderr)
