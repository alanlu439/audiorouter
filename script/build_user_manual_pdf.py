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
    Flowable,
    KeepTogether,
    ListFlowable,
    ListItem,
    PageBreak,
    Paragraph,
    Preformatted,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "USER_MANUAL.md"
OUTPUT = ROOT / "docs" / "assets" / "AudioRouter-User-Manual.pdf"

NAVY = colors.HexColor("#083447")
INK = colors.HexColor("#102026")
BODY = colors.HexColor("#2c363d")
MUTED = colors.HexColor("#687985")
TEAL = colors.HexColor("#18d6c2")
TEAL_DARK = colors.HexColor("#007b78")
SIGNAL = colors.HexColor("#ffb44e")
ICE = colors.HexColor("#e9f7ff")
MINT = colors.HexColor("#ddfbf6")
CREAM = colors.HexColor("#fff7e6")
LINE = colors.HexColor("#cde7e3")


class CoverPanel(Flowable):
    """Branded cover block with a small route graphic."""

    def __init__(self):
        super().__init__()
        self.width = 7.06 * inch
        self.height = 3.0 * inch

    def draw(self):
        c = self.canv
        c.saveState()
        c.setFillColor(NAVY)
        c.roundRect(0, 0, self.width, self.height, 18, fill=1, stroke=0)
        c.setFillColor(colors.HexColor("#0f5260"))
        c.circle(self.width - 0.8 * inch, self.height - 0.5 * inch, 1.55 * inch, fill=1, stroke=0)
        c.setFillColor(colors.HexColor("#0b4050"))
        c.circle(self.width - 0.2 * inch, 0.12 * inch, 1.15 * inch, fill=1, stroke=0)

        c.setFillColor(TEAL)
        c.roundRect(0.34 * inch, self.height - 0.92 * inch, 0.56 * inch, 0.56 * inch, 10, fill=1, stroke=0)
        c.setFillColor(NAVY)
        c.setFont("Helvetica-Bold", 14)
        c.drawCentredString(0.62 * inch, self.height - 0.72 * inch, "AU")

        c.setFillColor(colors.white)
        c.setFont("Helvetica-Bold", 28)
        c.drawString(1.02 * inch, self.height - 0.58 * inch, "AudioRouter")
        c.setFont("Helvetica", 12)
        c.setFillColor(colors.HexColor("#c7f7f1"))
        c.drawString(1.04 * inch, self.height - 0.90 * inch, "User Manual")

        c.setFillColor(colors.white)
        c.setFont("Helvetica-Bold", 16)
        c.drawString(0.42 * inch, 1.26 * inch, "Route apps. Control outputs. Save reliable setups.")
        c.setFont("Helvetica", 9.5)
        c.setFillColor(colors.HexColor("#d9eef0"))
        c.drawString(0.42 * inch, 0.94 * inch, "A practical guide to installing, routing, Group Play, EQ, updates, and troubleshooting.")

        labels = [("Source App", 0.52), ("Output", 2.24), ("Setup", 3.62)]
        y = 0.38 * inch
        for label, x in labels:
            c.setFillColor(colors.HexColor("#123f4e"))
            c.roundRect(x * inch, y, 1.15 * inch, 0.34 * inch, 8, fill=1, stroke=0)
            c.setFillColor(colors.white)
            c.setFont("Helvetica-Bold", 7.5)
            c.drawCentredString((x + 0.575) * inch, y + 0.12 * inch, label.upper())
        c.setStrokeColor(SIGNAL)
        c.setLineWidth(2.2)
        c.line(1.68 * inch, y + 0.17 * inch, 2.13 * inch, y + 0.17 * inch)
        c.line(3.39 * inch, y + 0.17 * inch, 3.51 * inch, y + 0.17 * inch)
        c.restoreState()


