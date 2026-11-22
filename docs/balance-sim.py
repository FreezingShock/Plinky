# Plinky zone 1 starting-balance sim (text only). Assumptions in balance.md.
DT=0.1; PRESS_RATE=0.5  # balance.md section 1
BUTTONS={
 'M1':dict(cost_stat='cash',cost=10,reward_stat='mult',reward=1),
 'M2':dict(cost_stat='cash',cost=100,reward_stat='mult',reward=8),
 'M3':dict(cost_stat='cash',cost=1000,reward_stat='mult',reward=64),
 'R1':dict(cost_stat='mult',cost=3000,reward_stat='reb',reward=1),
 'R2':dict(cost_stat='mult',cost=30000,reward_stat='reb',reward=8),
}
GATE_REB=9
s=dict(cash=0.0,mult=0.0,reb=0.0)
t=0.0; first={}; next_press=0.0
while s['reb']<GATE_REB and t<6*3600:
    cash_ps=0.25*(1+s['mult'])
    s['cash']+=cash_ps*DT
    t+=DT
    if t>=next_press:
        next_press+=1/PRESS_RATE
        # furthest affordable: check R2, R1 before M3..M1 (rebirth row is further right)
        for name in ['R2','R1','M3','M2','M1']:
            b=BUTTONS[name]
            if s[b['cost_stat']]>=b['cost']:
                s[b['cost_stat']]-=b['cost']
                gain=b['reward']*((1+s['reb']) if b['reward_stat']=='mult' else 1)
                s[b['reward_stat']]+=gain
                first.setdefault(name,t)
                break
for k,v in first.items(): print(f"{k} first bought at {v/60:.1f} min")
print(f"gate (rebirths>={GATE_REB}) at {t/60:.1f} min, state={({k:round(v,1) for k,v in s.items()})}")
