#!/usr/bin/env python3
"""v0.6 campaign data pass (idempotent: refuses to re-apply).
1. Per-world scenario remix inside same-size slot groups (lawn keeps tutorial order).
2. Difficulty-spike trimming (armor / gauntlet / rush) against each world's own curve.
3. Per-world objective targets and combined objectives, with briefing text kept in sync.
Run: python3 tools/balance/remix_v06.py [--dry-run]"""
import json, pathlib, re, sys, statistics
root = pathlib.Path(__file__).resolve().parents[2]
WORLDS = ['lawn','pool','night','desert','roof','frost','factory','moon']
REV = 'v0.6'
GROUPS = [[6,7,10],[12,13,14,17],[18,19,20,23]]
# Destination slot i of each group takes the scenario originally at ORDER[w][g][i].
ORDER = {
 'pool':    [[7,6,10],[13,12,17,14],[18,20,19,23]],
 'night':   [[10,7,6],[14,17,12,13],[23,18,20,19]],
 'desert':  [[6,10,7],[17,13,14,12],[19,23,18,20]],
 'roof':    [[7,10,6],[12,14,17,13],[20,19,23,18]],
 'frost':   [[10,6,7],[13,17,12,14],[18,23,19,20]],
 'factory': [[6,7,10],[17,12,13,14],[23,20,18,19]],
 'moon':    [[7,10,6],[14,13,17,12],[19,18,23,20]],
}
POSITIONAL = ['id','number','reward_plant','reward_feature','reward_coins','materials','artillery_damage','artillery_cooldown','hybrid_cap']
PROTECT = ('flagbearer',)
def zhp():
    out = {}
    for f in (root/'data/zombies').glob('*.tres'):
        t = f.read_text(); g = lambda k, d: float(m.group(1)) if (m := re.search(rf'^{k} = ([-\d.]+)', t, re.M)) else d
        out[re.search(r'^id = &"(\w+)"', t, re.M).group(1)] = g('hp', 270) + g('armor_hp', 0)
    return out
Z = zhp()
def total(lv): return sum(Z[s['id']] for w in lv['wave_specs'] for s in w['spawns'])
def protected(s): return s['id'] in PROTECT or 'gargantuan' in s['id'] or Z[s['id']] >= 3000
def trim(lv, target, min_per_wave=2):
    """Remove the heaviest unprotected spawn from the heaviest wave until under target."""
    removed = 0
    while total(lv) > target:
        waves = sorted(lv['wave_specs'], key=lambda w: -sum(Z[s['id']] for s in w['spawns']))
        done = False
        for w in waves:
            cand = [s for s in w['spawns'] if not protected(s)]
            if len(w['spawns']) <= min_per_wave or not cand: continue
            w['spawns'].remove(max(cand, key=lambda s: Z[s['id']])); removed += 1; done = True; break
        if not done: break
    return removed
def set_obj(lv, kind, target, sentence=None):
    for o in lv['objectives']:
        if o['type'] == kind: o['target'] = target; return
    lv['objectives'].append({'type': kind, 'target': target})
    if sentence: lv['briefing'] = lv['briefing'].rstrip() + ' ' + sentence
def retarget_text(lv, old, new):
    lv['briefing'] = lv['briefing'].replace(old, new)

# Per-world objective variety: (scenario -> callable)
def variety(world, wi, lv):
    sc = lv['scenario']
    if sc in ('limit', 'limited_fixed'):
        n = [20,20,18,20,18,18,17,16][wi]
        retarget_text(lv, 'at most 20 planting', f'at most {n} planting'); retarget_text(lv, 'limit of 20 planting', f'limit of {n} planting')
        set_obj(lv, 'plant_limit', n)
        if world in ('desert','moon') and sc == 'limit': set_obj(lv, 'loss_limit', 6, 'Bonus clause: lose no more than 6 plants.')
    elif sc == 'preserve':
        n = [3,3,3,2,3,2,3,2][wi]
        retarget_text(lv, 'no more than 3 plants', f'no more than {n} plants'); set_obj(lv, 'loss_limit', n)
        if world == 'factory': set_obj(lv, 'plant_limit', 26, 'Union rules also cap you at 26 planting actions.')
    elif sc == 'loss':
        n = [5,5,5,4,5,4,4,3][wi]
        retarget_text(lv, 'no more than 5 plants', f'no more than {n} plants'); set_obj(lv, 'loss_limit', n)
    elif sc == 'bank':
        n = [4000,3500,4000,4500,4000,4500,4500,4500][wi]
        retarget_text(lv, 'Hold 4000', f'Hold {n}'); set_obj(lv, 'bank_sun', n)
        if world in ('roof','moon'): set_obj(lv, 'loss_limit', 8, 'The accountant also forbids losing more than 8 plants.')
    elif sc == 'collect':
        n = [4000,4000,4500,4500,4500,5000,5000,5000][wi]
        retarget_text(lv, 'total of 4000 sun', f'total of {n} sun'); set_obj(lv, 'collect_sun', n)
        if world == 'frost': set_obj(lv, 'no_breach', 0, 'The house is also off-limits: no breaches.')
    elif sc == 'rush':
        # A real deadline: authored duration + per-wave crowd allowance + a cleanup window.
        lv['first_wave_delay'] = 35; lv['wave_interval'] = 27
        n = int(round((35 + 27 * (len(lv['wave_specs']) - 1) + 15 * len(lv['wave_specs']) + 110) / 10.0) * 10)
        lv['briefing'] = re.sub(r'within \d+ seconds', f'within {n} seconds', lv['briefing']); set_obj(lv, 'time_limit', n)
        if world in ('frost','factory','moon'): set_obj(lv, 'loss_limit', 6, 'Speed is not an excuse: lose no more than 6 plants.')
    elif sc == 'mowerless' and world in ('night','frost'):
        set_obj(lv, 'loss_limit', 8, 'Also lose no more than 8 plants.')
    elif sc == 'elite' and world in ('roof','factory'):
        set_obj(lv, 'plant_limit', 30, 'Specialists bill hourly: at most 30 planting actions.')
    elif sc == 'summons' and world in ('desert','moon'):
        set_obj(lv, 'no_breach', 0, 'No breaches: interns are not allowed indoors.')

