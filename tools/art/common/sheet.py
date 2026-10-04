"""Tiny Pillow layout helpers for review/reference sheets (labels, swatches, fitting).

Text on review sheets is rendered with real fonts here — never by the image model.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
_FONT_CANDIDATES = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    str(ROOT / "assets" / "fonts" / "NotoSansJP-GD.otf"),
]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    order = _FONT_CANDIDATES[1:2] + _FONT_CANDIDATES if bold else _FONT_CANDIDATES
    for p in order:
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def fit(im: Image.Image, w: int, h: int | None = None) -> Image.Image:
    """Resize keeping aspect so the image fits inside w x h (h optional)."""
    k = w / im.width
    if h is not None:
        k = min(k, h / im.height)
    return im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)


def text(draw: ImageDraw.ImageDraw, xy: tuple[int, int], s: str, size: int = 28,
         fill: str = "#3b2a1a", bold: bool = False) -> int:
    """Draw (multi-line) text, return the y below it."""
    f = font(size, bold)
    draw.multiline_text(xy, s, font=f, fill=fill, spacing=int(size * 0.35))
    box = draw.multiline_textbbox(xy, s, font=f, spacing=int(size * 0.35))
    return box[3]


def swatch_row(draw: ImageDraw.ImageDraw, xy: tuple[int, int], colors: list[str],
               size: int = 46, labels: bool = True) -> None:
    x, y = xy
    for c in colors:
        draw.rounded_rectangle((x, y, x + size, y + size), radius=8, fill=c, outline="#2c2418", width=2)
        if labels:
            draw.text((x, y + size + 4), c, font=font(13), fill="#3b2a1a")
        x += size + (40 if labels else 14)


def shadowed_paste(canvas: Image.Image, im: Image.Image, xy: tuple[int, int]) -> None:
    """Paste with a soft drop shadow (review sheet cosmetics)."""
    from PIL import ImageFilter
    sh = Image.new("RGBA", (im.width + 40, im.height + 40), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rectangle((20, 20, 20 + im.width, 20 + im.height), fill=(40, 30, 20, 110))
    sh = sh.filter(ImageFilter.GaussianBlur(10))
    canvas.alpha_composite(sh, (xy[0] - 14, xy[1] - 10))
    canvas.alpha_composite(im.convert("RGBA"), xy)
