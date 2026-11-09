#!/usr/bin/env python3
"""Generate the 6x9 terminal TTF from the glyph atlas and register it in assets/manifest.json.

Byte b maps to U+E000+b, so guest bytes can never form a rich-text tag. U+E100 is a
font-only full block for text-drawn backgrounds and U+E101 the one-pixel cursor bar. Development-only: needs fontTools
(4.68) and Pillow; the build checks only the recorded hashes.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ATLAS = 'assets/glyphs/atlas.png'
FONT = 'assets/fonts/tc-term.ttf'
TOOL = 'tools/terminal_font.py'
U = 128  # font units per glyph pixel
BLOCK, CURSOR = 0xE100, 0xE101


def digest(data):
    return hashlib.sha256(data).hexdigest()


def font_bytes(atlas):
    from PIL import Image
    from fontTools.fontBuilder import FontBuilder
    from fontTools.pens.ttGlyphPen import TTGlyphPen
    image = Image.open(io.BytesIO(atlas)).convert('RGBA')

    def outline(lit):
        pen = TTGlyphPen(None)
        for j in range(9):
            i = 0
            while i < 6:  # one clockwise rectangle per horizontal pixel run
                if lit(i, j):
                    s = i
                    while i < 6 and lit(i, j):
                        i += 1
                    x0, x1, y1 = s * U, i * U, (9 - j) * U
                    pen.moveTo((x0, y1 - U)); pen.lineTo((x0, y1)); pen.lineTo((x1, y1)); pen.lineTo((x1, y1 - U))
                    pen.closePath()
                else:
                    i += 1
        return pen.glyph()

    order, glyphs, cmap, metrics = ['.notdef'], {'.notdef': TTGlyphPen(None).glyph()}, {}, {'.notdef': (6 * U, 0)}
    for b in range(256):
        ox, oy = (b % 16) * 6, (b // 16) * 9
        name = 'g%03d' % b
        order.append(name); cmap[0xE000 + b] = name; metrics[name] = (6 * U, 0)
        glyphs[name] = outline(lambda i, j: image.getpixel((ox + i, oy + j))[3] > 127)
    order.append('block'); cmap[BLOCK] = 'block'; metrics['block'] = (6 * U, 0)
    glyphs['block'] = outline(lambda i, j: True)
    order.append('cursor'); cmap[CURSOR] = 'cursor'; metrics['cursor'] = (6 * U, 0)
    glyphs['cursor'] = outline(lambda i, j: j == 8)
    builder = FontBuilder(9 * U, isTTF=True)
    builder.setupGlyphOrder(order)
    builder.setupCharacterMap(cmap)
    builder.setupGlyf(glyphs)
    builder.setupHorizontalMetrics(metrics)
    builder.setupHorizontalHeader(ascent=9 * U, descent=0, lineGap=0)
    builder.setupNameTable({'familyName': 'TC Terminal', 'styleName': 'Regular'})
    builder.setupOS2(sTypoAscender=9 * U, sTypoDescender=0, sTypoLineGap=0, usWinAscent=9 * U, usWinDescent=0)
    builder.setupPost(isFixedPitch=1)
    builder.font['head'].created = builder.font['head'].modified = 0  # deterministic bytes
    stream = io.BytesIO()
    builder.save(stream)
    return stream.getvalue()


def record(font):
    return {'path': FONT, 'sha256': digest(font), 'license': 'MIT', 'notices': ['assets/notices/Tweaked-Computers-MIT.txt'],
            'codepoints': {'bytes': [0xE000, 0xE0FF], 'full_block': BLOCK, 'cursor': CURSOR},
            'inputs': [{'path': p, 'sha256': digest((ROOT / p).read_bytes())} for p in (ATLAS, TOOL)]}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--check', action='store_true', help='fail when the committed font or its record is stale')
    args = ap.parse_args()
    font = font_bytes((ROOT / ATLAS).read_bytes())
    path, manifest_path = ROOT / FONT, ROOT / 'assets/manifest.json'
    manifest = json.loads(manifest_path.read_text())
    if args.check:
        if not path.is_file() or path.read_bytes() != font or manifest.get('fonts') != [record(font)]:
            raise SystemExit('stale terminal font; run tools/terminal_font.py')
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(font)
    manifest['fonts'] = [record(font)]
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
    print(json.dumps({'path': FONT, 'sha256': digest(font)}))


if __name__ == '__main__':
    main()
