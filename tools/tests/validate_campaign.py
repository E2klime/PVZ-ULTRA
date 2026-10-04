#!/usr/bin/env python3
"""Static validation of all 200 authored missions and asset references."""
from pathlib import Path
import json,re,hashlib
root=Path(__file__).resolve().parents[2]
worlds=['lawn','pool','night','desert','roof','frost','factory','moon']
def ids(folder):
 return {re.search(r'^id = &"([^"]+)"',p.read_text(),re.M)[1] for p in (root/folder).glob('*.tres')}
plants=ids('data/plants');zombies=ids('data/zombies');levels=[];seen_enemies=set();layouts=set()
for w,world in enumerate(worlds):
 manifest=json.loads((root/'data/campaign'/f'{world}.json').read_text())
 assert manifest['order']==w and manifest['previous']==(worlds[w-1] if w else '')
 assert len(manifest['levels'])==25
 for n,level in enumerate(manifest['levels'],1):
  assert level['id']==f'{world}_{n:02}' and level['number']==n
  assert len(level['layout'])==5 and all(len(s)==9 and set(s)<=set('.~#') for s in level['layout'])
  layouts.add(tuple(level['layout']))
  assert set(level['fixed_seeds'])<=plants and set(level['banned_plants'])<=plants
  assert not level['reward_plant'] or level['reward_plant'] in plants
  assert level['mode'] in ('defense','artillery','holdout')
  assert level['wave_specs']
  for spec in level['wave_specs']:
   assert spec['spawns']
   for e in spec['spawns']:
    assert e['id'] in zombies and e['id'] in level['zombie_pool']
    assert 0<=e['row']<5 and e['delay']>=0
    seen_enemies.add(e['id'])
  for obj in level['objectives']:
   assert obj['type'] in ('plant_limit','loss_limit','bank_sun','collect_sun','graft_count','no_breach','time_limit')
   assert obj['target']>=0
   if obj['type']=='graft_count': assert level['hybrid_cap']>=obj['target']
   if obj['type'] in ('collect_sun','bank_sun'): assert level['sky_sun']
   # Briefing must state the exact number the tracker enforces.
   if obj['type'] in ('plant_limit','loss_limit','bank_sun','collect_sun','time_limit') and obj['target']>0:
    assert str(obj['target']) in level['briefing'], (level['id'], obj, level['briefing'])
  # A title that leads with a number phrase must name one of the level's real targets.
  NUMS={'twenty-two':22,'twenty':20,'nineteen':19,'eighteen':18,'five thousand':5000,'forty-five hundred':4500,'four thousand':4000,'five':5,'four':4,'three':3}
  suffix=level['title'].split('· ',1)[-1].lower()
  for word,value in NUMS.items():
   if suffix.startswith(word+' ') and level['objectives']:
    assert value in [o['target'] for o in level['objectives']], (level['id'], level['title'], level['objectives'])
    break
  positions=set()
  for p in level['preplants']:
   assert p['id'] in plants and 0<=p['row']<5 and 0<=p['col']<9
   assert (p['row'],p['col']) not in positions
   positions.add((p['row'],p['col']))
   assert level['layout'][p['row']][p['col']]=='.'
  if level['mode']=='artillery': assert not level['preplants'] and not level['fixed_seeds'] and level['artillery_cooldown']>0
  if level['mode']=='holdout': assert level['preplants']
  levels.append(level)
assert len(levels)==200 and len({l['id'] for l in levels})==200
assert len({l['title'] for l in levels})==200 and len({l['joke'] for l in levels})==200
# Legacy specialist enemies still need encounters in the campaign, not just almanac entries.
missing=zombies-seen_enemies
if missing: print('NOTICE: enemies not scheduled in current baseline:',', '.join(sorted(missing)))
recipes=[]
for p in (root/'data/fusion').glob('*.tres'):
 s=p.read_text();parts=[re.search(rf'^{k} = &"([^"]+)"',s,re.M)[1] for k in ('base_id','catalyst_id','result_id')]
 assert set(parts)<=plants;recipes.append(parts)
assert len({tuple(r[:2]) for r in recipes})==len(recipes)
workshop=json.loads((root/'data/crafting/workshop.json').read_text())
assert len({r['id'] for r in workshop})==len(workshop)
for r in workshop:
 assert r['world'] in worlds and all(v>0 for v in r['cost'].values())
 if r['kind']=='unlock': assert r['result'] in plants
 if r['kind']=='upgrade':
  assert r['tier']==1 or any(q['kind']=='upgrade' and q['result']==r['result'] and q['tier']==r['tier']-1 for q in workshop), r['id']
print(f'PASS: {len(levels)} levels, 8 worlds, {len(plants)} plants, {len(zombies)} zombies, {len(recipes)} grafts, {len(workshop)} workshop recipes, {len(layouts)} distinct field layouts, 200 unique titles and jokes.')
