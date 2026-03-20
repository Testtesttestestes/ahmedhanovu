#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import List, Tuple

from PIL import Image, ImageDraw, ImageFont

PAGE_WIDTH = 1654
PAGE_HEIGHT = 2339
MARGIN_X = 120
MARGIN_Y = 120
CONTENT_WIDTH = PAGE_WIDTH - 2 * MARGIN_X
SECTION_GAP = 42
TEXT_GAP = 18
CAPTION_GAP = 14
IMAGE_GAP = 26
BACKGROUND = "#f8fafc"
TEXT = "#0f172a"
MUTED = "#475569"
ACCENT = "#1d4ed8"
CARD = "#e2e8f0"


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = []
    if bold:
        candidates = [
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
            "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf",
        ]
    else:
        candidates = [
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf",
        ]

    for candidate in candidates:
        path = Path(candidate)
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


TITLE_FONT = load_font(52, bold=True)
SUBTITLE_FONT = load_font(28)
HEADING_FONT = load_font(34, bold=True)
BODY_FONT = load_font(24)
CAPTION_FONT = load_font(22)
META_FONT = load_font(26)


def wrap_text(text: str, font: ImageFont.ImageFont, width: int) -> List[str]:
    dummy = Image.new("RGB", (10, 10))
    draw = ImageDraw.Draw(dummy)
    lines: List[str] = []
    for paragraph in text.splitlines() or [""]:
        words = paragraph.split()
        if not words:
            lines.append("")
            continue
        current = words[0]
        for word in words[1:]:
            attempt = f"{current} {word}"
            if draw.textlength(attempt, font=font) <= width:
                current = attempt
            else:
                lines.append(current)
                current = word
        lines.append(current)
    return lines


