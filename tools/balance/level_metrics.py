#!/usr/bin/env python3
"""Static balance metrics per level: enemy effective HP, spawn density, sun supply, objectives.
Usage: python3 tools/balance/level_metrics.py [--csv out.csv]"""
import json, pathlib, re, sys, csv
root = pathlib.Path(__file__).resolve().parents[2]
WORLDS = ['lawn','pool','night','desert','roof','frost','factory','moon']
def zstats():
    out = {}
    for f in (root/'data/zombies').glob('*.tres'):
        t = f.read_text(); g = lambda k, d: float(m.group(1)) if (m := re.search(rf'^{k} = ([-\d.]+)', t, re.M)) else d
        zid = re.search(r'^id = &"(\w+)"', t, re.M).group(1)
        out[zid] = {'hp': g('hp', 270) + g('armor_hp', 0), 'speed': g('speed', .18), 'cost': g('threat_cost', 1)}
    return out
def rows():
    Z = zstats(); res = []
    for w in WORLDS:
        d = json.loads((root/f'data/campaign/{w}.json').read_text())
        for lv in d['levels']:
            hp = 0; n = 0; last = 0; boss = 0
            for i, ws in enumerate(lv['wave_specs']):
                for s in ws['spawns']:
                    z = Z.get(s['id'], {'hp': 0}); hp += z['hp']; n += 1
                    boss += 'gargantuan' in s['id'] or z['hp'] >= 3000
            t = lv['first_wave_delay'] + lv['wave_interval'] * max(0, len(lv['wave_specs']) - 1)
            sky = (t / lv['sky_sun_interval'] * lv['sky_sun_value']) if lv['sky_sun'] else 0
            res.append({'id': lv['id'], 'mode': lv['mode'], 'waves': len(lv['wave_specs']), 'spawns': n, 'total_hp': int(hp),
                        'hp_per_s': round(hp / max(1, t), 1), 'bosses': boss, 'start_sun': lv['start_sun'], 'sky_sun': int(sky),
                        'seeds': len(lv['fixed_seeds']) or 'pick', 'objectives': ';'.join(f"{o['type']}={o['target']}" for o in lv['objectives']),
                        'field_rule': lv['field_rule'], 'duration_s': int(t)})
    return res
if __name__ == '__main__':
    r = rows()
    if '--csv' in sys.argv:
        with open(sys.argv[sys.argv.index('--csv') + 1], 'w', newline='') as f:
            wr = csv.DictWriter(f, r[0].keys()); wr.writeheader(); wr.writerows(r)
    else:
        for x in r: print(x)
