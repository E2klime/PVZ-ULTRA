# Localization (v0.7)

Languages: English (`en`), Russian (`ru`), Simplified Chinese (`zh_CN`), Japanese (`ja`), German (`de`).
First launch picks the OS language if supported (`Settings.detect_language()`); the player can change it in Settings at any time.

## Two translation tables
| File | Keyed by | Contains |
|---|---|---|
| `localization/translations.csv` | UI key (`MENU_PLAY`, `PLANT_*_DESC`, ...) | Menus, HUD, help, almanac, objectives, toasts, names/descriptions |
| `localization/content.csv` | English source text | Authored data: campaign titles/briefings/jokes, workshop, badges, quests |

Both are generated - **do not edit them by hand**. Edit the sources in `tools/localization/src/`:
- `ui_en.json` - `{KEY: English}`; `<lang>_ui.tsv` - `KEY<TAB>text`
- `content_en.json` - list of English units; `<lang>_content.tsv` - `index<TAB>text`

Build and check:
```
python3 tools/localization/check_content.py   # every authored string has a unit, no stale units
python3 tools/localization/build_csv.py       # writes both CSVs, validates {placeholders} and BBCode
godot --headless --path . --editor --import --quit
godot --headless --path . -s res://tools/tests/loc_test.gd   # every key/unit translated in every locale
```

## Code rules
- UI text: `tr("KEY")`, placeholders via `.format({...})` - never concatenate translated fragments.
- Data text (campaign/workshop/badges): `Loc.text(s)` / `Loc.title(s)` (`core/loc.gd`), which look up `content.csv`.
- Objectives, field rules and tool names are built from keys (`ObjectiveTracker.describe()`, `FieldRules.rule_name()`, `CraftingSystem.tool_name()`).
- Long strings: use `UIKit.fit_label()` or autowrap; German and Russian are ~30-40% longer than English.
- `tools/strings_en.py` regenerates an English-only CSV and refuses to run without `--force`.

## Fonts
`assets/fonts/NotoSansSC-GD.otf` and `NotoSansJP-GD.otf` are subsets (OFL, see `OFL.txt`) of the CJK characters used by the game.
`Settings._apply_fonts()` puts the locale's CJK font first in the fallback chain. After adding new zh/ja text re-run
`python3 tools/localization/subset_fonts.py` (needs the full Noto fonts, see `assets/fonts/README.md`).

## Adding a language
1. Add `<lang>_ui.tsv` and `<lang>_content.tsv`, add the code to `LANGS` in `build_csv.py` and to the locale list in `tools/tests/loc_test.gd`.
2. Add it to `Settings.ENABLED_LANGUAGES` (and a font to `CJK_FONTS` if needed).
3. Register `localization/*.<lang>.translation` in `project.godot` (`internationalization/locale/translations`).
4. Build, import, run `loc_test.gd`, and take screenshots: `res://tools/screenshot.tscn -- <dir> <lang>`.
