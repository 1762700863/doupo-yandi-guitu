import numpy as np, wave, os, subprocess
SR=32000
rng=np.random.default_rng(7)
def save(name,x,folder='sfx',ogg=False):
    x=np.asarray(x,float); m=np.max(np.abs(x))+1e-9; x=x/m*0.9
    p=f'/home/user/game/assets/{folder}/{name}.wav'
    with wave.open(p,'w') as w:
        w.setnchannels(1 if x.ndim==1 else 2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x*32767).astype(np.int16).tobytes())
    if ogg:
        subprocess.run(['oggenc','-Q','-q','5',p,'-o',p[:-4]+'.ogg']); os.remove(p)
def t(d): return np.arange(int(SR*d))/SR
def env(n,a=0.005,d=0.2):
    tt=np.arange(n)/SR; e=np.minimum(1,tt/a)*np.exp(-tt/d); return e
def noise(d): return rng.standard_normal(int(SR*d))
def lp(x,k):
    # simple one-pole lowpass, k in 0..1
    y=np.zeros_like(x); s=0
    for i in range(len(x)): s+=k*(x[i]-s); y[i]=s
    return y
def lpf(x,cut):
    from scipy.signal import butter,lfilter
    b,a=butter(2,cut/(SR/2)); return lfilter(b,a,x)
def hpf(x,cut):
    from scipy.signal import butter,lfilter
    b,a=butter(2,cut/(SR/2),'high'); return lfilter(b,a,x)
def bpf(x,lo,hi):
    from scipy.signal import butter,lfilter
    if np.ndim(lo)==0 and np.ndim(hi)==0:
        b,a=butter(2,[lo/(SR/2),hi/(SR/2)],'band'); return lfilter(b,a,x)
    lo=np.broadcast_to(lo,x.shape); hi=np.broadcast_to(hi,x.shape)
    out=np.zeros_like(x); B=512
    for i in range(0,len(x),B):
        l=float(np.mean(lo[i:i+B])); h=float(np.mean(hi[i:i+B])); h=min(h,SR/2-100); l=min(l,h-50)
        b,a=butter(2,[l/(SR/2),h/(SR/2)],'band'); out[i:i+B]=lfilter(b,a,x[max(0,i-2048):i+B])[-len(x[i:i+B]):]
    return out
# ---- SFX ----
d=0.18; n=noise(d); save('hit', lpf(n,2500)*env(len(n),0.001,0.04)+np.sin(2*np.pi*110*t(d)*np.exp(-t(d)*8))*env(len(n),0.001,0.06))
d=0.35; save('heavy', lpf(noise(d),900)*env(int(SR*d),0.001,0.09)*1.2+np.sin(2*np.pi*70*t(d)*np.exp(-t(d)*5))*env(int(SR*d),0.001,0.15)*1.5)
d=0.25; tt=t(d); save('swing', bpf(noise(d),600+2500*tt/d,1200+4000*tt/d)*np.sin(np.pi*tt/d)**2)
d=0.3; tt=t(d); save('whoosh_fire', bpf(noise(d),300,3000)*np.sin(np.pi*tt/d)*(1+0.5*np.sin(2*np.pi*30*tt)))
d=0.9; tt=t(d); x=lpf(noise(d),1200)*env(len(tt),0.003,0.35)+np.sin(2*np.pi*50*tt*np.exp(-tt*2))*env(len(tt),0.002,0.4)*1.3; save('explode',x)
d=1.8; tt=t(d); x=lpf(noise(d),700)*env(len(tt),0.01,0.8)+np.sin(2*np.pi*38*tt)*env(len(tt),0.01,0.9)*1.4+bpf(noise(d),2000,6000)*env(len(tt),0.001,0.1)*0.6; save('big_explode',x)
d=0.5; tt=t(d); x=hpf(noise(d),2500)*env(len(tt),0.001,0.05)
cr=np.zeros_like(tt)
for k in range(6): i=int(SR*rng.uniform(0,0.3)); cr[i:i+400]+=rng.standard_normal(400)*np.exp(-np.arange(400)/60)
save('thunder_small',x+cr*1.5)
d=2.0; tt=t(d); x=lpf(noise(d),400)*env(len(tt),0.02,0.9)*1.6+hpf(noise(d),1500)*env(len(tt),0.001,0.08); save('thunder',x)
d=0.2; tt=t(d); save('dash', bpf(noise(d),800,5000)*np.sin(np.pi*tt/d)**0.5*np.exp(-tt*6))
d=0.25; tt=t(d); save('pickup', (np.sin(2*np.pi*880*tt)+np.sin(2*np.pi*1320*tt)*(tt>0.07))*env(len(tt),0.002,0.08))
d=0.08; tt=t(d); save('click', np.sin(2*np.pi*1200*tt)*env(len(tt),0.001,0.015)+0.3*noise(d)*env(len(tt),0.001,0.005))
d=0.12; tt=t(d); save('hover', np.sin(2*np.pi*700*tt)*env(len(tt),0.001,0.03)*0.5)
# level up / breakthrough : rising pentatonic bells
def bell(f,d,dec=0.6):
    tt=t(d); return (np.sin(2*np.pi*f*tt)+0.5*np.sin(2*np.pi*f*2.76*tt)*np.exp(-tt*4)+0.25*np.sin(2*np.pi*f*5.4*tt)*np.exp(-tt*8))*env(len(tt),0.002,dec)
