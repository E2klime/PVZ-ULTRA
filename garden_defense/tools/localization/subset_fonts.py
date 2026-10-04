#!/usr/bin/env python3
"""Subset Noto Sans SC / JP (SIL OFL 1.1) to the glyphs used by the game's
Chinese and Japanese text, so the CJK fallback fonts stay small.
Run after build_csv.py whenever translations change:
  python3 tools/localization/subset_fonts.py [/path/to/google-noto-cjk]"""
import csv, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(sys.argv[1] if len(sys.argv) > 1 else '/usr/share/fonts/google-noto-cjk')
EXTRA = 'U+0020-007E,U+00A0-00FF,U+2010-2027,U+2190-2193,U+2605,U+3000-303F,U+FF01-FF5E'

chars = set()
for name in ('translations.csv', 'content.csv'):
    for row in csv.DictReader(open(ROOT / 'localization' / name, encoding='utf-8')):
        for col in ('zh_CN', 'ja'):
            chars |= {c for c in row[col] if ord(c) > 0x2E7F}
text = ROOT / 'tools/localization/.cjk_chars.txt'
text.write_text(''.join(sorted(chars)), encoding='utf-8')
for src, out in (('NotoSansSC-Medium.otf', 'NotoSansSC-GD.otf'), ('NotoSansJP-Medium.otf', 'NotoSansJP-GD.otf')):
    subprocess.run(['pyftsubset', str(SRC / src), f'--text-file={text}', f'--unicodes={EXTRA}',
                    '--layout-features=*', '--no-hinting', f'--output-file={ROOT / "assets/fonts" / out}'], check=True)
text.unlink()
print(f'{len(chars)} CJK characters subset into assets/fonts/NotoSans{{SC,JP}}-GD.otf')
