"""Procedural placeholder SFX + music (numpy -> 16-bit wav). Run from project root:
python3 tools/audio/gen_audio.py"""
import numpy as np, wave, os
SR = 22050
rng = np.random.default_rng(7)
OUT = "audio"

def save(name, x, sub="sfx", sr=SR):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * 0.85
    path = os.path.join(OUT, sub, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes((x * 32767).astype(np.int16).tobytes())

def t(d): return np.arange(int(SR * d)) / SR
def env(n, a=0.005, r=0.1, d=None):
    tt = np.arange(n) / SR; dur = n / SR
    e = np.minimum(1, tt / max(a, 1e-4)) * np.clip((dur - tt) / max(r, 1e-4), 0, 1)
    return e
def sine(f, d): return np.sin(2*np.pi*np.cumsum(np.broadcast_to(f, (int(SR*d),)))/SR)
def sq(f, d, duty=0.5):
    ph = np.cumsum(np.broadcast_to(f, (int(SR*d),)))/SR % 1.0
    return np.where(ph < duty, 1.0, -1.0)
def tri(f, d):
    ph = np.cumsum(np.broadcast_to(f, (int(SR*d),)))/SR % 1.0
    return 4*np.abs(ph-0.5)-1
def noise(d): return rng.uniform(-1, 1, int(SR*d))
def lp(x, k=8):
    kern = np.ones(k)/k
    return np.convolve(x, kern, mode="same")
def sweep(f0, f1, d, curve=1.0):
    n = int(SR*d); u = np.linspace(0, 1, n)**curve
    return f0 + (f1-f0)*u

def decay(d, k): return np.exp(-t(d)*k)

# --- SFX ---
d=0.25; save("plant", lp(noise(d),30)*decay(d,18)*0.8 + sine(sweep(180,90,d),d)*decay(d,14))
d=0.3; save("shovel", lp(noise(d),4)*decay(d,10)*0.6 + sq(sweep(400,200,d),d,0.3)*decay(d,25)*0.3)
d=0.18; save("error", sq(np.where(t(d)<0.09,220,160),d,0.4)*env(int(SR*d),0.003,0.03)*0.5)
d=0.15; save("pick", sine(sweep(500,900,d),d)*decay(d,12))
d=0.6; x=sum(sine(f,d)*np.clip(1-(t(d)-i*0.08)*3,0,1)*(t(d)>i*0.08) for i,f in enumerate([880,1100,1320,1760])); save("star", x)
d=0.8; save("fuse", sine(sweep(300,1200,d,0.6),d)*env(int(SR*d),0.02,0.3)*0.6 + sine(sweep(450,1800,d,0.6),d)*env(int(SR*d),0.02,0.3)*0.3 + lp(noise(d),3)*decay(d,5)*0.2)
d=0.12; save("shoot", lp(noise(d),6)*decay(d,40)*0.6 + sine(sweep(320,140,d),d)*decay(d,30))
d=0.1; save("hit", lp(noise(d),10)*decay(d,45) + sine(sweep(200,90,d),d)*decay(d,40)*0.6)
d=0.25; save("chomp", (lp(noise(d),20)*(np.sin(2*np.pi*12*t(d))>0))*decay(d,8))
d=0.4; save("sun", sum(sine(f,d)*decay(d,6) for f in [1046,1318,1568])*0.4 + sine(sweep(1500,2600,d),d)*decay(d,14)*0.3)
d=0.35; save("coin", sq(np.where(t(d)<0.07,988,1319),d,0.25)*decay(d,7)*0.5)
d=0.9; save("explode", lp(noise(d),40)*decay(d,4) + sine(sweep(120,30,d),d)*decay(d,5))
d=0.5; save("freeze", sine(sweep(2400,1200,d),d)*decay(d,6)*0.4 + noise(d)*decay(d,9)*0.15)
d=1.0; base=sweep(110,80,d); g=(sq(base,d,0.3)*0.5+sine(base*2,d)*0.3)*(1+0.3*np.sin(2*np.pi*6*t(d))); save("groan", lp(g,25)*env(int(SR*d),0.15,0.4))
d=2.2; f=np.where(t(d)<1.0, 233, 175); save("huge_wave", lp(sq(f,d,0.45)+sq(f*1.5,d,0.45)*0.6,10)*env(int(SR*d),0.1,0.5))
d=0.08; save("click", sine(1400,d)*decay(d,60))
d=0.4; save("pause", sine(np.where(t(d)<0.12,660,440),d)*env(int(SR*d),0.005,0.2))
d=0.35; save("armor", sq(sweep(900,500,d),d,0.2)*decay(d,14)*0.4 + noise(d)*decay(d,25)*0.3)
d=0.5; save("pop_balloon", noise(d)*decay(d,30) + sine(sweep(600,200,d),d)*decay(d,10)*0.4)
d=0.3; save("zap", (sq(sweep(1800,300,d),d,0.5)*noise(d))*decay(d,9))
d=0.25; save("lob", sine(sweep(200,600,d),d)*decay(d,8)*0.6 + lp(noise(d),5)*decay(d,20)*0.3)
d=0.5; save("mower", lp(sq(70+10*np.sin(2*np.pi*20*t(d)),d,0.3),5)*env(int(SR*d),0.05,0.2))
# jingles
def notes(seq, bpm=140, wave_fn=sq, duty=0.5, vol=0.5):
    out=[]
    for n,l in seq:
        dd=60/bpm*l
        if n is None: out.append(np.zeros(int(SR*dd))); continue
        f=440*2**((n-69)/12)
        s=(wave_fn(f,dd,duty) if wave_fn is sq else wave_fn(f,dd))*env(int(SR*dd),0.005,dd*0.6)*vol
        out.append(s)
    return np.concatenate(out)
save("win", notes([(72,0.5),(76,0.5),(79,0.5),(84,1.5),(None,0.25),(79,0.5),(84,2)],160))
save("lose", notes([(67,0.75),(63,0.75),(60,0.75),(55,2)],100,tri))

# --- Music: simple looping chiptune (bass + arp + lead) ---
def track(name, bpm, chords, melody, bars_rep=2, lead_wave=sq):
    beat=60/bpm; parts=[]
    total=len(chords)*4*beat*bars_rep
    n=int(SR*total); mix=np.zeros(n)
    for rep in range(bars_rep):
        for ci,ch in enumerate(chords):
            t0=(rep*len(chords)+ci)*4*beat
            # bass on quarter notes
            for b in range(4):
                f=440*2**((ch[0]-12-69)/12)
                s=tri(f,beat*0.9)*env(int(SR*beat*0.9),0.005,0.1)*0.45
                i=int(SR*(t0+b*beat)); mix[i:i+len(s)]+=s[:n-i]
            # arp in 8ths
            for k in range(8):
                note=ch[k%len(ch)]+12
                f=440*2**((note-69)/12)
                s=sq(f,beat*0.45,0.25)*env(int(SR*beat*0.45),0.003,0.12)*0.12
                i=int(SR*(t0+k*beat/2)); mix[i:i+len(s)]+=s[:n-i]
            # soft hat
            for k in range(8):
                s=noise(0.04)*decay(0.04,90)*0.08
                i=int(SR*(t0+k*beat/2+beat/4)); mix[i:i+len(s)]+=s[:n-i]
    tpos=0.0
    for note,l in melody*bars_rep:
        dd=l*beat
        if note is not None:
            f=440*2**((note-69)/12)
            vib=f*(1+0.006*np.sin(2*np.pi*5.5*t(dd)))
            s=(lead_wave(vib,dd,0.5) if lead_wave is sq else lead_wave(vib,dd))*env(int(SR*dd),0.01,dd*0.4)*0.22
            i=int(SR*tpos)
            if i<n: mix[i:i+len(s)]+=s[:n-i]
        tpos+=dd
    save(name, lp(mix,3), "music")

C=[60,64,67]; Am=[57,60,64]; F=[53,57,60]; G=[55,59,62]; Dm=[50,53,57]; Em=[52,55,59]
track("menu", 96, [C,Am,F,G], [(72,1),(74,0.5),(76,1.5),(79,1),(77,1),(76,1),(74,2),(72,1),(69,1),(72,1),(74,1),(76,3),(None,1)], 2, tri)
track("battle", 128, [Am,F,C,G,Am,Dm,Em,Am], [(69,0.5),(72,0.5),(76,1),(74,0.5),(72,0.5),(69,1),(None,1),(65,0.5),(69,0.5),(72,1),(71,1),(None,1),(67,0.5),(71,0.5),(74,1),(72,1),(71,1),(69,2),(None,2),(72,1),(74,1),(76,2),(77,1),(76,1),(74,2),(72,1),(71,1),(69,4)], 2)
track("battle_night", 110, [Dm,Am,Em,Am], [(62,1),(65,1),(69,2),(67,1),(65,1),(64,2),(62,1),(64,1),(65,1),(67,1),(69,4)], 2, tri)
print("ok")
