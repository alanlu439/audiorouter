#!/usr/bin/env python3
"""Build the AudioRouter user manual PDF from USER_MANUAL.md."""

from __future__ import annotations

from pathlib import Path
import re

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    KeepTogether,
    ListFlowable,
    ListItem,
    PageBreak,
    Paragraph,
    Preformatted,
    SimpleDocTemplate,
    Spacer,
)


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "USER_MANUAL.md"
OUTPUT = ROOT / "docs" / "assets" / "AudioRouter-User-Manual.pdf"


def clean_inline(text: str) -> str:
    text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    text = re.sub(r"`([^`]+)`", r"<font name='Courier'>\1</font>", text)
    text = text.replace("**", "")
    return text


def page_footer(canvas, doc):
    canvas.saveState()
    width, _ = letter
    canvas.setFillColor(colors.HexColor("#6f7780"))
    canvas.setFont("Helvetica", 8)
    canvas.drawString(doc.leftMargin, 0.42 * inch, "AudioRouter User Manual")
    canvas.drawRightString(width - doc.rightMargin, 0.42 * inch, f"Page {doc.page}")
    canvas.restoreState()


def build_pdf() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    styles = getSampleStyleSheet()
    styles.add(
        ParagraphStyle(
            name="ManualTitle",
            parent=styles["Title"],
            fontName="Helvetica-Bold",
            fontSize=30,
            leading=34,
            textColor=colors.HexColor("#102026"),
            spaceAfter=18,
            alignment=TA_LEFT,
        )
    )
    styles.add(
        ParagraphStyle(
            name="ManualH2",
            parent=styles["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=17,
            leading=21,
            textColor=colors.HexColor("#102026"),
            spaceBefore=16,
            spaceAfter=8,
        )
    )
    styles.add(
        ParagraphStyle(
            name="ManualBody",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=10.5,
            leading=15.5,
            textColor=colors.HexColor("#2c363d"),
            spaceAfter=7,
        )
    )
    styles.add(
        ParagraphStyle(
            name="ManualBullet",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=10.3,
            leading=14.5,
            textColor=colors.HexColor("#2c363d"),
            leftIndent=8,
        )
    )
    styles.add(
        ParagraphStyle(
            name="ManualCode",
            parent=styles["Code"],
            fontName="Courier",
            fontSize=9.4,
            leading=12,
            textColor=colors.HexColor("#102026"),
            backColor=colors.HexColor("#eef6f5"),
            borderColor=colors.HexColor("#cde7e3"),
            borderWidth=0.5,
            borderPadding=6,
            spaceBefore=4,
            spaceAfter=10,
        )
    )

    story = []
    bullet_items = []
    numbered_items = []
    code_lines = []
    in_code = False

    def flush_bullets():
        nonlocal bullet_items
        if bullet_items:
            story.append(
                ListFlowable(
                    [ListItem(Paragraph(item, styles["ManualBullet"])) for item in bullet_items],
                    bulletType="bullet",
                    start="circle",
                    leftIndent=18,
                    bulletFontSize=8,
                    spaceAfter=8,
                )
            )
            bullet_items = []

    def flush_numbered():
        nonlocal numbered_items
        if numbered_items:
            story.append(
                ListFlowable(
                    [ListItem(Paragraph(item, styles["ManualBullet"])) for item in numbered_items],
                    bulletType="1",
                    leftIndent=18,
                    bulletFontSize=9,
                    spaceAfter=8,
                )
            )
            numbered_items = []

    def flush_code():
        nonlocal code_lines
        if code_lines:
            story.append(Preformatted("\n".join(code_lines), styles["ManualCode"]))
            code_lines = []

    for raw_line in SOURCE.read_text(encoding="utf-8").splitlines():
        line = raw_line.rstrip()
        if line.startswith("```"):
            if in_code:
                flush_code()
                in_code = False
            else:
                flush_bullets()
                flush_numbered()
                in_code = True
            continue

        if in_code:
            code_lines.append(line)
            continue

        if not line:
            flush_bullets()
            flush_numbered()
            story.append(Spacer(1, 2))
            continue

        if line.startswith("# "):
            flush_bullets()
            flush_numbered()
            story.append(Paragraph(clean_inline(line[2:]), styles["ManualTitle"]))
            story.append(Paragraph("A practical guide to installing, routing, Group Play, EQ, updates, and troubleshooting.", styles["ManualBody"]))
            story.append(Spacer(1, 8))
            continue

        if line.startswith("## "):
            flush_bullets()
            flush_numbered()
            if story:
                heading = Paragraph(clean_inline(line[3:]), styles["ManualH2"])
                story.append(KeepTogether([heading]))
            continue

        if line.startswith("- "):
            flush_numbered()
            bullet_items.append(clean_inline(line[2:]))
            continue

        number_match = re.match(r"^\d+\.\s+(.*)$", line)
        if number_match:
            flush_bullets()
            numbered_items.append(clean_inline(number_match.group(1)))
            continue

        flush_bullets()
        flush_numbered()
        story.append(Paragraph(clean_inline(line), styles["ManualBody"]))

    flush_bullets()
    flush_numbered()
    flush_code()
    story.append(PageBreak())
    story.append(Paragraph("Need the latest build?", styles["ManualH2"]))
    story.append(Paragraph(clean_inline("Visit https://alanlu439.github.io/audiorouter/ or the latest GitHub Release."), styles["ManualBody"]))

    document = SimpleDocTemplate(
        str(OUTPUT),
        pagesize=letter,
        leftMargin=0.72 * inch,
        rightMargin=0.72 * inch,
        topMargin=0.72 * inch,
        bottomMargin=0.68 * inch,
        title="AudioRouter User Manual",
        author="AudioRouter",
    )
    document.build(story, onFirstPage=page_footer, onLaterPages=page_footer)


if __name__ == "__main__":
    build_pdf()
