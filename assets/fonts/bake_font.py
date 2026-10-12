"""Bake Spectral Semibold into a small, single-page BMFont atlas using Pillow.

Usage: python3 assets/fonts/bake_font.py /path/to/Spectral-SemiBold.ttf
The generated font and its source are licensed under the accompanying OFL.txt.
"""

from pathlib import Path
import sys

from PIL import Image, ImageDraw, ImageFont


def bake(source: Path, destination: Path) -> None:
    font = ImageFont.truetype(str(source), 64)
    codepoints = [*range(32, 127), 0x2212]
    bounds = {code: font.getbbox(chr(code)) for code in codepoints}
    top = min(box[1] for box in bounds.values())
    bottom = max(box[3] for box in bounds.values())
    line_height = bottom - top + 8
    baseline = font.getmetrics()[0] - top + 4
    atlas_width = 512
    padding = 4
    x = y = padding
    row_height = 0
    glyphs = []

    for code in codepoints:
        left, upper, right, lower = bounds[code]
        width, height = max(1, right - left), max(1, lower - upper)
        if x + width + padding > atlas_width:
            x, y = padding, y + row_height + 2 * padding
            row_height = 0
        glyphs.append((code, x, y, width, height, left, upper - top + 4,
                       round(font.getlength(chr(code)))))
        row_height = max(row_height, height)
        x += width + 2 * padding

    atlas_height = 1 << (y + row_height + padding - 1).bit_length()
    mask = Image.new("L", (atlas_width, atlas_height), 0)
    draw = ImageDraw.Draw(mask)
    for code, x, y, _, _, _, _, _ in glyphs:
        left, upper, _, _ = bounds[code]
        draw.text((x - left, y - upper), chr(code), font=font, fill=255)
    # White luminance even in transparent pixels avoids dark filtering fringes.
    atlas = Image.merge("LA", (Image.new("L", mask.size, 255), mask))
    destination.mkdir(parents=True, exist_ok=True)
    atlas.save(destination / "spectral-semibold.png", optimize=True)

    lines = [
        'info face="Spectral SemiBold" size=64 bold=0 italic=0 charset="" '
        'unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=0,0',
        f"common lineHeight={line_height} base={baseline} scaleW={atlas_width} "
        f"scaleH={atlas_height} pages=1 packed=0",
        'page id=0 file="spectral-semibold.png"',
        f"chars count={len(glyphs)}",
    ]
    for code, x, y, width, height, offset_x, offset_y, advance in glyphs:
        lines.append(
            f"char id={code} x={x} y={y} width={width} height={height} "
            f"xoffset={offset_x} yoffset={offset_y} xadvance={advance} page=0 chnl=15"
        )
    (destination / "spectral-semibold.fnt").write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    bake(Path(sys.argv[1]), Path(__file__).resolve().parent)
