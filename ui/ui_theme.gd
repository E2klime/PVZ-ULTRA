class_name UITheme
extends RefCounted
## Theme entry point. Colours live here; painted styles come from ui/theme/* (kit built by
## tools/art/ui/build_ui.py). box()/panel_box() remain for code that needs an ad-hoc flat box.

const INK := Color(0.24, 0.16, 0.1)
const PAPER := Color(0.98, 0.93, 0.8)
const LEAF := Color(0.36, 0.62, 0.26)
const LEAF_DARK := Color(0.2, 0.4, 0.15)
const SUN := Color(1.0, 0.82, 0.25)
const BAD := Color(0.85, 0.25, 0.2)
## Legendary rarity accent (cards, almanac, shop).
const LEGEND := Color(0.85, 0.58, 0.08)
const LEGEND_LIGHT := Color(1.0, 0.9, 0.55)

static func box(bg: Color, border: Color, radius: int = 14, border_w: int = 4, margin: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	return s

## Painted kit style by name (see assets/ui/kit/styles).
static func kit(kit_name: String, content: int = -1, tint: Color = Color.WHITE) -> StyleBox:
	return KitStyles.get_style(kit_name, content, tint)

static func panel_box() -> StyleBox:
	return KitStyles.get_style("panel")

## Built at runtime (autoload UIBoot sets it as the root Window theme); never baked to .tres.
static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 26
	ThemeButtons.apply(t)
	ThemePanels.apply(t)
	ThemeBars.apply(t)
	ThemeWidgets.apply(t)
	ThemeFillIns.apply(t)
	return t
