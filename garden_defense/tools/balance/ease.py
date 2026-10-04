#!/usr/bin/env python3
"""Apply one recorded easing step to specific levels (balance loop helper).
Each step: trim ~8% of unprotected enemy HP (heaviest spawns from the heaviest waves, never
bosses/flagbearers, never below 2 spawns per wave) and add +75 starting sun.
Every change is appended to docs/testing/balance_log.json with before/after numbers.
Usage: python3 tools/balance/ease.py --reason "strong bot 0/2" night_23 desert_18 ..."""
import json, pathlib, sys, argparse, datetime
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from remix_v06 import Z, total, trim, WORLDS
root = pathlib.Path(__file__).resolve().parents[2]
ap = argparse.ArgumentParser(); ap.add_argument('levels', nargs='+'); ap.add_argument('--reason', required=True)
ap.add_argument('--trim', type=float, default=0.08); ap.add_argument('--sun', type=int, default=75); a = ap.parse_args()
log_path = root/'docs/testing/balance_log.json'
log = json.loads(log_path.read_text()) if log_path.exists() else []
by_world = {}
for lid in a.levels: by_world.setdefault(lid.split('_')[0], []).append(lid)
for w, ids in by_world.items():
    p = root/f'data/campaign/{w}.json'; d = json.loads(p.read_text())
    for lv in d['levels']:
        if lv['id'] not in ids: continue
        before = total(lv); sun0 = lv['start_sun']
        removed = trim(lv, before * (1 - a.trim)) if lv['mode'] != 'holdout' else 0
        if lv['mode'] == 'defense': lv['start_sun'] += a.sun
        entry = dict(level=lv['id'], date=datetime.date.today().isoformat(), reason=a.reason, hp_before=int(before), hp_after=int(total(lv)),
                     spawns_removed=removed, start_sun=[sun0, lv['start_sun']])
        log.append(entry); print(entry)
    p.write_text(json.dumps(d, indent=1, ensure_ascii=False) + '\n')
log_path.write_text(json.dumps(log, indent=1) + '\n')
