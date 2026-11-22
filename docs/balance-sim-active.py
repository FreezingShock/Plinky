# Plinky active-play and rebirth-push sim (text only), v1.1. Mirrors the numbers in content/config/game.tres.
# Usage: python3 docs/balance-sim-active.py
import random
def run(mom=0.0,streak=False,critter=False,base=0.25,start=10.0,r1=3000,r2=12000,press=1.0,seed=1):
    random.seed(seed)
    DT=0.1;s=dict(cash=start,mult=0.0,reb=0.0);t=0.0;nxt=0.0
    seq=0;last=0;cool=-99;crit_next=random.uniform(75,150)
    while s['reb']<9 and t<7200:
        inc=base*(1+s['mult'])*(1+mom)
        s['cash']+=inc*DT;t+=DT
        if critter and t>=crit_next:
            s['cash']+=30*inc; crit_next=t+random.uniform(75,150)
        if t<nxt: continue
        nxt+=1/press
        if s['mult']>=r2: s['mult']-=r2;s['reb']+=8;continue
        if s['mult']>=r1: s['mult']-=r1;s['reb']+=1;continue
        for i,c in ((2,1000),(1,100),(0,10)):
            if s['cash']>=c:
                s['cash']-=c;s['mult']+=(1,8,64)[i]*(1+s['reb'])
                if streak:
                    if i==0: seq=1;last=t
                    elif i==seq and t-last<=10:
                        seq+=1;last=t
                        if seq==3 and t-cool>=20: s['cash']+=6*inc;cool=t;seq=0
                    else: seq=0
                break
    return round(t/60,1)
for name,kw in (('idle',{}),('momentum +20%',dict(mom=0.2)),('streak',dict(streak=True)),('critter',dict(critter=True)),('all',dict(mom=0.2,streak=True,critter=True))):
    print(name,[run(seed=s,**kw) for s in (1,2,3)])

print()
print('Prestige after 60 min by rebirth target, push exponent k (0 = old rule):')
def prun(prestige,target,base=0.25,start=10.0,r1=3000,r2=12000,press=1.0):
    DT=0.1;s=dict(cash=start,mult=0.0,reb=0.0);t=0.0;nxt=0.0;pm=1+prestige**0.8
    while s['reb']<target and t<7200:
        s['cash']+=base*(1+s['mult'])*pm*DT;t+=DT
        if t<nxt: continue
        nxt+=1/press
        if s['mult']>=r2: s['mult']-=r2;s['reb']+=8;continue
        if s['mult']>=r1: s['mult']-=r1;s['reb']+=1;continue
        for i,c in ((2,1000),(1,100),(0,10)):
            if s['cash']>=c: s['cash']-=c;s['mult']+=(1,8,64)[i]*(1+s['reb']);break
    return t,s['reb']
def gain(reb,k,th=9):
    return reb*max(1.0,reb/th)**k
def best(k,total_min=60):
    # dp-ish greedy: simulate fixed target per run, report prestige after total_min
    res={}
    for tg in (9,12,16,24,36,54):
        t_used=0;p=0;runs=0
        # first run must reach 9 w/o prestige
        while True:
            t,r=prun(p,tg if (p>0 or tg>=9) else 9)
            if t_used+t/60>total_min: break
            t_used+=t/60;p+=gain(r,k);runs+=1
        res[tg]=(round(p),runs)
    return res
for k in (0,0.5): print('k',k,best(k))
