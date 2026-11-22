# Plinky zone 1 balance sim (text only), v1. Mirrors core/sim.gd rules; tools/sim.gd is the in-engine check.
# Usage: python3 docs/balance-sim.py   (prints both play styles for old and new tuning)
DT=0.1
def run(strategy, base=0.25, start=0.0, r1=3000, r2=30000, press=1.0, prestige=0.0, target=9, m=(10,100,1000)):
    """greedy = always buy the furthest affordable button (r2 never happens at 30000).
    saver  = skip r1, wait for mult to reach r2 (+8 reb), then finish with r1."""
    s=dict(cash=start,mult=0.0,reb=0.0); t=0.0; nxt=0.0; pm=1+prestige**0.8; first={}; buys=0
    while s['reb']<target and t<7200:
        s['cash']+=base*(1+s['mult'])*pm*DT; t+=DT
        if t<nxt: continue
        nxt+=1/press
        if s['mult']>=r2: s['mult']-=r2; s['reb']+=8; first.setdefault('r2',t); buys+=1; continue
        if s['mult']>=r1 and (strategy=='greedy' or s['reb']>=8):
            s['mult']-=r1; s['reb']+=1; first.setdefault('r1',t); buys+=1; continue
        for i in (2,1,0):
            if s['cash']>=m[i]:
                s['cash']-=m[i]; s['mult']+=(1,8,64)[i]*(1+s['reb']); first.setdefault('m%d'%(i+1),t); buys+=1; break
    return t,first,buys
def show(label,**kw):
    for st in ('greedy','saver'):
        t,f,b=run(st,**kw)
        print(f"{label:>8} {st:>6}: gate {t/60:4.1f} min, buys {b:4d}, first buys "+", ".join(f"{k} {v/60:.1f}m" for k,v in sorted(f.items(),key=lambda x:x[1])))
show('v0')
show('v1',start=10.0,r2=12000)