x=np.zeros(int(SR*1.4))
for i,f in enumerate([523,587,659,784,880,1046]): s=bell(f,1.0,0.4); o=int(i*0.08*SR); x[o:o+len(s)]+=s
save('levelup',x)
d=3.0; tt=t(d); x=np.zeros(len(tt))
for i,f in enumerate([262,330,392,523,659,784,1046,1318]): s=bell(f,2.0,0.9); o=int(i*0.1*SR); x[o:o+len(s)]+=s*0.6
x+=lpf(noise(d),300)*np.minimum(1,tt/1.2)*np.exp(-np.maximum(0,tt-1.2)*2)*2
save('breakthrough',x)
d=0.6; tt=t(d); save('coin', sum(bell(f,d,0.15) for f in [1568,2093])*1)
d=0.5; tt=t(d); save('hurt', lpf(noise(d),1500)*env(len(tt),0.001,0.07)+np.sin(2*np.pi*200*tt*np.exp(-tt*4))*env(len(tt),0.001,0.1))
d=1.5; tt=t(d); save('death', np.sin(2*np.pi*(220*np.exp(-tt*0.8))*tt)*env(len(tt),0.01,0.7)+lpf(noise(d),500)*env(len(tt),0.01,0.4))
d=0.7; tt=t(d); save('poison', bpf(noise(d),300,1200)*env(len(tt),0.05,0.3)*(1+np.sin(2*np.pi*12*tt)))
d=0.5; tt=t(d); save('wind', bpf(noise(d),500+1500*np.sin(np.pi*tt/d),3000)*np.sin(np.pi*tt/d))
d=0.4; tt=t(d); save('shoot', bpf(noise(d),1000,6000)*env(len(tt),0.002,0.07)+np.sin(2*np.pi*(900*np.exp(-tt*10))*tt)*env(len(tt),0.001,0.08)*0.5)
d=1.2; tt=t(d); save('charge', bpf(noise(d),200+2000*(tt/d)**2,400+5000*(tt/d)**2)*(tt/d)*2)
d=2.5; tt=t(d); x=np.zeros(len(tt))
for f in [196,247,294,392]: x+=bell(f,d,1.2)
save('fire_get',x+lpf(noise(d),900)*env(len(tt),0.3,0.8))
d=0.6; tt=t(d); save('door', lpf(noise(d),300)*env(len(tt),0.01,0.2)+np.sin(2*np.pi*80*tt)*env(len(tt),0.01,0.2))
d=0.4; tt=t(d); save('ice', hpf(noise(d),3000)*env(len(tt),0.001,0.1)+sum(np.sin(2*np.pi*f*tt) for f in [2400,3100,3900])*env(len(tt),0.001,0.12)*0.3)
d=1.0; tt=t(d); save('pill', sum(bell(f,d,0.3) for f in [784,988])+0.3*lpf(noise(d),2000)*env(len(tt),0.001,0.05))
d=0.6; tt=t(d); save('fail', np.sin(2*np.pi*(300-150*tt/d)*tt)*env(len(tt),0.01,0.3)+0.5*np.sin(2*np.pi*(290-150*tt/d)*tt)*env(len(tt),0.01,0.3))
d=0.3; tt=t(d); save('bosswarn', np.sign(np.sin(2*np.pi*140*tt))*env(len(tt),0.005,0.15)*0.5)
# ---- MUSIC ----
def ks(f,d,damp=0.996,bright=0.5):
    N=int(SR/f); buf=rng.uniform(-1,1,N); buf=lp(buf,bright) if False else buf
    M=int(SR*d); reps=M//N+2
    out=np.zeros(reps*N); cur=buf.copy()
    for r_ in range(reps):
        out[r_*N:(r_+1)*N]=cur
        cur=damp*0.5*(cur+np.roll(cur,-1))
    return out[:M]
cache={}
def pluck(f,d=1.6,damp=0.996):
    k=(round(f,1),d,damp)
    if k not in cache: cache[k]=ks(f,d,damp)*env(int(SR*d),0.001,d*0.5)
    return cache[k]
