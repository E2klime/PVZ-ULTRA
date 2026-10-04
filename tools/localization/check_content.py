#!/usr/bin/env python3
"""Coverage check: every player-visible authored string (campaign map names,
level titles/briefings/jokes, workshop names/descriptions, plant badges) must
resolve through Loc.text() to units present in localization/content.csv, and
every tr() key used in code must exist in localization/translations.csv."""
import csv, json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPLIT = re.compile(r'(?<=[.!?])[\'")]?\s+')

def sentences(s):
    out, start = [], 0
    for m in SPLIT.finditer(s):
        cut = m.start() + len(m.group(0).strip())
        out.append(s[start:cut]); start = m.end()
    if start < len(s): out.append(s[start:])
    return out

def resolve(s, units, missing):
    if not s or s in units or s.strip().replace('-', '').isdigit(): return
    if ' · ' in s:
        for p in s.split(' · '): resolve(p, units, missing)
        return
    if '\n' in s:
        for p in s.split('\n'): resolve(p, units, missing)
        return
    parts = sentences(s)
    if len(parts) <= 1:
        missing.add(s); return
    for p in parts:
        if p not in units: missing.add(p)

def main():
    units = {r['keys'] for r in csv.DictReader(open(ROOT / 'localization/content.csv', encoding='utf-8'))}
    keys = {r['keys'] for r in csv.DictReader(open(ROOT / 'localization/translations.csv', encoding='utf-8'))}
    texts = []
    for f in sorted((ROOT / 'data/campaign').glob('*.json')):
        d = json.loads(f.read_text(encoding='utf-8'))
        texts.append(d['name'])
        for l in d['levels']:
            texts += [l['title'], l['briefing'], l['joke']]
    for r in json.loads((ROOT / 'data/crafting/workshop.json').read_text(encoding='utf-8')):
        texts += [r['name'], r['description']]
    for f in (ROOT / 'data/plants').glob('*.tres'):
        m = re.search(r'^badge = "(.*)"$', f.read_text(encoding='utf-8'), re.M)
        if m: texts.append(m.group(1))
    missing = set()
    for t in texts: resolve(t, units, missing)
    used = set()
    for f in list((ROOT).glob('ui/*.gd')) + list(ROOT.glob('core/**/*.gd')) + list(ROOT.glob('entities/**/*.gd')) + list(ROOT.glob('autoload/*.gd')):
        used |= set(re.findall(r'(?:tr|translate)\("([A-Z][A-Z0-9_]+)"\)', f.read_text(encoding='utf-8')))
    for f in ROOT.glob('data/**/*.tres'):
        used |= set(re.findall(r'_key = "([A-Z][A-Z0-9_]+)"', f.read_text(encoding='utf-8')))
    legacy = {k for k in used if k.startswith(('LEVEL_', 'HINT_'))}  # unused data/levels/*.tres
    unknown = sorted(used - keys - legacy)
    print(f'{len(keys)} UI keys, {len(units)} content units, {len(texts)} authored strings')
    print(f'missing content units: {len(missing)}'); [print('  ', m) for m in sorted(missing)[:30]]
    print(f'unknown tr() keys: {len(unknown)}'); [print('  ', k) for k in unknown[:30]]
    sys.exit(1 if missing or unknown else 0)

if __name__ == '__main__':
    main()