class PdfCanvas:
    def __init__(self) -> None:
        self.pages: List[Image.Image] = []
        self.page: Image.Image | None = None
        self.draw: ImageDraw.ImageDraw | None = None
        self.cursor_y = MARGIN_Y
        self.new_page()

    def new_page(self) -> None:
        self.page = Image.new("RGB", (PAGE_WIDTH, PAGE_HEIGHT), BACKGROUND)
        self.draw = ImageDraw.Draw(self.page)
        self.cursor_y = MARGIN_Y
        self.pages.append(self.page)

    def ensure_space(self, required_height: int) -> None:
        if self.cursor_y + required_height <= PAGE_HEIGHT - MARGIN_Y:
            return
        self.new_page()

    def text_block(
        self,
        text: str,
        font: ImageFont.ImageFont,
        fill: str = TEXT,
        line_spacing: int = 10,
        top_gap: int = 0,
    ) -> int:
        lines = wrap_text(text, font, CONTENT_WIDTH)
        bbox = font.getbbox("Ag")
        line_height = (bbox[3] - bbox[1]) + line_spacing
        total_height = max(line_height, len(lines) * line_height)
        self.ensure_space(total_height + top_gap)
        self.cursor_y += top_gap
        assert self.draw is not None
        for line in lines:
            self.draw.text((MARGIN_X, self.cursor_y), line, font=font, fill=fill)
            self.cursor_y += line_height
        return total_height

    def centered_text(self, text: str, font: ImageFont.ImageFont, fill: str = TEXT, gap_after: int = 0) -> int:
        lines = wrap_text(text, font, CONTENT_WIDTH)
        bbox = font.getbbox("Ag")
        line_height = (bbox[3] - bbox[1]) + 12
        total_height = len(lines) * line_height
        self.ensure_space(total_height)
        assert self.draw is not None
        for line in lines:
            width = self.draw.textlength(line, font=font)
            x = (PAGE_WIDTH - width) / 2
            self.draw.text((x, self.cursor_y), line, font=font, fill=fill)
            self.cursor_y += line_height
        self.cursor_y += gap_after
        return total_height

    def divider(self) -> None:
        self.ensure_space(24)
        assert self.draw is not None
        y = self.cursor_y + 10
        self.draw.rounded_rectangle((MARGIN_X, y, PAGE_WIDTH - MARGIN_X, y + 4), radius=2, fill=CARD)
        self.cursor_y = y + 24

    def metadata_table(self, items: List[Tuple[str, str]]) -> None:
        if not items:
            return
        row_height = 58
        total_height = row_height * len(items) + 30
        self.ensure_space(total_height)
        assert self.draw is not None
        left = MARGIN_X
        right = PAGE_WIDTH - MARGIN_X
        top = self.cursor_y
        self.draw.rounded_rectangle((left, top, right, top + total_height), radius=28, fill="#ffffff", outline=CARD, width=2)
        y = top + 18
        label_width = 360
        for label, value in items:
            self.draw.text((left + 24, y), f"{label}:", font=META_FONT, fill=ACCENT)
            value_lines = wrap_text(value, META_FONT, CONTENT_WIDTH - label_width - 40)
            value_text = "\n".join(value_lines)
            self.draw.multiline_text((left + label_width, y), value_text, font=META_FONT, fill=TEXT, spacing=8)
            y += row_height
        self.cursor_y = top + total_height + SECTION_GAP

    def image_with_caption(self, image_path: Path, caption: str) -> None:
        image = Image.open(image_path).convert("RGB")
        max_width = CONTENT_WIDTH
        max_height = 1050
        scale = min(max_width / image.width, max_height / image.height, 1)
        target_size = (max(1, int(image.width * scale)), max(1, int(image.height * scale)))
        image = image.resize(target_size, Image.Resampling.LANCZOS)
        caption_lines = wrap_text(caption, CAPTION_FONT, CONTENT_WIDTH)
        caption_height = len(caption_lines) * ((CAPTION_FONT.getbbox("Ag")[3] - CAPTION_FONT.getbbox("Ag")[1]) + 8)
        needed = image.height + CAPTION_GAP + caption_height + IMAGE_GAP
        self.ensure_space(needed)
        assert self.page is not None and self.draw is not None
        x = int((PAGE_WIDTH - image.width) / 2)
        self.page.paste(image, (x, self.cursor_y))
        self.cursor_y += image.height + CAPTION_GAP
        for line in caption_lines:
            width = self.draw.textlength(line, font=CAPTION_FONT)
            self.draw.text(((PAGE_WIDTH - width) / 2, self.cursor_y), line, font=CAPTION_FONT, fill=MUTED)
            self.cursor_y += (CAPTION_FONT.getbbox("Ag")[3] - CAPTION_FONT.getbbox("Ag")[1]) + 8
        self.cursor_y += IMAGE_GAP


def render_report(manifest: dict, output: Path) -> None:
    canvas = PdfCanvas()
    canvas.centered_text(manifest["title"], TITLE_FONT, fill=TEXT, gap_after=12)
    if manifest.get("subtitle"):
        canvas.centered_text(manifest["subtitle"], SUBTITLE_FONT, fill=MUTED, gap_after=20)
    canvas.divider()
    canvas.metadata_table([(item["label"], item["value"]) for item in manifest.get("metadata", [])])

    for section in manifest.get("sections", []):
        canvas.text_block(section["heading"], HEADING_FONT, fill=ACCENT, top_gap=0)
        for paragraph in section.get("body", []):
            canvas.text_block(paragraph, BODY_FONT, fill=TEXT, top_gap=TEXT_GAP)
        if section.get("image"):
            canvas.cursor_y += TEXT_GAP
            canvas.image_with_caption(Path(section["image"]), section.get("caption", ""))
        else:
            canvas.cursor_y += SECTION_GAP

    first, *rest = [page.convert("RGB") for page in canvas.pages]
    output.parent.mkdir(parents=True, exist_ok=True)
    first.save(output, save_all=True, append_images=rest, resolution=150.0)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Build a PDF report from a JSON manifest.")
    parser.add_argument("manifest")
    parser.add_argument("output")
    args = parser.parse_args()

    manifest = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    render_report(manifest, Path(args.output))
