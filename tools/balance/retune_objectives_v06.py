#!/usr/bin/env python3
"""v0.6b objective retune after the first full 200-level sweep (see docs/testing/balance_log.json).
Findings: caps of 16-17 lost with 800-1200 unspent sun; loss limit 2 failed in wave 2; rush+loss-6
combos failed on losses in all three worlds; late mowerless levels breached early.
Idempotent: sets absolute values."""
import json, pathlib, re, datetime
root = pathlib.Path(__file__).resolve().parents[2]
W = ['lawn','pool','night','desert','roof','frost','factory','moon']
LIMIT       = dict(zip(W, [20,22,20,20,20,20,20,19]))
LIMIT_FIXED = dict(zip(W, [20,24,22,22,22,24,24,24]))   # 4-seed basic deck: room for Twin Pod evolutions
PRESERVE    = dict(zip(W, [3,3,3,3,3,3,3,3]))
LOSS        = dict(zip(W, [5,5,5,5,5,5,5,4]))
def setnum(lv, kind, n, pattern):
    for o in lv['objectives']:
        if o['type'] == kind and o['target'] != n:
            old = o['target']; o['target'] = n
            lv['briefing'] = re.sub(pattern.format(old), lambda m: m.group(0).replace(str(old), str(n)), lv['briefing'])
            return (kind, old, n)
log_path = root/'docs/testing/balance_log.json'
log = json.loads(log_path.read_text()) if log_path.exists() else []
for w in W:
    p = root/f'data/campaign/{w}.json'; d = json.loads(p.read_text())
    for lv in d['levels']:
        sc = lv['scenario']; ch = []
        if sc == 'limit': ch.append(setnum(lv, 'plant_limit', LIMIT[w], r'at most {} planting'))
        if sc == 'limited_fixed': ch.append(setnum(lv, 'plant_limit', LIMIT_FIXED[w], r'limit of {} planting'))
        if sc == 'preserve': ch.append(setnum(lv, 'loss_limit', PRESERVE[w], r'no more than {} plants'))
        if sc == 'loss': ch.append(setnum(lv, 'loss_limit', LOSS[w], r'no more than {} plants'))
        if sc == 'rush': ch.append(setnum(lv, 'loss_limit', 10, r'no more than {} plants'))
        if sc == 'mowerless' and W.index(w) >= 3 and 'mowerless_sun' not in lv.get('tuning', []):
            lv['start_sun'] += 100; lv.setdefault('tuning', []).append('mowerless_sun'); ch.append(('start_sun', lv['start_sun'] - 100, lv['start_sun']))
        ch = [c for c in ch if c]
        if ch:
            e = dict(level=lv['id'], date=datetime.date.today().isoformat(), reason='v0.6b objective retune after sweep 1', changes=ch); log.append(e); print(e)
    p.write_text(json.dumps(d, indent=1, ensure_ascii=False) + '\n')
log_path.write_text(json.dumps(log, indent=1) + '\n')
