# Fonts

- `NotoSansSC-GD.otf` — subset of Noto Sans SC Medium (Simplified Chinese).
- `NotoSansJP-GD.otf` — subset of Noto Sans JP Medium (Japanese).

Both are © Google / Adobe, licensed under the SIL Open Font License 1.1 (`OFL.txt`).
They only contain the glyphs used by the game's Chinese and Japanese text plus
basic Latin and CJK punctuation. `autoload/settings.gd` chains them as fallbacks
of the default font, preferring JP shapes for Japanese and SC shapes otherwise.

Regenerate after editing translations: `python3 tools/localization/subset_fonts.py`.