def main(dry):
    data = {w: json.loads((root/f'data/campaign/{w}.json').read_text()) for w in WORLDS}
    if any(d.get('balance_revision') == REV for d in data.values()):
        sys.exit(f'{REV} already applied; restore manifests from git/zip before re-running.')
    report = []
    first_seen = {}
    for wi, w in enumerate(WORLDS):
        levels = data[w]['levels']
        if w in ORDER:
            orig = {lv['number']: json.loads(json.dumps(lv)) for lv in levels}
            for g, order in zip(GROUPS, ORDER[w]):
                for dest, src in zip(g, order):
                    if dest == src: continue
                    new = json.loads(json.dumps(orig[src]))
                    for k in POSITIONAL: new[k] = orig[dest][k]
                    new['title'] = re.sub(r'^\d-\d\d', f'{wi+1}-{dest:02}', orig[src]['title'])
                    levels[dest-1] = new
                    report.append(f'{w}_{dest:02} <- {orig[src]["scenario"]} (was slot {src})')
        # introduction check: a zombie must not appear before its first original appearance
        for lv in levels:
            for zid in {s['id'] for ws in lv['wave_specs'] for s in ws['spawns']}:
                first_seen.setdefault(zid, (wi, lv['number']))
        # curve of "plain" levels for spike targets
        plain = [lv for lv in levels if lv['scenario'] in ('introduce','elite','fixed','loss','blocked','blackout','summons','limit','preserve','mowerless','limited_fixed') and lv['mode']=='defense']
        xs = [lv['number'] for lv in plain]; ys = [total(lv) for lv in plain]
        mx, my = statistics.mean(xs), statistics.mean(ys)
        slope = sum((x-mx)*(y-my) for x, y in zip(xs, ys)) / sum((x-mx)**2 for x in xs)
        ref = lambda n: my + slope * (n - mx)
        boss = next(lv for lv in levels if lv['scenario'] == 'boss')
        for lv in levels:
            sc = lv['scenario']; before = total(lv)
            if sc == 'armor': r = trim(lv, 1.35 * ref(lv['number']))
            elif sc == 'gauntlet':
                r = trim(lv, min(1.4 * ref(lv["number"]), 0.95 * total(boss)))
                lv['start_sun'] += 150; lv['first_wave_delay'] = max(lv['first_wave_delay'], 50)
                # the opener may not be heavier than the boss level's opener
                while len(lv['wave_specs'][0]['spawns']) > len(boss['wave_specs'][0]['spawns']) + 1:
                    cand = [s for s in lv['wave_specs'][0]['spawns'] if not protected(s)]
                    if not cand: break
                    lv['wave_specs'][0]['spawns'].remove(max(cand, key=lambda s: Z[s['id']])); r += 1
                if w != 'moon':
                    lv['briefing'] = lv['briefing'].replace(' On the Moon, all three Gargantuans arrive in separate waves.', ' Pace your economy: the waves never stop being polite about it.')
            elif sc == 'rush': r = trim(lv, 1.05 * ref(lv['number'])); lv['start_sun'] += 100
            else: r = 0
            if r: report.append(f'{lv["id"]} {sc}: trimmed {r} spawns, HP {int(before)} -> {int(total(lv))}')
            if lv['mode'] == 'holdout':
                lv['briefing'] = lv['briefing'].replace('Collect sun and protect it;', 'Protect it;')
            variety(w, wi, lv)
        data[w]['balance_revision'] = REV
    # introduction-order violations
    for wi, w in enumerate(WORLDS):
        for lv in data[w]['levels']:
            for zid in {s['id'] for ws in lv['wave_specs'] for s in ws['spawns']}:
                if (wi, lv['number']) < first_seen[zid]: report.append(f'WARN early appearance {zid} at {lv["id"]}')
    print('\n'.join(report))
    if not dry:
        for w in WORLDS:
            (root/f'data/campaign/{w}.json').write_text(json.dumps(data[w], indent=1, ensure_ascii=False) + '\n')
if __name__ == '__main__': main('--dry-run' in sys.argv)
