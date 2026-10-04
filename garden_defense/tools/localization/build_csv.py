#!/usr/bin/env python3
"""Build localization/translations.csv (UI keys) and localization/content.csv
(authored campaign/workshop/badge text keyed by its English source) from the
sources in tools/localization/src. Validates placeholders and BBCode tags.

Sources:
  src/ui_en.json        {KEY: English}         (literal "\\n" = line break)
  src/content_en.json   [English unit, ...]    (index = unit id)
  src/<lang>_ui.tsv     KEY<TAB>text
  src/<lang>_content.tsv  index<TAB>text
"""
import csv, json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(__file__).resolve().parent / 'src'
LANGS = ['ru', 'zh_CN', 'ja', 'de']
PH = re.compile(r'\{\w+\}')

def tsv(path):
    out = {}
    for line in path.read_text(encoding='utf-8').splitlines():
        if line.strip():
            k, v = line.split('\t', 1)
            out[k] = v
    return out

def check(key, en, tr, lang, errors):
    if sorted(PH.findall(en)) != sorted(PH.findall(tr)):
        errors.append(f'{lang} {key}: placeholders differ')
    for tag in ('[b]', '[/b]'):
        if en.count(tag) != tr.count(tag):
            errors.append(f'{lang} {key}: {tag} count differs')
    if not tr.strip():
        errors.append(f'{lang} {key}: empty')

def main():
    errors = []
    ui = json.loads((SRC / 'ui_en.json').read_text(encoding='utf-8'))
    units = json.loads((SRC / 'content_en.json').read_text(encoding='utf-8'))
    ui_tr = {l: tsv(SRC / f'{l}_ui.tsv') for l in LANGS}
    ct_tr = {l: tsv(SRC / f'{l}_content.tsv') for l in LANGS}
    for l in LANGS:
        for k in ui:
            if k not in ui_tr[l]: errors.append(f'{l} UI missing {k}')
            else: check(k, ui[k], ui_tr[l][k], l, errors)
        for k in ui_tr[l]:
            if k not in ui: errors.append(f'{l} UI unknown key {k}')
        for i, u in enumerate(units):
            if str(i) not in ct_tr[l]: errors.append(f'{l} content missing #{i}')
            else: check(f'#{i}', u, ct_tr[l][str(i)], l, errors)
    if len(set(units)) != len(units):
        errors.append('duplicate content units')
    if errors:
        print('\n'.join(errors[:50])); print(f'{len(errors)} errors'); sys.exit(1)
    nl = lambda s: s.replace('\\n', '\n')
    with open(ROOT / 'localization/translations.csv', 'w', encoding='utf-8', newline='') as f:
        w = csv.writer(f, lineterminator='\n')
        w.writerow(['keys', 'en'] + LANGS)
        for k in sorted(ui):
            w.writerow([k, nl(ui[k])] + [nl(ui_tr[l][k]) for l in LANGS])
    with open(ROOT / 'localization/content.csv', 'w', encoding='utf-8', newline='') as f:
        w = csv.writer(f, lineterminator='\n')
        w.writerow(['keys', 'en'] + LANGS)
        for i, u in enumerate(units):
            w.writerow([u, u] + [ct_tr[l][str(i)] for l in LANGS])
    print(f'translations.csv: {len(ui)} keys; content.csv: {len(units)} units; languages: en, ' + ', '.join(LANGS))

if __name__ == '__main__':
    main()
