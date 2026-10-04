"""v0.7 campaign pass: new reward plants + Cardboard Box / Balloon / Slingshot zombies
injected into later defense levels. Idempotent (skips levels already patched)."""
import json, random
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
REWARDS = {('lawn', 8): 'pumpkin_shell', ('lawn', 10): 'clod_catapult', ('lawn', 12): 'thorn_carpet', ('lawn', 15): 'pea_bedding',
           ('lawn', 23): 'turbo_bean', ('pool', 3): 'garlic_drone', ('pool', 8): 'spine_cactus', ('pool', 12): 'cloud_bloom',
           ('pool', 25): 'aegis_pumpkin', ('night', 12): 'bean_patriarch', ('desert', 12): 'sky_dragon', ('roof', 25): 'chrono_clover',
           ('frost', 25): 'thunder_root', ('factory', 12): 'starfall_melon'}
ORDER = ['lawn', 'pool', 'night', 'desert', 'roof', 'frost', 'factory', 'moon']
def stage(world, n): return ORDER.index(world) * 100 + n
BOX_FROM, BALLOON_FROM, SLING_FROM = stage('lawn', 16), stage('pool', 14), stage('pool', 17)
rng = random.Random(77)
total = {'box': 0, 'balloon': 0, 'sling': 0, 'reward': 0}
for world in ORDER:
    p = ROOT / 'data/campaign' / f'{world}.json'
    doc = json.loads(p.read_text())
    for lv in doc['levels']:
        n = lv['number']; st = stage(world, n)
        key = (world, n)
        if key in REWARDS and not lv.get('reward_plant'):
            lv['reward_plant'] = REWARDS[key]; total['reward'] += 1
        if lv.get('mode') != 'defense' or lv.get('fixed_seeds') or lv.get('v07'):
            continue
        specs = lv.get('wave_specs') or []
        if not specs:
            continue
        pool = lv.setdefault('zombie_pool', [])
        added = []
        for wi, w in enumerate(specs):
            if wi == 0:
                continue
            spawns = w.setdefault('spawns', [])
            frac = wi / max(1, len(specs) - 1)
            leaders = [s for s in spawns if s['id'] in ('shambler', 'cone_head', 'bucket_head', 'flagbearer', 'newspaper')]
            if st >= BOX_FROM and leaders and rng.random() < 0.35 + 0.3 * frac:
                L = rng.choice(leaders)
                spawns.append({'id': 'box_zombie', 'row': L['row'], 'delay': round(float(L.get('delay', 0)) + 0.8, 2)})
                added.append('box_zombie'); total['box'] += 1
            if st >= BALLOON_FROM and rng.random() < 0.18 + 0.25 * frac:
                spawns.append({'id': 'balloon_zombie', 'row': rng.randrange(5), 'delay': round(rng.uniform(1, 6), 2)})
                added.append('balloon_zombie'); total['balloon'] += 1
            if st >= SLING_FROM and rng.random() < 0.15 + 0.2 * frac:
                spawns.append({'id': 'slingshot_zombie', 'row': rng.randrange(5), 'delay': round(rng.uniform(1, 6), 2)})
                added.append('slingshot_zombie'); total['sling'] += 1
        # water rows: balloons fly, sling/box need grass; keep them off pure water rows
        layout = lv.get('layout') or []
        for w in specs:
            for s in w.get('spawns', []):
                if s['id'] in ('box_zombie', 'slingshot_zombie') and layout and '~' in layout[s['row']][-1:]:
                    s['row'] = next((r for r in range(5) if '~' not in layout[r][-1:]), s['row'])
        for z in sorted(set(added)):
            if z not in pool:
                pool.append(z)
        if added:
            tip = []
            if 'box_zombie' in added: tip.append('Cardboard Box zombies hide behind others: use low shots, catapults or thorns.')
            if 'balloon_zombie' in added: tip.append('Balloons fly over ground plants: bring anti-air.')
            if 'slingshot_zombie' in added: tip.append('Slingshots target flying plants.')
            lv['joke'] = (lv.get('joke', '') + ' ' + ' '.join(tip)).strip()
        lv['v07'] = True
    p.write_text(json.dumps(doc, indent=1, ensure_ascii=False))
print(total)