class RouteDiagram(Flowable):
    """Small visual model of the product's route flow."""

    def __init__(self):
        super().__init__()
        self.width = 7.06 * inch
        self.height = 1.55 * inch

    def draw(self):
        c = self.canv
        c.saveState()
        c.setFillColor(colors.HexColor("#f4fffd"))
        c.setStrokeColor(LINE)
        c.roundRect(0, 0, self.width, self.height, 12, fill=1, stroke=1)
        c.setFillColor(INK)
        c.setFont("Helvetica-Bold", 10)
        c.drawString(0.24 * inch, self.height - 0.35 * inch, "Visual route model")

        boxes = [
            ("Spotify", "source app", 0.36, TEAL),
            ("Group Play 1", "speaker group", 2.75, SIGNAL),
            ("Saved Setup", "profile preset", 5.1, NAVY),
        ]
        y = 0.33 * inch
        for title, subtitle, x, fill in boxes:
            c.setFillColor(fill)
            c.roundRect(x * inch, y, 1.42 * inch, 0.54 * inch, 9, fill=1, stroke=0)
            c.setFillColor(colors.white)
            c.setFont("Helvetica-Bold", 8.5)
            c.drawString((x + 0.14) * inch, y + 0.31 * inch, title)
            c.setFont("Helvetica", 7)
            c.drawString((x + 0.14) * inch, y + 0.15 * inch, subtitle)

        c.setStrokeColor(NAVY)
        c.setLineWidth(1.8)
        for x1, x2 in [(1.86, 2.62), (4.25, 4.98)]:
            c.line(x1 * inch, y + 0.27 * inch, x2 * inch, y + 0.27 * inch)
            c.line(x2 * inch, y + 0.27 * inch, (x2 - 0.09) * inch, y + 0.34 * inch)
            c.line(x2 * inch, y + 0.27 * inch, (x2 - 0.09) * inch, y + 0.20 * inch)
        c.restoreState()


def status_legend():
    data = [
        ["Badge", "Meaning"],
        ["Working", "The current backend can perform the action."],
        ["Saved Only", "The route preference is stored and will retry later."],
        ["Experimental", "AudioRouter is trying a live public-API route."],
        ["Requires Backend", "A deeper audio driver or service is required."],
    ]
    table = Table(data, colWidths=[1.55 * inch, 5.12 * inch], hAlign="LEFT")
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), NAVY),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("FONTNAME", (0, 1), (0, -1), "Helvetica-Bold"),
                ("TEXTCOLOR", (0, 1), (0, -1), TEAL_DARK),
                ("TEXTCOLOR", (1, 1), (1, -1), BODY),
                ("BACKGROUND", (0, 1), (-1, -1), colors.HexColor("#fbfffe")),
                ("GRID", (0, 0), (-1, -1), 0.35, LINE),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("LEFTPADDING", (0, 0), (-1, -1), 9),
                ("RIGHTPADDING", (0, 0), (-1, -1), 9),
                ("TOPPADDING", (0, 0), (-1, -1), 8),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
            ]
        )
    )
    return table


def clean_inline(text: str) -> str:
    text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    text = re.sub(r"`([^`]+)`", r"<font name='Courier'>\1</font>", text)
    text = text.replace("**", "")
    return text


def page_footer(canvas, doc):
    canvas.saveState()
    width, height = letter
    canvas.setFillColor(colors.white)
    canvas.rect(0, 0, width, height, fill=1, stroke=0)
    canvas.setFillColor(MUTED)
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
            fontSize=26,
            leading=30,
            textColor=NAVY,
            spaceAfter=14,
            alignment=TA_LEFT,
        )
    )
    styles.add(
        ParagraphStyle(
            name="ManualH2",
            parent=styles["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=16,
            leading=20,
            textColor=NAVY,
            backColor=colors.HexColor("#f4fffd"),
            borderColor=LINE,
            borderWidth=0.5,
            borderPadding=6,
            spaceBefore=14,
            spaceAfter=9,
        )
    )
    styles.add(
        ParagraphStyle(
            name="ManualBody",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=10.5,
            leading=15.5,
            textColor=BODY,
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
            textColor=BODY,
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
            textColor=INK,
            backColor=colors.HexColor("#eef6f5"),
            borderColor=LINE,
            borderWidth=0.5,
            borderPadding=6,
            spaceBefore=4,
            spaceAfter=10,
        )
    )
    styles.add(
        ParagraphStyle(
            name="ManualLead",
            parent=styles["ManualBody"],
            fontName="Helvetica-Bold",
            fontSize=11.5,
            leading=16,
            textColor=NAVY,
            backColor=colors.HexColor("#fff7e6"),
            borderColor=colors.HexColor("#f2cf95"),
            borderWidth=0.5,
            borderPadding=8,
            spaceBefore=6,
            spaceAfter=10,
        )
    )

    story = [CoverPanel(), Spacer(1, 14), RouteDiagram(), Spacer(1, 14), status_legend(), Spacer(1, 12)]
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
        callout_markers = (
            "The public ZIP may not be Apple-notarized",
            "If a route shows",
            "Group Play is experimental",
            "The driver is experimental",
            "AudioRouter checks GitHub Releases",
        )
        style = styles["ManualLead"] if any(marker in line for marker in callout_markers) else styles["ManualBody"]
        story.append(Paragraph(clean_inline(line), style))

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
