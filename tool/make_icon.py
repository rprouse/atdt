# /// script
# dependencies = ["pillow"]
# ///
"""Draws the app icon: ATDT in JetBrains Mono, phosphor green on the
green-phosphor theme's background, with a cursor and faint scanlines.

    uv run tool/make_icon.py

Writes assets/icon/icon.png (full square, iOS and legacy Android) and
assets/icon/foreground.png (transparent, inside Android's adaptive-icon
safe zone). flutter_launcher_icons turns them into every platform size.
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 1024
BACKGROUND = (10, 18, 10, 255)  # green phosphor theme background
PHOSPHOR = (65, 255, 99, 255)  # green phosphor theme foreground
FONT = "assets/fonts/files/JetBrainsMono-Regular.ttf"


def draw_mark(size: int, scale: float) -> Image.Image:
    """The text and cursor on a transparent square; scale is the share of
    the square the mark may use."""
    mark = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(mark)
    font = ImageFont.truetype(FONT, int(size * 0.2 * scale / 0.66))
    text = "ATDT"
    left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
    cursor_w = (right - left) / len(text) * 0.75
    width = right - left + cursor_w * 1.3
    x = (size - width) / 2 - left
    y = (size - (bottom - top)) / 2 - top
    stroke = max(1, int(size * 0.005 * scale / 0.66))
    draw.text((x, y), text, font=font, fill=PHOSPHOR, stroke_width=stroke, stroke_fill=PHOSPHOR)
    cx = x + right + cursor_w * 0.3
    draw.rectangle(
        [cx, y + top, cx + cursor_w, y + bottom], fill=PHOSPHOR
    )
    # Phosphor glow behind the strokes.
    glow = mark.filter(ImageFilter.GaussianBlur(size * 0.012))
    return Image.alpha_composite(glow, mark)


def scanlines(image: Image.Image) -> Image.Image:
    lines = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(lines)
    step = image.size[1] // 128
    for y in range(0, image.size[1], step):
        draw.rectangle([0, y, image.size[0], y + step // 3], fill=(0, 0, 0, 45))
    return Image.alpha_composite(image, lines)


def main() -> None:
    full = Image.new("RGBA", (SIZE, SIZE), BACKGROUND)
    full = Image.alpha_composite(full, draw_mark(SIZE, 0.8))
    scanlines(full).convert("RGB").save("assets/icon/icon.png")
    # Adaptive foreground: the system masks to a shape and may crop to the
    # inner 66%, so the mark stays well inside it.
    scanlines(draw_mark(SIZE, 0.6)).save("assets/icon/foreground.png")


if __name__ == "__main__":
    main()