def drum(kind):
    if kind=='taiko':
        d=0.6; tt=t(d); return np.sin(2*np.pi*(90*np.exp(-tt*5)+45)*tt)*env(len(tt),0.001,0.18)*1.4+lpf(noise(d),600)*env(len(tt),0.001,0.03)
    if kind=='small':
        d=0.2; tt=t(d); return bpf(noise(d),800,4000)*env(len(tt),0.001,0.04)*0.5+np.sin(2*np.pi*300*tt)*env(len(tt),0.001,0.03)*0.4
    if kind=='gong':
        d=3; tt=t(d); return sum(np.sin(2*np.pi*f*tt+3*np.sin(2*np.pi*f*0.5*tt)*np.exp(-tt)) for f in [110,163,231])*env(len(tt),0.01,1.5)*0.4
def pad(freqs,d):
    tt=t(d); x=sum(np.sin(2*np.pi*f*tt+0.3*np.sin(2*np.pi*5*tt))+0.3*np.sin(2*np.pi*f*2.001*tt) for f in freqs)
    return x*np.minimum(1,np.minimum(tt/0.5,(d-tt)/0.5))
def song(name,root,bpm,bars,scale_mode,intensity,seed):
    r=np.random.default_rng(seed)
    beat=60/bpm; L=int(SR*beat*4*bars)+SR*3
    mix=np.zeros(L); 
    pent=[0,2,4,7,9] if scale_mode=='gong' else [0,3,5,7,10]
    notes=[root*2**((o*12+p)/12) for o in range(0,3) for p in pent]
    chords=[[0,2,4],[3,5,7],[1,3,5],[2,4,6]]
    # melody motif generated then repeated with variation
    motif=[r.integers(3,10) for _ in range(8)]
    for bar in range(bars):
        bt=int(SR*beat*4*bar)
        ch=chords[(bar//2)%4]
        base=notes[ch[0]]/2
        p=pad([base,notes[ch[1]]/2,notes[ch[2]]/2],beat*4)*0.07*(0.6+0.4*intensity)
        mix[bt:bt+len(p)]+=p
        # bass pluck
        for b in range(4 if intensity>0.5 else 2):
            s=pluck(base/2 if intensity>0.5 else base,1.2,0.994)*0.35; o=bt+int(SR*beat*b*(4/(4 if intensity>0.5 else 2)))
            mix[o:o+len(s)]+=s[:L-o]
        # melody (guzheng-ish)
        sec=(bar//4)%4
        if not (sec==0 and bar<4 and intensity<0.5):
            steps=8
            for s_ in range(steps):
                if r.random()<(0.55+0.3*intensity):
                    idx=int(np.clip(motif[s_]+(sec%2)*2+r.integers(-1,2),0,len(notes)-1))
                    f=notes[idx]*2
                    s=pluck(f,1.4,0.997)*0.28; o=bt+int(SR*beat*s_/2)
                    mix[o:o+len(s)]+=s[:L-o]
                    if r.random()<0.25: # grace / tremolo
                        s2=pluck(f*2**(2/12),0.6)*0.12; o2=o+int(SR*beat/4); mix[o2:o2+len(s2)]+=s2[:L-o2]
        # drums
        if intensity>0.3:
            for b in range(4):
                o=bt+int(SR*beat*b)
                if b in (0,2) or intensity>0.8:
                    s=drum('taiko')*(0.7 if b in(0,2) else 0.45)*intensity; mix[o:o+len(s)]+=s[:L-o]
                if intensity>0.5:
                    for h in (0.5,):
                        s=drum('small')*0.6; o2=o+int(SR*beat*h); mix[o2:o2+len(s)]+=s[:L-o2]
        if bar%8==0:
            s=drum('gong')*(0.4+0.4*intensity); mix[bt:bt+len(s)]+=s[:L-bt]
    # fold tail into start for seamless loop
    body=int(SR*beat*4*bars); tail=mix[body:]; mix=mix[:body]; mix[:len(tail)]+=tail
    # simple stereo reverb-ish
    from scipy.signal import fftconvolve
    ir=rng.standard_normal(int(SR*1.2))*np.exp(-np.arange(int(SR*1.2))/(SR*0.3))*0.05
    wet=fftconvolve(np.concatenate([mix,mix]),ir)[len(mix):2*len(mix)]
    L_=mix+wet; R_=mix+np.roll(wet,int(SR*0.013))
    st=np.stack([L_,R_],1)
    save(name,st,'music',ogg=True)
    print(name)
song('hub',196,72,24,'gong',0.2,1)
song('battle1',220,112,32,'gong',0.75,2)
song('battle2',185,120,32,'yu',0.8,3)
song('boss',165,138,32,'yu',1.0,4)
song('prologue',147,96,24,'yu',0.6,5)
song('calm',262,80,16,'gong',0.1,6)
