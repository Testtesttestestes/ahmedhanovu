#!/usr/bin/env python3
from pathlib import Path
import argparse
from PIL import Image, ImageDraw, ImageFont

parser = argparse.ArgumentParser()
parser.add_argument('input_file')
parser.add_argument('output_file')
parser.add_argument('--title', default='')
args = parser.parse_args()

text = Path(args.input_file).read_text(encoding='utf-8', errors='replace')
font = ImageFont.load_default()
lines = []
for raw_line in text.splitlines() or ['']:
    line = raw_line.expandtabs(4)
    while len(line) > 140:
        lines.append(line[:140])
        line = line[140:]
    lines.append(line)

if args.title:
    lines = [args.title, '-' * max(20, len(args.title))] + lines

line_height = 16
width = 1200
height = max(120, (len(lines) + 2) * line_height + 20)
img = Image.new('RGB', (width, height), '#111827')
draw = ImageDraw.Draw(img)

y = 12
for line in lines:
    draw.text((12, y), line, font=font, fill='#e5e7eb')
    y += line_height

Path(args.output_file).parent.mkdir(parents=True, exist_ok=True)
img.save(args.output_file)
