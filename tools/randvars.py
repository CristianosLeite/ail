"""Check variable allocation with random programs.

Usage: randvars.py <compiler> <count> <seed> [top]

Generates programs with up to 40 variables in use at once, nested loops and
skipped blocks, in a function or (with "top") at top level, computes the
exit status each must give, and runs them. The expected status comes from
running the same program in Python, not from a compiler. A program that
fails is kept as build/randvars/seed<seed>[-top]-<n>.ai. `make test` runs
it with a fixed seed in both forms.
"""
import os
import random
import subprocess
import sys
import tempfile
M=(1<<64)-1
def gen(rng, top):
    names=['v%d'%i for i in range(rng.randint(3,40))]
    lines=[]; env={}; lab=[0]
    ops={'add':lambda a,b:(a+b)&M,'sub':lambda a,b:(a-b)&M,'mul':lambda a,b:(a*b)&M,'xor':lambda a,b:a^b,'and':lambda a,b:a&b,'or':lambda a,b:a|b}
    prog=[]   # structured: ('op',name,a,b,dst) ('loop',n,cnt,body) ('if',cond,body)
    def val(defined):
        if defined and rng.random()<0.8: return rng.choice(sorted(defined))
        return str(rng.randint(0,9))
    def block(defined, depth, newok, n):
        out=[]
        for _ in range(n):
            r=rng.random()
            if r<0.75 or depth>=3:
                dst=rng.choice(names) if newok else (rng.choice(sorted(defined)) if defined else None)
                if dst is None: continue
                out.append(('op',rng.choice(list(ops)),val(defined),val(defined),dst)); defined.add(dst)
            elif r<0.9:
                cnt='c%d'%lab[0]; lab[0]+=1
                body=block(defined,depth+1,newok,rng.randint(1,6))
                out.append(('loop',rng.randint(1,3),cnt,body))
            else:
                if not defined: continue
                cond=rng.choice(sorted(defined))
                body=block(set(defined),depth+1,False,rng.randint(1,4))
                out.append(('if',cond,body))
        return out
    params=['p%d'%i for i in range(rng.randint(0,6))] if not top else []
    defined=set(params)
    body=block(defined,0,True,rng.randint(5,40))
    def emit(b):
        for st in b:
            if st[0]=='op': lines.append('%s %s %s as %s'%(st[1],st[2],st[3],st[4]))
            elif st[0]=='loop':
                l='l%d'%lab[0]; lab[0]+=1
                lines.append('set %d as %s'%(st[1],st[2])); lines.append('label '+l); emit(st[3])
                lines.append('sub %s 1 as %s'%(st[2],st[2])); lines.append('jnz %s %s'%(st[2],l))
            else:
                l='l%d'%lab[0]; lab[0]+=1
                lines.append('jz %s %s'%(st[1],l)); emit(st[2]); lines.append('label '+l)
    def run(b,env):
        g=lambda x: env[x] if x in env else int(x)
        for st in b:
            if st[0]=='op': env[st[4]]=ops[st[1]](g(st[2]),g(st[3]))
            elif st[0]=='loop':
                for _ in range(st[1]): run(st[3],env)
            elif env[st[1]]!=0: run(st[2],env)
    args=[rng.randint(0,1000) for _ in params]
    env=dict(zip(params,args)); run(body,env)
    h=0
    final=sorted(defined)
    if not top: lines.append('fn f '+' '.join(params)); 
    emit(body)
    lines.append('set 0 as h')
    for v in final:
        lines.append('add h %s as h'%v); h=(h+env[v])&M
    lines.append('mod h 251 as h')
    if top: lines.append('sys 60 h')
    else:
        lines.append('ret h'); lines.append('end')
        lines.append('call f %s as r'%' '.join(map(str,args))); lines.append('sys 60 r')
    # too many variables for a scope: skip
    nv=len(defined)+lab[0]+2
    return '\n'.join(lines)+'\n', h%251, nv
tmp=tempfile.mkdtemp(); exe=os.path.join(tmp,'prog')
cc=sys.argv[1]; n=int(sys.argv[2]); seed=int(sys.argv[3]); rng=random.Random(seed); top=len(sys.argv)>4
bad=0; done=0
what='randvars %d programs, seed %d%s'%(n,seed,', top level' if top else '')
def keep(i,src):
    os.makedirs('build/randvars',exist_ok=True)
    path='build/randvars/seed%d%s-%d.ai'%(seed,'-top' if top else '',i)
    open(path,'w').write(src); return path
for i in range(n):
    src,want,nv=gen(rng,top)
    if nv>60: continue
    done+=1
    p=subprocess.run([cc],input=src.encode(),capture_output=True)
    if p.returncode!=0: print('FAIL randvars %d: does not compile (kept as %s)'%(i,keep(i,src))); bad+=1; continue
    open(exe,'wb').write(p.stdout); os.chmod(exe,0o755)
    try: got=subprocess.run([exe],timeout=10).returncode
    except subprocess.TimeoutExpired: got='deadline'
    if got!=want: print('FAIL randvars %d: status %s, expected %d (kept as %s)'%(i,got,want,keep(i,src))); bad+=1
if not bad: print('ok   %s (%d run)'%(what,done))
if os.path.exists(exe): os.remove(exe)
os.rmdir(tmp)
sys.exit(1 if bad else 0)
