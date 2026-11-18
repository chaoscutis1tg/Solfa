# -*- coding: utf-8 -*-
"""
Generator for ChaoNote (Solfa v1.9.4+26) System Analysis & Design Document (SRS & SDD v2.0).
Outputs:
  1. 10 High-Resolution Light-Blueprint UML Diagrams in d:/Solfa/docs/uml/*.png
  2. Complete Markdown SRS/SDD with Mermaid + Embedded UML PNGs: d:/Solfa/SYSTEM_DESIGN_SRS_SDD.md
  3. Complete Word Document (.docx) with Embedded UML PNGs & Tables: d:/Solfa/Phân tích thiết kế hệ thống Solfa.docx
"""

import os
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import docx
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import qn, nsdecls

ROOT = Path(r"d:/Solfa")
UML_DIR = ROOT / "docs" / "uml"
UML_DIR.mkdir(parents=True, exist_ok=True)

FONT_REG_PATH = r"C:/Windows/Fonts/arial.ttf"
FONT_BOLD_PATH = r"C:/Windows/Fonts/arialbd.ttf"
FONT_ITALIC_PATH = r"C:/Windows/Fonts/ariali.ttf"


def get_font(size: int, bold: bool = False, italic: bool = False):
    path = FONT_BOLD_PATH if bold else (FONT_ITALIC_PATH if italic else FONT_REG_PATH)
    if not os.path.exists(path):
        path = FONT_REG_PATH
    return ImageFont.truetype(path, size)


# Palette - Light Academic Blueprint
BG_COLOR = (255, 255, 255)
GRID_COLOR = (241, 245, 249)
BORDER_FRAME = (203, 213, 225)
HEADER_BG = (30, 58, 138)       # Deep Indigo
HEADER_TEXT = (255, 255, 255)

INDIGO_FILL = (238, 242, 255)
INDIGO_STROKE = (67, 56, 202)
INDIGO_DARK = (49, 46, 129)

BLUE_FILL = (239, 246, 255)
BLUE_STROKE = (37, 99, 235)
BLUE_DARK = (30, 58, 138)

EMERALD_FILL = (236, 253, 245)
EMERALD_STROKE = (5, 150, 105)
EMERALD_DARK = (6, 95, 70)

AMBER_FILL = (255, 251, 235)
AMBER_STROKE = (217, 119, 6)
AMBER_DARK = (146, 64, 14)

ROSE_FILL = (255, 241, 242)
ROSE_STROKE = (225, 29, 72)
ROSE_DARK = (159, 18, 57)

PURPLE_FILL = (250, 245, 255)
PURPLE_STROKE = (126, 34, 206)
PURPLE_DARK = (88, 28, 135)

SLATE_FILL = (248, 250, 252)
SLATE_STROKE = (100, 116, 139)
SLATE_DARK = (15, 23, 42)
TEXT_MUTED = (71, 85, 105)


def create_canvas(width: int, height: int, title: str, subtitle: str):
    img = Image.new("RGB", (width, height), BG_COLOR)
    draw = ImageDraw.Draw(img)

    # Subtle blueprint dot/line grid
    for x in range(0, width, 40):
        draw.line([(x, 0), (x, height)], fill=GRID_COLOR, width=1)
    for y in range(0, height, 40):
        draw.line([(0, y), (width, y)], fill=GRID_COLOR, width=1)

    # Outer border
    draw.rectangle([8, 8, width - 9, height - 9], outline=BORDER_FRAME, width=3)

    # Top Title Banner
    draw.rectangle([8, 8, width - 9, 86], fill=HEADER_BG)
    f_title = get_font(25, bold=True)
    f_sub = get_font(16, bold=False)
    draw.text((28, 18), title, font=f_title, fill=HEADER_TEXT)
    draw.text((28, 52), subtitle, font=f_sub, fill=(191, 219, 254))

    # Right badge in banner
    badge_text = "CHAONOTE (SOLFA) v1.9.4+26 • UML 2.5"
    f_badge = get_font(14, bold=True)
    bw = draw.textlength(badge_text, font=f_badge)
    draw.rounded_rectangle(
        [width - bw - 54, 26, width - 26, 64],
        radius=10,
        fill=(37, 99, 235),
        outline=(147, 197, 253),
        width=2,
    )
    draw.text((width - bw - 40, 36), badge_text, font=f_badge, fill=HEADER_TEXT)
    return img, draw


def draw_box(
    draw: ImageDraw.ImageDraw,
    box,
    title: str,
    lines=None,
    fill=BLUE_FILL,
    stroke=BLUE_STROKE,
    title_color=BLUE_DARK,
    radius: int = 12,
    header_fill=None,
    stereotype: str = None,
    title_size: int = 17,
    body_size: int = 14,
    center_title: bool = True,
):
    x1, y1, x2, y2 = box
    # Soft shadow
    draw.rounded_rectangle(
        [x1 + 4, y1 + 4, x2 + 4, y2 + 4],
        radius=radius,
        fill=(226, 232, 240),
    )
    draw.rounded_rectangle(
        [x1, y1, x2, y2],
        radius=radius,
        fill=fill,
        outline=stroke,
        width=2,
    )

    f_title = get_font(title_size, bold=True)
    f_stereo = get_font(body_size - 1, italic=True)
    f_body = get_font(body_size, bold=False)

    title_lines = title.split("\n")
    cur_y = y1 + 10
    if header_fill:
        hdr_h = (38 if not stereotype else 54) + (len(title_lines) - 1) * (title_size + 4)
        draw.rounded_rectangle(
            [x1, y1, x2, y1 + hdr_h],
            radius=radius,
            fill=header_fill,
            outline=stroke,
            width=2,
        )
        draw.rectangle([x1, y1 + hdr_h - radius, x2, y1 + hdr_h], fill=header_fill)
        draw.line([(x1, y1 + hdr_h), (x2, y1 + hdr_h)], fill=stroke, width=2)

    if stereotype:
        sw = draw.textlength(stereotype, font=f_stereo)
        sx = (x1 + x2 - sw) / 2 if center_title else x1 + 14
        draw.text(
            (sx, cur_y),
            stereotype,
            font=f_stereo,
            fill=(255, 255, 255) if header_fill else stroke,
        )
        cur_y += body_size + 3

    for t_line in title_lines:
        tw = draw.textlength(t_line, font=f_title)
        tx = (x1 + x2 - tw) / 2 if center_title else x1 + 14
        draw.text(
            (tx, cur_y),
            t_line,
            font=f_title,
            fill=(255, 255, 255) if header_fill else title_color,
        )
        cur_y += title_size + 5
    cur_y += 5

    if lines:
        if not header_fill:
            draw.line([(x1 + 10, cur_y - 4), (x2 - 10, cur_y - 4)], fill=stroke, width=1)
        cur_y += 4
        for line in lines:
            if line == "---":
                draw.line([(x1 + 4, cur_y + 3), (x2 - 4, cur_y + 3)], fill=stroke, width=1)
                cur_y += 9
                continue
            is_bold = line.startswith("* ")
            txt = line[2:] if is_bold else line
            font_use = get_font(body_size, bold=is_bold)
            draw.text((x1 + 14, cur_y), txt, font=font_use, fill=SLATE_DARK)
            cur_y += body_size + 6


def draw_ellipse_uc(
    draw: ImageDraw.ImageDraw,
    box,
    text: str,
    code: str = None,
    fill=BLUE_FILL,
    stroke=BLUE_STROKE,
    text_color=BLUE_DARK,
):
    x1, y1, x2, y2 = box
    draw.ellipse([x1 + 3, y1 + 3, x2 + 3, y2 + 3], fill=(226, 232, 240))
    draw.ellipse([x1, y1, x2, y2], fill=fill, outline=stroke, width=2)
    f_code = get_font(12, bold=True)
    f_txt = get_font(14, bold=True)
    cx = (x1 + x2) / 2
    cy = (y1 + y2) / 2
    lines = text.split("\n")
    total_h = len(lines) * 18 + (15 if code else 0)
    sy = cy - total_h / 2
    if code:
        cw = draw.textlength(code, font=f_code)
        draw.text((cx - cw / 2, sy), code, font=f_code, fill=stroke)
        sy += 16
    for l in lines:
        lw = draw.textlength(l, font=f_txt)
        draw.text((cx - lw / 2, sy), l, font=f_txt, fill=text_color)
        sy += 18


def draw_actor(draw: ImageDraw.ImageDraw, cx: int, cy: int, name: str, role: str = ""):
    # Head
    r = 18
    draw.ellipse([cx - r, cy - 55, cx + r, cy - 55 + 2 * r], fill=INDIGO_FILL, outline=INDIGO_STROKE, width=3)
    # Body
    draw.line([(cx, cy - 19), (cx, cy + 25)], fill=INDIGO_STROKE, width=3)
    # Arms
    draw.line([(cx - 26, cy - 4), (cx + 26, cy - 4)], fill=INDIGO_STROKE, width=3)
    # Legs
    draw.line([(cx, cy + 25), (cx - 22, cy + 58)], fill=INDIGO_STROKE, width=3)
    draw.line([(cx, cy + 25), (cx + 22, cy + 58)], fill=INDIGO_STROKE, width=3)

    f_name = get_font(16, bold=True)
    f_role = get_font(13, italic=True)
    nw = draw.textlength(name, font=f_name)
    draw.text((cx - nw / 2, cy + 66), name, font=f_name, fill=INDIGO_DARK)
    if role:
        rw = draw.textlength(role, font=f_role)
        draw.text((cx - rw / 2, cy + 87), role, font=f_role, fill=TEXT_MUTED)


def draw_arrow(
    draw: ImageDraw.ImageDraw,
    p1,
    p2,
    color=SLATE_STROKE,
    width: int = 2,
    label: str = None,
    dashed: bool = False,
    head_size: int = 10,
    bidirectional: bool = False,
):
    x1, y1 = p1
    x2, y2 = p2
    if dashed:
        dist = math.hypot(x2 - x1, y2 - y1)
        steps = max(int(dist // 10), 1)
        for i in range(0, steps, 2):
            sx = x1 + (x2 - x1) * (i / steps)
            sy = y1 + (y2 - y1) * (i / steps)
            ex = x1 + (x2 - x1) * (min(i + 1, steps) / steps)
            ey = y1 + (y2 - y1) * (min(i + 1, steps) / steps)
            draw.line([(sx, sy), (ex, ey)], fill=color, width=width)
    else:
        draw.line([(x1, y1), (x2, y2)], fill=color, width=width)

    angle = math.atan2(y2 - y1, x2 - x1)
    a1 = angle + math.pi * 0.82
    a2 = angle - math.pi * 0.82
    p_a1 = (x2 + head_size * math.cos(a1), y2 + head_size * math.sin(a1))
    p_a2 = (x2 + head_size * math.cos(a2), y2 + head_size * math.sin(a2))
    draw.polygon([(x2, y2), p_a1, p_a2], fill=color)

    if bidirectional:
        b1 = angle + math.pi - math.pi * 0.82
        b2 = angle + math.pi + math.pi * 0.82
        p_b1 = (x1 - head_size * math.cos(a1), y1 - head_size * math.sin(a1))
        p_b2 = (x1 - head_size * math.cos(a2), y1 - head_size * math.sin(a2))
        draw.polygon([(x1, y1), p_b1, p_b2], fill=color)

    if label:
        f_lbl = get_font(13, bold=True)
        lw = draw.textlength(label, font=f_lbl)
        mx = (x1 + x2) / 2
        my = (y1 + y2) / 2
        draw.rounded_rectangle(
            [mx - lw / 2 - 6, my - 12, mx + lw / 2 + 6, my + 12],
            radius=6,
            fill=(255, 255, 255),
            outline=color,
            width=1,
        )
        draw.text((mx - lw / 2, my - 8), label, font=f_lbl, fill=color)


# ==============================================================================
# 1. UML 01: USE CASE DIAGRAM
# ==============================================================================
def build_uml_01_use_case():
    img, draw = create_canvas(
        1900,
        1220,
        "HÌNH 1: SƠ ĐỒ USE CASE TỔNG QUÁT & PHÂN RÃ HỆ THỐNG (USE CASE DIAGRAM)",
        "Hệ thống ChaoNote (Solfa v1.9.4+26) • 5 Phân hệ Nghiệp vụ & 4 Tác nhân (Actors)",
    )

    # System Boundary Box
    draw.rounded_rectangle(
        [330, 115, 1550, 1180],
        radius=18,
        fill=(250, 252, 255),
        outline=HEADER_BG,
        width=3,
    )
    f_sys = get_font(19, bold=True)
    draw.text(
        (355, 128),
        "<<System Boundary>> ỨNG DỤNG DI ĐỘNG CHAONOTE (SOLFA OFFLINE-FIRST)",
        font=f_sys,
        fill=HEADER_BG,
    )

    # Actors
    draw_actor(draw, 145, 360, "Người học nhạc", "<<Primary Actor>>")
    draw_actor(draw, 145, 860, "Người chơi thứ 2", "<<Local 1v1 Split-Screen>>")
    draw_actor(draw, 1735, 340, "DSP Audio & SQLite", "<<Local Engine>>")
    draw_actor(draw, 1735, 840, "Rewarded Ad & Guard", "<<Ad / SHA-256 Guard>>")

    # Subsystem 1: Luyện tập 11 Chủ đề
    draw.rounded_rectangle([360, 170, 935, 650], radius=14, fill=BLUE_FILL, outline=BLUE_STROKE, width=2)
    draw.text((380, 182), "1. Phân hệ Luyện tập Cảm âm, Khuông nhạc & Guitar (11 Chủ đề)", font=get_font(15, bold=True), fill=BLUE_DARK)

    ucs_sub1 = [
        ((385, 220, 635, 300), "UC-01", "Luyện nhanh & Tiếp tục\nbài đang học (60s/15p/1h)"),
        ((660, 220, 910, 300), "UC-02", "Luyện 7 Chủ đề Cảm âm\n& Đọc Khuông Sol/Fa"),
        ((385, 325, 635, 405), "UC-03", "Luyện 4 Chủ đề Guitar\n(81 câu Hợp âm mở/chặn)"),
        ((660, 325, 910, 405), "UC-04", "Trả lời bằng Phím Piano\nC3-C5 & Cần đàn 6 dây"),
        ((385, 430, 635, 510), "UC-05", "Ôn tập câu sai\n(Đúng 2 lần liên tiếp)"),
        ((660, 430, 910, 510), "UC-06", "Xem Thống kê Tiến trình\n& Thẻ Vinh Danh Share"),
        ((490, 535, 795, 620), "UC-07", "Sinh câu hỏi Hybrid\n(Anti-Repeat 65% Window)"),
    ]
    for box, code, txt in ucs_sub1:
        draw_ellipse_uc(draw, box, txt, code, fill=(255, 255, 255), stroke=BLUE_STROKE, text_color=BLUE_DARK)

    # Subsystem 2: Studio Nhạc cụ & Máy đếm nhịp
    draw.rounded_rectangle([965, 170, 1520, 650], radius=14, fill=EMERALD_FILL, outline=EMERALD_STROKE, width=2)
    draw.text((985, 182), "2. Phân hệ Studio Nhạc cụ & Máy đếm nhịp cơ học (<10ms)", font=get_font(15, bold=True), fill=EMERALD_DARK)

    ucs_sub2 = [
        ((990, 220, 1235, 300), "UC-08", "Khám phá Đàn Piano\nC3-C5 & Khuông nhạc"),
        ((1255, 220, 1500, 300), "UC-09", "Chép nhạc Giai điệu\n(Melodic Dictation)"),
        ((990, 325, 1235, 405), "UC-10", "Guitar Studio: 44 Hợp âm\n& So dây 6 dây chuẩn Hz"),
        ((1255, 325, 1500, 405), "UC-11", "Vòng Hòa âm, Backing\nTrack Jam & Scale VIP"),
        ((990, 430, 1235, 510), "UC-12", "Lộ trình 12 Bài Luyện\nNgón Guitar (36 Sao)"),
        ((1255, 430, 1500, 510), "UC-13", "Máy đếm nhịp cơ học\n(30-300 BPM, Tap Tempo)"),
        ((1095, 535, 1395, 620), "UC-14", "Chia phách Subdivision\n& Lưu Preset Nhịp"),
    ]
    for box, code, txt in ucs_sub2:
        draw_ellipse_uc(draw, box, txt, code, fill=(255, 255, 255), stroke=EMERALD_STROKE, text_color=EMERALD_DARK)

    # Subsystem 3: Đấu Trường Âm Nhạc 1v1
    draw.rounded_rectangle([360, 680, 935, 1150], radius=14, fill=PURPLE_FILL, outline=PURPLE_STROKE, width=2)
    draw.text((380, 692), "3. Phân hệ Đấu Trường Âm Nhạc 1v1 (Battle Arena)", font=get_font(15, bold=True), fill=PURPLE_DARK)

    ucs_sub3 = [
        ((385, 735, 635, 820), "UC-15", "Đấu Hạng 1v1\n(Smart Matchmaking)"),
        ((660, 735, 910, 820), "UC-16", "Đấu Máy AI 4 Cấp độ\n(Tập Sự -> Huyền Thoại)"),
        ((385, 850, 635, 935), "UC-17", "Đấu 2 Người 1 Máy\n(Local Split-Screen 1v1)"),
        ((660, 850, 910, 935), "UC-18", "Tính sát thương 100 HP,\nBạo kích Combo & K.O."),
        ((485, 965, 805, 1055), "UC-19", "Thăng hạng 6 Bậc Sao\n& Lịch sử Đấu Trường"),
    ]
    for box, code, txt in ucs_sub3:
        draw_ellipse_uc(draw, box, txt, code, fill=(255, 255, 255), stroke=PURPLE_STROKE, text_color=PURPLE_DARK)

    # Subsystem 4: Kinh tế Gem, Bảo mật & Cài đặt Đa Quốc Gia
    draw.rounded_rectangle([965, 680, 1520, 1150], radius=14, fill=AMBER_FILL, outline=AMBER_STROKE, width=2)
    draw.text((985, 692), "4. Phân hệ Kinh tế Gem, Nhiệm vụ & Cài đặt (EU 2018/302)", font=get_font(15, bold=True), fill=AMBER_DARK)

    ucs_sub4 = [
        ((990, 735, 1235, 820), "UC-20", "Làm 3 Nhiệm vụ ngày\n& Mục tiêu (+120 Gem)"),
        ((1255, 735, 1500, 820), "UC-21", "Xem Video 15s nhận\n+100 Gem & +1 Lượt Đấu"),
        ((990, 850, 1235, 935), "UC-22", "Đổi Gem mở Phiên 1h/\nTự do/Scale/Lượt Đấu"),
        ((1255, 850, 1500, 935), "UC-23", "Cài đặt Sáng/Tối, Âm\nlượng & 174+ Quốc gia"),
        ((1085, 965, 1405, 1055), "UC-24", "Kiểm định Chữ ký SHA-256\n& Chống lùi giờ thiết bị"),
    ]
    for box, code, txt in ucs_sub4:
        draw_ellipse_uc(draw, box, txt, code, fill=(255, 255, 255), stroke=AMBER_STROKE, text_color=AMBER_DARK)

    # Actor associations
    for target_y in [260, 365, 470, 775, 890]:
        draw_arrow(draw, (220, 360), (385, target_y), color=INDIGO_STROKE, width=2)
    draw_arrow(draw, (220, 860), (385, 892), color=PURPLE_STROKE, width=2, label="Chạm 1/2 màn hình")
    draw_arrow(draw, (640, 405), (640, 535), color=BLUE_STROKE, dashed=True, label="<<include>>")
    draw_arrow(draw, (785, 820), (785, 850), color=PURPLE_STROKE, dashed=True, label="<<include>>")
    draw_arrow(draw, (1245, 935), (1245, 965), color=AMBER_STROKE, dashed=True, label="<<include>>")

    # Right actors links
    for ty in [260, 365, 470, 575]:
        draw_arrow(draw, (1500, ty), (1665, 340), color=EMERALD_STROKE, width=2)
    for ty in [775, 890, 1010]:
        draw_arrow(draw, (1500, ty), (1665, 840), color=AMBER_STROKE, width=2)

    out_path = UML_DIR / "uml_01_use_case.png"
    img.save(out_path, "PNG")
    return out_path


# ==============================================================================
# 2. UML 02: LAYERED & COMPONENT ARCHITECTURE DIAGRAM
# ==============================================================================
def build_uml_02_architecture():
    img, draw = create_canvas(
        1900,
        1180,
        "HÌNH 2: KIẾN TRÚC PHÂN TẦNG & THÀNH PHẦN FLUTTER (COMPONENT & LAYERED ARCHITECTURE)",
        "Mô hình Clean Feature-First + Riverpod State Management + Offline SQLite + 44.1kHz PCM DSP Engine",
    )

    # Layer 1: Presentation Layer
    draw.rounded_rectangle([50, 115, 1850, 335], radius=16, fill=BLUE_FILL, outline=BLUE_STROKE, width=3)
    draw.text((75, 127), "TẦNG 1: PRESENTATION LAYER (GIAO DIỆN NGƯỜI DÙNG & DESIGN SYSTEM - MATERIAL 3 LIGHT/DARK)", font=get_font(17, bold=True), fill=BLUE_DARK)

    pres_boxes = [
        ((75, 165, 350, 315), "MainShell & HomeScreen", ["* 4-Tab Nav + Diamond CTA", "* Header [💎 Gem] [🔥 Streak]", "* Hero Card & 3 Daily Quests"]),
        ((370, 165, 655, 315), "Topics & QuizScreen", ["* 11 Chủ đề (7 Cảm âm + 4 Guitar)", "* Khuông Sol/Fa & Phím C3-C5", "* Cần đàn 6 dây + Badge Chặn 1"]),
        ((675, 165, 965, 315), "Piano & Guitar Studio", ["* Piano C3-C5 + Chép nhạc", "* 44 Hợp âm + So dây Hz Loop", "* 12 Bài luyện ngón & Jam Track"]),
        ((985, 165, 1270, 315), "BattleScreen (1v1 Arena)", ["* Ghép Rank / Bot AI / 2 Người", "* Thanh máu 100 HP & Sét đánh", "* 6 Bậc Rank Sao & Lịch sử đấu"]),
        ((1290, 165, 1555, 315), "Metronome & Progress", ["* Máy đếm nhịp 30-300 BPM", "* Tap Tempo & Chia phách 1x-4x", "* Biểu đồ Tiến trình & Share Card"]),
        ((1575, 165, 1825, 315), "Settings & Gem Station", ["* Đồng bộ Sáng/Tối & 174+ Vùng", "* Trạm Đổi Gem (200/350/500/800)", "* Trình phát Video QC 15 giây"]),
    ]
    for b, t, lines in pres_boxes:
        draw_box(draw, b, t, lines, fill=(255, 255, 255), stroke=BLUE_STROKE, title_color=BLUE_DARK, header_fill=BLUE_STROKE, title_size=15, body_size=13)

    # Layer 2: Application / State Management Layer (Riverpod)
    draw.rounded_rectangle([50, 380, 1850, 610], radius=16, fill=PURPLE_FILL, outline=PURPLE_STROKE, width=3)
    draw.text((75, 392), "TẦNG 2: APPLICATION LAYER (QUẢN LÝ TRẠNG THÁI FLUTTER RIVERPOD STATE NOTIFIERS)", font=get_font(17, bold=True), fill=PURPLE_DARK)

    app_boxes = [
        ((75, 430, 415, 590), "PracticeSessionNotifier", ["* Quản lý phiên 60s / 15p / 1h / Tự do", "* Chống bấm trùng (isSubmittingAnswer)", "* Tự động nạp tiếp câu hỏi (Continuous)", "* Ghi nhận Combo & tính điểm phiên"], "<<StateNotifier>>"),
        ((435, 430, 775, 590), "BattleNotifier", ["* Quản lý vòng đời BattlePhase", "* Tính sát thương HP, Combo & First Blood", "* Lập lịch Bot AI 4 cấp độ phản xạ", "* Quản lý 5 lượt miễn phí/ngày & Sao"], "<<StateNotifier>>"),
        ((795, 430, 1135, 590), "MetronomeNotifier", ["* Bộ đếm Stopwatch Microsecond (<10ms)", "* Chu kỳ Đèn phách Nhấn/Thường/Tắt", "* Đồng bộ 2 chiều Âm sắc & Wakelock", "* Tăng tốc tự động (Auto Speed-Up)"], "<<StateNotifier>>"),
        ((1155, 430, 1495, 590), "RewardedAdNotifier", ["* Quản lý Ví Gem (prestigePoints)", "* Theo dõi 3 Nhiệm vụ ngày & Mục tiêu", "* Xử lý đổi Gem -> Phiên 1h/Tự do/Lượt", "* Cấp danh hiệu Người đồng hành"], "<<StateNotifier>>"),
        ((1515, 430, 1825, 590), "AppSettingsNotifier", ["* Đồng bộ Theme Sáng/Tối/Hệ thống", "* Lưu Thời gian mặc định & Mục tiêu", "* Tự nhận diện 174+ Quốc gia & Ngôn ngữ", "* Quản lý Mở khóa cấp độ & Âm lượng"], "<<StateNotifier>>"),
    ]
    for b, t, lines, st in app_boxes:
        draw_box(draw, b, t, lines, fill=(255, 255, 255), stroke=PURPLE_STROKE, title_color=PURPLE_DARK, header_fill=PURPLE_STROKE, stereotype=st, title_size=15, body_size=13)

    # Layer 3: Domain & Core Logic Layer
    draw.rounded_rectangle([50, 655, 1850, 885], radius=16, fill=EMERALD_FILL, outline=EMERALD_STROKE, width=3)
    draw.text((75, 667), "TẦNG 3: DOMAIN & CORE ENGINE LAYER (THUẬT TOÁN NGHIỆP VỤ, BẢO MẬT & ĐA QUỐC GIA)", font=get_font(17, bold=True), fill=EMERALD_DARK)

    dom_boxes = [
        ((75, 705, 500, 865), "HybridQuestionGenerator", ["* Cửa sổ chống lặp 65% tổng kho câu hỏi", "* Trộn ngẫu nhiên đáp án nhiễu (Dynamic Distractors)", "* Cân bằng vị trí A/B/C/D không lệch xác suất", "* Sinh động câu hỏi Đọc Khuông Sol/Fa & Cần đàn"], "<<Domain Service>>"),
        ((520, 705, 945, 865), "SolfaIntegrityGuard", ["* Ký số SHA-256 Salted Checksum cho Ví Gem & Sao", "* Monotonic Clock Guard chống chỉnh lùi giờ hệ thống", "* Tự động khôi phục số dư an toàn khi phát hiện giả mạo", "* Bảo vệ toàn vẹn nhiệm vụ hàng ngày 100% Offline"], "<<Security Guard>>"),
        ((965, 705, 1390, 865), "TapTempoCalculator & NoteFormatter", ["* Lọc nhiễu ngoại lai (Outlier Filter) khi gõ Tap Tempo", "* Chuyển đổi BPM <-> Chu kỳ ms/phách chính xác", "* Chuẩn hóa ký hiệu Song ngữ Đô-Rê-Mi (C-D-E)", "* Phân tích tần số chuẩn Hz cho 6 dây Guitar"], "<<Music DSP Math>>"),
        ((1410, 705, 1825, 865), "AppLocale & DomainModels", ["* Tự động nhận diện 174+ Quốc gia (EU 2018/302)", "* Chuyển đổi tức thời Tiếng Việt <-> Tiếng Anh", "* 12+ Lớp thực thể bất biến (Immutable Models)", "* Quy tắc Ôn tập: Đúng 2 lần liên tiếp mới hoàn thành"], "<<Core Domain>>"),
    ]
    for b, t, lines, st in dom_boxes:
        draw_box(draw, b, t, lines, fill=(255, 255, 255), stroke=EMERALD_STROKE, title_color=EMERALD_DARK, header_fill=EMERALD_STROKE, stereotype=st, title_size=15, body_size=13)

    # Layer 4: Data & Infrastructure Layer
    draw.rounded_rectangle([50, 930, 1850, 1145], radius=16, fill=AMBER_FILL, outline=AMBER_STROKE, width=3)
    draw.text((75, 942), "TẦNG 4: DATA & INFRASTRUCTURE LAYER (LƯU TRỮ CỤC BỘ SQLITE, SHAREDPREFERENCES & KHO ÂM THANH WAV)", font=get_font(17, bold=True), fill=AMBER_DARK)

    data_boxes = [
        ((75, 980, 640, 1125), "AppDatabase (SQLite / sqflite_common_ffi)", ["* 9 Bảng chuẩn hóa: topics, levels, questions, question_options,", "  practice_sessions, practice_answers, review_items, metronome_presets, app_settings", "* Bảo toàn 100% lịch sử người dùng khi nâng cấp seed_content.json"]),
        ((665, 980, 1230, 1125), "AudioService & AssetValidator (Low-Latency PCM)", ["* 283+ File âm thanh 44.1kHz 16-bit PCM WAV tổng hợp DSP Zero-Click", "* Grand Piano, Guitar Acoustic, Guitar Electric, Backing Track Jam & Click", "* Tự động dừng âm thanh khi ẩn ứng dụng (WidgetsBindingObserver)"]),
        ((1255, 980, 1825, 1125), "SharedPreferences & Local Security Store", ["* Lưu Ví Gem, Sao Đấu Trường, Lượt đấu ngày & Tiến độ 12 Bài Luyện Ngón", "* Lưu trạng thái Mở khóa Scale VIP 12 ngăn & Chuỗi nhiệm vụ hàng ngày", "* Đính kèm chữ ký băm (_sig_v2) và mốc thời gian đơn điệu (_monotonic_ts)"]),
    ]
    for b, t, lines in data_boxes:
        draw_box(draw, b, t, lines, fill=(255, 255, 255), stroke=AMBER_STROKE, title_color=AMBER_DARK, header_fill=AMBER_STROKE, title_size=15, body_size=13)

    # Vertical inter-layer arrows
    for x in [245, 605, 965, 1325, 1670]:
        draw_arrow(draw, (x, 335), (x, 380), color=INDIGO_STROKE, width=3)
        draw_arrow(draw, (x, 610), (x, 655), color=PURPLE_STROKE, width=3)
        draw_arrow(draw, (x, 885), (x, 930), color=EMERALD_STROKE, width=3)

    out_path = UML_DIR / "uml_02_architecture.png"
    img.save(out_path, "PNG")
    return out_path


# ==============================================================================
# 3. UML 03: UI NAVIGATION & SCREEN FLOW DIAGRAM
# ==============================================================================
def build_uml_03_navigation():
    img, draw = create_canvas(
        1900,
        1120,
        "HÌNH 3: SƠ ĐỒ LUỒNG ĐIỀU HƯỚNG MÀN HÌNH (GOROUTER UI NAVIGATION FLOW)",
        "Cấu trúc StatefulShellRoute 4 Tab + Nút Diamond CTA Đấu Trường + Các Màn Hình Phụ & Studio Bottom Sheets",
    )

    # Splash Screen
    draw_box(
        draw,
        (70, 480, 320, 640),
        "UI-01: SplashScreen\n(path: '/')",
        [
            "* Khởi tạo SQLite DB",
            "* Nạp seed_content.json",
            "* Nạp AppSettingsState",
            "* Tự chuyển -> /home",
        ],
        fill=INDIGO_FILL,
        stroke=INDIGO_STROKE,
        header_fill=INDIGO_STROKE,
    )

    # MainShell container
    draw.rounded_rectangle([390, 140, 1160, 1060], radius=18, fill=(248, 250, 252), outline=HEADER_BG, width=3)
    draw.text((415, 155), "MainShell (StatefulShellRoute.indexedStack) • Header [💎] [🔥] [⚙️] + Diamond Bottom Nav", font=get_font(16, bold=True), fill=HEADER_BG)

    tabs = [
        ((430, 210, 770, 440), "Tab 1: Trang chủ (/home)", ["* Lời chào & Chuỗi ngày học", "* Thẻ Hero: Tiếp tục bài đang học", "* 4 Tiện ích: Piano / Guitar / Ôn sai / Đấu", "* Mục tiêu ngày (+20G) & 3 Nhiệm vụ (+100G)"], BLUE_FILL, BLUE_STROKE),
        ((800, 210, 1130, 440), "Tab 2: Phòng luyện tập (/topics)", ["* 7 Chủ đề Cảm âm & Khuông nhạc", "* 4 Chủ đề Guitar (Nốt/Hợp âm/Scale/Tab)", "* Modal chọn Cấp độ & Thời gian", "* Nút mở nhanh Piano & Guitar Studio"], BLUE_FILL, BLUE_STROKE),
        ((430, 480, 770, 700), "Tab 3: Công cụ (/metronome)", ["* Máy đếm nhịp cơ học 30-300 BPM", "* 4 Đèn phách tương tác (Nhấn/Thường/Tắt)", "* Tap Tempo, Nhịp 1/4..6/8, Chia phách 1x..4x", "* 4 Âm sắc & Lưu Preset tốc độ"], EMERALD_FILL, EMERALD_STROKE),
        ((800, 480, 1130, 700), "Tab 4: Tiến trình (/progress)", ["* Thẻ tổng quan Câu đúng & Độ chính xác", "* Biểu đồ cột số câu luyện 7 ngày gần nhất", "* Độ thành thạo theo từng Chủ đề", "* Lịch sử các phiên luyện tập gần đây"], EMERALD_FILL, EMERALD_STROKE),
    ]
    for box, t, lines, f, s in tabs:
        draw_box(draw, box, t, lines, fill=(255, 255, 255), stroke=s, header_fill=s, title_size=15, body_size=13)

    # Center Diamond CTA inside MainShell
    draw_box(
        draw,
        (520, 745, 1040, 865),
        "Nút Diamond CTA Chính Giữa Thanh Điều Hướng",
        [
            "* Chạm từ bất kỳ Tab nào -> Tự động dừng Metronome & Mở Đấu Trường 1v1 (/battle)",
        ],
        fill=PURPLE_FILL,
        stroke=PURPLE_STROKE,
        header_fill=PURPLE_STROKE,
        title_size=15,
        body_size=13,
    )

    # Interactive Studios (Modal Bottom Sheets)
    draw_box(
        draw,
        (430, 895, 770, 1035),
        "Modal: Piano Studio C3-C5",
        [
            "* Đàn Piano 25 phím + Khuông nhạc",
            "* Chép nhạc Giai điệu (+30 Gem)",
        ],
        fill=AMBER_FILL,
        stroke=AMBER_STROKE,
        header_fill=AMBER_STROKE,
        title_size=15,
        body_size=13,
    )
    draw_box(
        draw,
        (800, 895, 1130, 1035),
        "Modal: Guitar Studio (Thùng/Điện)",
        [
            "* 44 Hợp âm, So dây Hz, Vòng hòa âm",
            "* Scale 12 ngăn, 12 Bài tập & Jam Track",
        ],
        fill=AMBER_FILL,
        stroke=AMBER_STROKE,
        header_fill=AMBER_STROKE,
        title_size=15,
        body_size=13,
    )

    # Root Navigator Full-Screen Routes on Right
    right_screens = [
        ((1260, 140, 1840, 275), "UI-04: Chi tiết Chủ đề (/topics/:topicId)", ["* Chọn Cấp độ 1..4 & Thời gian (60s / 15p / 1h 200G / Tự do 350G)", "* Xem hướng dẫn nhạc lý chi tiết trước khi vào bài"], BLUE_STROKE),
        ((1260, 300, 1840, 445), "UI-05/06: Phòng thi & Câu hỏi (/quiz)", ["* Phát âm thanh câu hỏi, Đếm ngược thời gian & Tính điểm liên tục", "* Trả lời trắc nghiệm A/B/C/D, Phím Piano hoặc Cần đàn Guitar 6 dây"]),
        ((1260, 470, 1840, 605), "UI-07: Kết quả Phiên & Thẻ Vinh Danh (/session-result)", ["* Tổng kết Điểm, Độ chính xác %, Chuỗi Combo & Tạo Thẻ Vinh Danh", "* Xem Video ngắn 15s nhận thưởng +100 Gem sau mỗi phiên học"]),
        ((1260, 630, 1840, 755), "UI-08: Ôn tập Câu sai (/review)", ["* Lọc câu sai theo từng chủ đề, nghe lại mẫu âm thanh chuẩn", "* Luyện tập chế độ Ôn sai (Đúng 2 lần liên tiếp -> Xóa khỏi danh sách)"]),
        ((1260, 780, 1840, 915), "UI-13: Đấu Trường Âm Nhạc 1v1 (/battle)", ["* Sảnh chờ Hạng Sao & Thanh năng lượng 5/5 lượt -> Ghép trận VS", "* Sàn đấu 100 HP (Ghép Rank / Bot AI 4 cấp / 2 Người 1 Máy Split-Screen)"]),
        ((1260, 940, 1840, 1065), "UI-11 & UI-12: Cài đặt (/settings) & Trạm Gem (/support-developer)", ["* Cài đặt Sáng/Tối, Ngôn ngữ 174+ Quốc gia, Âm lượng, Xóa lịch sử", "* Xem Video 15s (+100 Gem & +1 Lượt), Đổi gói +1/+3/+5 Lượt Đấu Trường"]),
    ]
    for item in right_screens:
        box, t, lines = item[0], item[1], item[2]
        draw_box(draw, box, t, lines, fill=(255, 255, 255), stroke=INDIGO_STROKE, header_fill=INDIGO_STROKE, title_size=15, body_size=13)

    # Arrows
    draw_arrow(draw, (320, 560), (390, 560), color=INDIGO_STROKE, width=3, label="context.go('/home')")
    draw_arrow(draw, (1130, 320), (1260, 210), color=BLUE_STROKE, width=2, label="Chọn chủ đề")
    draw_arrow(draw, (1130, 360), (1260, 370), color=BLUE_STROKE, width=2, label="Bắt đầu luyện")
    draw_arrow(draw, (1550, 275), (1550, 300), color=BLUE_STROKE, width=2)
    draw_arrow(draw, (1550, 445), (1550, 470), color=EMERALD_STROKE, width=2, label="Hoàn thành")
    draw_arrow(draw, (1040, 805), (1260, 845), color=PURPLE_STROKE, width=3, label="push('/battle')")
    draw_arrow(draw, (1160, 995), (1260, 995), color=AMBER_STROKE, width=2, label="[💎] / [⚙️]")

    out_path = UML_DIR / "uml_03_navigation.png"
    img.save(out_path, "PNG")
    return out_path


# ==============================================================================
# 4. UML 04: CLASS DIAGRAM
# ==============================================================================
def build_uml_04_class_diagram():
    img, draw = create_canvas(
        1900,
        1240,
        "HÌNH 4: SƠ ĐỒ LỚP CHI TIẾT (UML CLASS DIAGRAM - DOMAIN, NOTIFIERS & SERVICES)",
        "Cấu trúc các lớp Thực thể (Entities), Bộ điều khiển Trạng thái (Riverpod Notifiers) và Dịch vụ Hạ tầng",
    )

    classes = [
        # Top row: Domain Models
        (
            (45, 115, 445, 435),
            "TopicModel & LevelModel",
            "<<Domain Entity>>",
            BLUE_STROKE,
            [
                "+ id: String",
                "+ code: String",
                "+ name: String",
                "+ difficultyOrder: int",
                "+ passThreshold: double",
                "+ questionCount: int",
                "---",
                "+ fromMap(Map): TopicModel",
                "+ toMap(): Map<String, Object?>",
            ],
        ),
        (
            (485, 115, 925, 435),
            "QuestionModel & OptionModel",
            "<<Domain Entity>>",
            BLUE_STROKE,
            [
                "+ id: String",
                "+ topicId: String / levelId: String",
                "+ questionType: String",
                "+ promptText: String",
                "+ audioPath: String?",
                "+ correctAnswer: String",
                "+ explanationText: String",
                "+ options: List<QuestionOptionModel>",
                "---",
                "+ correctOption: QuestionOptionModel",
                "+ hasQuestionAudio: bool",
            ],
        ),
        (
            (965, 115, 1405, 435),
            "PracticeSession & AnswerModel",
            "<<Domain Entity>>",
            BLUE_STROKE,
            [
                "+ id: String (UUID v4)",
                "+ sessionType: String (quick|topic|review)",
                "+ totalQuestions: int",
                "+ correctAnswers: int / wrongAnswers: int",
                "+ score: int",
                "+ accuracyPercent: double",
                "+ durationSeconds: int",
                "+ isCompleted: bool",
                "---",
                "+ toMap(): Map<String, Object?>",
            ],
        ),
        (
            (1445, 115, 1855, 435),
            "ReviewItemModel & OverallStats",
            "<<Domain Entity>>",
            BLUE_STROKE,
            [
                "+ id: String",
                "+ questionId: String",
                "+ wrongCount: int",
                "+ consecutiveCorrectCount: int",
                "+ status: String (pending|mastered)",
                "+ currentStreakDays: int",
                "+ todayAnsweredCount: int",
                "---",
                "+ isDailyGoalReached: bool",
                "+ dailyGoalProgress: double",
            ],
        ),
        # Middle row: State Notifiers
        (
            (45, 485, 475, 845),
            "PracticeSessionNotifier",
            "<<StateNotifier<PracticeSessionState>>>",
            PURPLE_STROKE,
            [
                "- _db: AppDatabase",
                "- _audio: AudioService",
                "- _generator: HybridQuestionGenerator",
                "- _countdownTimer: Timer?",
                "---",
                "+ startSession(mode, topicId, levelId): Future<bool>",
                "+ playCurrentQuestionAudio(): Future<void>",
                "+ submitAnswer(QuestionOptionModel): Future<void>",
                "+ nextQuestion(): Future<bool>",
                "+ finishSessionNow(): Future<void>",
            ],
        ),
        (
            (505, 485, 935, 845),
            "BattleNotifier",
            "<<StateNotifier<BattleState>>>",
            PURPLE_STROKE,
            [
                "- _db: AppDatabase",
                "- _audio: AudioService",
                "- _botTimer: Timer?",
                "- _roundTimer: Timer?",
                "---",
                "+ startBattle(seed, roundCount): Future<bool>",
                "+ enterArenaNow(): Future<void>",
                "+ submitPlayer1Answer(opt): Future<void>",
                "+ submitPlayer2Answer(opt): Future<void>",
                "+ restoreTurnFromRewardedAd(turns): Future<void>",
            ],
        ),
        (
            (965, 485, 1395, 845),
            "MetronomeNotifier",
            "<<StateNotifier<MetronomeState>>>",
            PURPLE_STROKE,
            [
                "- _stopwatch: Stopwatch",
                "- _schedulerTimer: Timer?",
                "- _tapCalculator: TapTempoCalculator",
                "---",
                "+ setBpm(int newBpm): void",
                "+ setTimeSignature(num, den): void",
                "+ setSubdivision(int sub): void",
                "+ cycleBeatState(int beatIndex): void",
                "+ registerTap(): int?",
                "+ togglePlayPause(): Future<void>",
            ],
        ),
        (
            (1425, 485, 1855, 845),
            "RewardedAdNotifier & Settings",
            "<<StateNotifier<RewardedAdState>>>",
            PURPLE_STROKE,
            [
                "+ kOneHourPracticeGemCost: int = 200",
                "+ kUnlimitedPracticeGemCost: int = 350",
                "+ kGuitarProScaleGemCost: int = 300",
                "+ kSingleBattleTurnGemCost: int = 200",
                "---",
                "+ completeWatchingAd(watchedToEnd): Future<void>",
                "+ spendGemsForOneHourSession(): Future<bool>",
                "+ spendGemsForUnlimitedSession(): Future<bool>",
                "+ spendPrestigePointsForTurns(): Future<bool>",
                "+ claimDailyQuest(code): Future<int>",
            ],
        ),
        # Bottom row: Core Infrastructure & Domain Services
        (
            (45, 895, 475, 1200),
            "HybridQuestionGenerator",
            "<<Domain Service>>",
            EMERALD_STROKE,
            [
                "- _recentQuestionIdsByPool: Map<String, List>",
                "- _recentCorrectSlotByPool: Map<String, List>",
                "---",
                "+ buildSessionQuestions(pool, count): List<Question>",
                "- _materializeQuestion(raw, pool, rng): Question",
                "- _balanceOptionOrder(q, poolKey, rng): Question",
                "- _buildDynamicGuitarChordDistractors(): List",
            ],
        ),
        (
            (505, 895, 935, 1200),
            "AppDatabase (SQLite Engine)",
            "<<Repository / DAO>>",
            AMBER_STROKE,
            [
                "- _database: Database?",
                "---",
                "+ seedContent(): Future<void>",
                "+ getQuestionsForPractice(): Future<List>",
                "+ saveCompletedSession(): Future<void>",
                "+ recordReviewWrongAnswer(): Future<void>",
                "+ recordReviewCorrectAnswer(): Future<void>",
                "+ getOverallProgressStats(): Future<Stats>",
                "+ clearLearningHistory(): Future<void>",
            ],
        ),
        (
            (965, 895, 1395, 1200),
            "AudioService (44.1kHz DSP)",
            "<<Infrastructure Service>>",
            AMBER_STROKE,
            [
                "- _primaryPlayer: AudioPlayer?",
                "- _polyPool: List<AudioPlayer>",
                "- _lessonVolume: double",
                "---",
                "+ playAsset(String path): Future<bool>",
                "+ playPolyphonicNote(String path): Future<bool>",
                "+ playReferenceC4(): Future<bool>",
                "+ playFeedbackSfx(isCorrect): Future<void>",
                "+ stop(): Future<void>",
            ],
        ),
        (
            (1425, 895, 1855, 1200),
            "SolfaIntegrityGuard",
            "<<Security Utility>>",
            EMERALD_STROKE,
            [
                "- _kInternalSalt: String",
                "---",
                "+ computeSignature(scope, fields): String",
                "+ verifySignature(scope, fields, sig): bool",
                "+ checkAndAdvanceMonotonicClock(): bool",
                "+ fnv1a64Hex(String input): String",
            ],
        ),
    ]

    for box, title, stereo, stroke, lines in classes:
        draw_box(
            draw,
            box,
            title,
            lines,
            fill=(255, 255, 255),
            stroke=stroke,
            title_color=stroke,
            header_fill=stroke,
            stereotype=stereo,
            title_size=16,
            body_size=13,
            center_title=False,
        )

    # Relationships
    draw_arrow(draw, (445, 275), (485, 275), color=BLUE_STROKE, width=2, label="1..*")
    draw_arrow(draw, (260, 485), (260, 435), color=PURPLE_STROKE, width=2, label="uses")
    draw_arrow(draw, (700, 485), (700, 435), color=PURPLE_STROKE, width=2, label="uses")
    draw_arrow(draw, (260, 845), (260, 895), color=EMERALD_STROKE, width=2, label="delegates")
    draw_arrow(draw, (720, 845), (720, 895), color=AMBER_STROKE, width=2, label="persists")
    draw_arrow(draw, (1180, 845), (1180, 895), color=AMBER_STROKE, width=2, label="triggers")
    draw_arrow(draw, (1640, 845), (1640, 895), color=EMERALD_STROKE, width=2, label="verifies")

    out_path = UML_DIR / "uml_04_class_diagram.png"
    img.save(out_path, "PNG")
    return out_path


# ==============================================================================
# 5. UML 05: ENTITY-RELATIONSHIP DIAGRAM (ERD)
# ==============================================================================
def build_uml_05_erd():
    img, draw = create_canvas(
        1900,
        1200,
        "HÌNH 5: SƠ ĐỒ THỰC THỂ LIÊN KẾT CƠ SỞ DỮ LIỆU CỤC BỘ (SQLITE ERD & SECURE KV STORE)",
        "9 Bảng Quan hệ SQLite (solfa_offline.db) + Kho Khóa Bảo mật SharedPreferences có Chữ ký SHA-256",
    )

    tables = [
        (
            (60, 130, 470, 420),
            "topics (Chủ đề học tập)",
            BLUE_STROKE,
            [
                "* PK  id : TEXT",
                "  UQ  code : TEXT",
                "      name : TEXT",
                "      description : TEXT",
                "      icon_name : TEXT",
                "      display_order : INTEGER",
                "      is_enabled : INTEGER (0|1)",
            ],
        ),
        (
            (540, 130, 960, 440),
            "levels (35 Cấp độ khó)",
            BLUE_STROKE,
            [
                "* PK  id : TEXT",
                "* FK  topic_id : TEXT -> topics.id",
                "      code : TEXT (basic|inter|adv|master)",
                "      name : TEXT",
                "      difficulty_order : INTEGER (1..4)",
                "      pass_threshold : REAL (0.70)",
                "      question_count : INTEGER",
                "      unlock_rule : TEXT",
            ],
        ),
        (
            (1030, 130, 1450, 460),
            "questions (Kho câu hỏi & Hợp âm)",
            BLUE_STROKE,
            [
                "* PK  id : TEXT",
                "* FK  topic_id : TEXT -> topics.id",
                "* FK  level_id : TEXT -> levels.id",
                "      question_type : TEXT",
                "      prompt_text : TEXT",
                "      audio_path : TEXT (WAV 44.1kHz)",
                "      correct_answer : TEXT",
                "      explanation_text : TEXT",
                "      difficulty : INTEGER",
            ],
        ),
        (
            (1510, 130, 1850, 420),
            "question_options (Đáp án)",
            BLUE_STROKE,
            [
                "* PK  id : TEXT",
                "* FK  question_id : TEXT",
                "      label : TEXT (A|B|C|D)",
                "      content : TEXT",
                "      option_value : TEXT",
                "      is_correct : INTEGER (0|1)",
                "      display_order : INTEGER",
            ],
        ),
        (
            (60, 520, 490, 850),
            "practice_sessions (Phiên học)",
            EMERALD_STROKE,
            [
                "* PK  id : TEXT (UUID v4)",
                "      session_type : TEXT (quick|topic|review)",
                "* FK  topic_id : TEXT?",
                "* FK  level_id : TEXT?",
                "      total_questions : INTEGER",
                "      correct_answers : INTEGER",
                "      wrong_answers : INTEGER",
                "      score : INTEGER",
                "      accuracy_percent : REAL",
                "      duration_seconds : INTEGER",
                "      started_at / completed_at : TEXT",
            ],
        ),
        (
            (555, 520, 975, 830),
            "practice_answers (Chi tiết trả lời)",
            EMERALD_STROKE,
            [
                "* PK  id : TEXT (UUID v4)",
                "* FK  session_id : TEXT -> practice_sessions",
                "* FK  question_id : TEXT -> questions.id",
                "      selected_answer : TEXT",
                "      correct_answer : TEXT",
                "      is_correct : INTEGER (0|1)",
                "      response_time_ms : INTEGER",
                "      answered_at : TEXT (ISO-8601)",
            ],
        ),
        (
            (1035, 520, 1455, 830),
            "review_items (Sổ tay Ôn câu sai)",
            ROSE_STROKE,
            [
                "* PK  id : TEXT",
                "* FK  question_id : TEXT (UNIQUE)",
                "      wrong_count : INTEGER",
                "      consecutive_correct_count : INTEGER",
                "      last_wrong_at : TEXT",
                "      last_reviewed_at : TEXT?",
                "      status : TEXT ('pending'|'mastered')",
                "  -- Quy tắc: consecutive_correct >= 2 -> mastered",
            ],
        ),
        (
            (60, 910, 490, 1155),
            "metronome_presets (Mẫu nhịp)",
            AMBER_STROKE,
            [
                "* PK  id : TEXT",
                "      name : TEXT",
                "      bpm : INTEGER (30..300)",
                "      time_signature_numerator : INTEGER",
                "      time_signature_denominator : INTEGER",
                "      sound_type : TEXT (tempo|click|bell)",
                "      accent_first_beat : INTEGER (0|1)",
            ],
        ),
        (
            (555, 910, 975, 1155),
            "app_settings (Cấu hình 2 chiều)",
            AMBER_STROKE,
            [
                "* PK  setting_key : TEXT",
                "      setting_value : TEXT",
                "      updated_at : TEXT",
                "  -- Keys: theme_mode, default_practice_duration,",
                "     daily_goal_target, default_metronome_sound,",
                "     language_mode, country_code_override, ...",
            ],
        ),
        (
            (1035, 890, 1850, 1155),
            "SharedPreferences + SolfaIntegrityGuard (Ví Gem, Sao & Luyện Ngón)",
            PURPLE_STROKE,
            [
                "* KEY  solfa_rewarded_ad_total_points_v1 : INT (Tổng Gem tích lũy)",
                "* KEY  solfa_rewarded_ad_spent_points_v1 : INT (Tổng Gem đã chi tiêu)",
                "* KEY  solfa_daily_quests_date_v1 / claimed_v1 : STRING (Nhiệm vụ hàng ngày +100 Gem)",
                "* KEY  solfa_battle_total_stars_v1 / daily_used_v1 : INT (Sao Rank & 5 Lượt đấu/ngày)",
                "* KEY  solfa_guitar_pro_unlocked_v1 / workout_stars_v1 : BOOL/JSON (Scale VIP & 36 Sao)",
                "* SIG  solfa_integrity_sig_v2_* : TEXT (Chữ ký SHA-256 Salted + Monotonic Clock Guard)",
            ],
        ),
    ]

    for box, title, stroke, lines in tables:
        draw_box(
            draw,
            box,
            title,
            lines,
            fill=(255, 255, 255),
            stroke=stroke,
            title_color=stroke,
            header_fill=stroke,
            stereotype="<<Table / Store>>",
            title_size=15,
            body_size=13,
            center_title=False,
        )

    # Crow's foot / FK connectors
    draw_arrow(draw, (470, 270), (540, 270), color=BLUE_STROKE, width=2, label="1 : N")
    draw_arrow(draw, (960, 270), (1030, 270), color=BLUE_STROKE, width=2, label="1 : N")
    draw_arrow(draw, (1450, 270), (1510, 270), color=BLUE_STROKE, width=2, label="1 : 4")
    draw_arrow(draw, (490, 670), (555, 670), color=EMERALD_STROKE, width=2, label="1 : N")
    draw_arrow(draw, (1240, 460), (765, 520), color=EMERALD_STROKE, width=2, label="1 : N")
    draw_arrow(draw, (1240, 460), (1240, 520), color=ROSE_STROKE, width=2, label="1 : 0..1")

    out_path = UML_DIR / "uml_05_erd.png"
    img.save(out_path, "PNG")
    return out_path


# ==============================================================================
# HELPER FOR SEQUENCE DIAGRAMS
# ==============================================================================
def draw_sequence_diagram(
    filename: str,
    title: str,
    subtitle: str,
    participants: list,
    messages: list,
    blocks: list = None,
):
    img, draw = create_canvas(1900, 1180, title, subtitle)
    n = len(participants)
    margin_x = 125
    usable_w = 1900 - 2 * margin_x
    step_x = usable_w / max(n - 1, 1)

    xs = [int(margin_x + i * step_x) for i in range(n)]
    top_y = 120
    bot_y = 1120

    # Lifelines
    for i, (pname, pstereo, pcolor) in enumerate(participants):
        cx = xs[i]
        draw.line([(cx, top_y + 70), (cx, bot_y)], fill=SLATE_STROKE, width=2)
        draw_box(
            draw,
            (cx - 115, top_y, cx + 115, top_y + 72),
            pname,
            fill=(255, 255, 255),
            stroke=pcolor,
            header_fill=pcolor,
            stereotype=pstereo,
            title_size=14,
            body_size=12,
        )
        draw_box(
            draw,
            (cx - 105, bot_y, cx + 105, bot_y + 42),
            pname,
            fill=SLATE_FILL,
            stroke=pcolor,
            title_color=pcolor,
            title_size=13,
            body_size=11,
        )

    # Combined fragments (alt / loop / opt)
    if blocks:
        for b_type, b_label, x_idx1, x_idx2, y1, y2, b_color in blocks:
            bx1 = xs[x_idx1] - 70
            bx2 = xs[x_idx2] + 70
            draw.rounded_rectangle([bx1, y1, bx2, y2], radius=8, outline=b_color, width=2)
            draw.rectangle([bx1, y1, bx1 + 85, y1 + 24], fill=b_color)
            draw.text((bx1 + 10, y1 + 4), b_type.upper(), font=get_font(12, bold=True), fill=(255, 255, 255))
            draw.text((bx1 + 95, y1 + 4), f"[{b_label}]", font=get_font(13, bold=True), fill=b_color)

    # Messages
    start_y = 225
    gap_y = int((bot_y - start_y - 30) / max(len(messages), 1))
    for idx, (src, dst, text, is_return, mcolor) in enumerate(messages):
        y = start_y + idx * gap_y
        x1 = xs[src]
        x2 = xs[dst]
        # Activation bar dots
        draw.rectangle([x1 - 5, y - 10, x1 + 5, y + 10], fill=mcolor)
        draw.rectangle([x2 - 5, y - 10, x2 + 5, y + 10], fill=mcolor)

        if src == dst:
            # Self-call loop
            draw.line([(x1 + 5, y - 6), (x1 + 55, y - 6), (x1 + 55, y + 16), (x1 + 5, y + 16)], fill=mcolor, width=2)
            draw.polygon([(x1 + 5, y + 16), (x1 + 14, y + 11), (x1 + 14, y + 21)], fill=mcolor)
            f_m = get_font(13, bold=True)
            tw = draw.textlength(text, font=f_m)
            draw.rounded_rectangle([x1 + 62, y - 8, x1 + 74 + tw, y + 16], radius=5, fill=(255, 255, 255), outline=mcolor)
            draw.text((x1 + 68, y - 5), text, font=f_m, fill=mcolor)
        else:
            draw_arrow(
                draw,
                (x1, y),
                (x2, y),
                color=mcolor,
                width=2,
                label=f"{idx + 1}. {text}",
                dashed=is_return,
            )

    out_path = UML_DIR / filename
    img.save(out_path, "PNG")
    return out_path


# ==============================================================================
# 6. UML 06: SEQUENCE DIAGRAM 1 - PRACTICE SESSION & HYBRID GENERATOR
# ==============================================================================
def build_uml_06_seq_practice():
    participants = [
        ("Người học", "<<Actor>>", INDIGO_STROKE),
        ("Topics / Quiz UI", "<<Presentation>>", BLUE_STROKE),
        ("PracticeNotifier", "<<Riverpod State>>", PURPLE_STROKE),
        ("HybridGenerator", "<<Domain Engine>>", EMERALD_STROKE),
        ("AudioService", "<<44.1kHz PCM>>", AMBER_STROKE),
        ("AppDatabase", "<<SQLite>>", ROSE_STROKE),
    ]
    messages = [
        (0, 1, "Chọn Chủ đề, Cấp độ & Thời gian (60s/15p/1h/Tự do)", False, INDIGO_STROKE),
        (1, 2, "startSession(mode, topicId, levelId, timeLimit)", False, BLUE_STROKE),
        (2, 5, "getQuestionsForPractice(topicId, levelId)", False, PURPLE_STROKE),
        (5, 2, "Trả về Pool câu hỏi (VD: 49 câu Hợp âm Guitar)", True, ROSE_STROKE),
        (2, 3, "buildSessionQuestions(pool, window=65% anti-repeat)", False, PURPLE_STROKE),
        (3, 3, "Lọc câu vừa hỏi + Sinh đáp án nhiễu + Cân bằng A/B/C/D", False, EMERALD_STROKE),
        (3, 2, "Danh sách câu hỏi đã trộn không lặp", True, EMERALD_STROKE),
        (2, 4, "playAsset(currentQuestion.audioPath) [Nếu bật AutoPlay]", False, AMBER_STROKE),
        (0, 1, "Nghe âm thanh & Chọn đáp án (A/B/C/D / Phím Đàn / Cần Đàn)", False, INDIGO_STROKE),
        (1, 2, "submitAnswer(selectedOption) [Chặn double-tap]", False, BLUE_STROKE),
        (2, 4, "playFeedbackSfx(isCorrect) + HapticFeedback", False, AMBER_STROKE),
        (2, 5, "recordReviewWrongAnswer(qId) [Nếu trả lời Sai]", False, ROSE_STROKE),
        (2, 5, "recordReviewCorrectAnswer(qId) [Nếu đang Ôn tập & Đúng]", False, EMERALD_STROKE),
        (2, 5, "saveCompletedSession(session, answers) & Cập nhật Streak", False, PURPLE_STROKE),
        (5, 1, "Điều hướng sang /session-result & Hiển thị Thẻ Vinh Danh", True, BLUE_STROKE),
    ]
    blocks = [
        ("loop", "Lặp qua từng câu hỏi hoặc cho tới khi hết giờ đếm ngược", 0, 5, 625, 965, BLUE_STROKE),
    ]
    return draw_sequence_diagram(
        "uml_06_seq_practice.png",
        "HÌNH 6: SƠ ĐỒ TUẦN TỰ LUỒNG PHIÊN LUYỆN TẬP & BỘ SINH CÂU HỎI HYBRID (SEQUENCE DIAGRAM 1)",
        "Quy trình khởi tạo phiên học, trộn câu hỏi chống lặp 65% Window, phát âm thanh WAV, chấm điểm và cập nhật Ôn câu sai",
        participants,
        messages,
        blocks,
    )


# ==============================================================================
# 7. UML 07: SEQUENCE DIAGRAM 2 - 1V1 BATTLE ARENA
# ==============================================================================
def build_uml_07_seq_battle():
    participants = [
        ("Người chơi 1", "<<Actor>>", INDIGO_STROKE),
        ("BattleScreen UI", "<<Presentation>>", BLUE_STROKE),
        ("BattleNotifier", "<<Riverpod State>>", PURPLE_STROKE),
        ("Bot AI / P2", "<<Opponent Engine>>", EMERALD_STROKE),
        ("AudioService", "<<SFX & Fanfare>>", AMBER_STROKE),
        ("Integrity & Store", "<<SHA-256 Store>>", ROSE_STROKE),
    ]
    messages = [
        (0, 1, "Bấm nút Diamond CTA -> Chọn Chế độ (Ghép Rank / Bot AI / 2 Người)", False, INDIGO_STROKE),
        (1, 2, "startBattle() -> Kiểm tra remainingBattlesToday (Tối đa 5 lượt/ngày)", False, BLUE_STROKE),
        (2, 5, "Trừ 1 lượt đấu & Xác thực chữ ký SHA-256 (SolfaIntegrityGuard)", False, PURPLE_STROKE),
        (2, 1, "Chuyển sang BattlePhase.vsIntro -> BattlePhase.fighting (100 HP)", True, PURPLE_STROKE),
        (2, 4, "Phát âm thanh câu hỏi hiệp hiện tại (playCurrentRoundAudio)", False, AMBER_STROKE),
        (2, 3, "Lập lịch phản xạ Bot AI theo cấp độ (Tập Sự / Nhạc Công / Cao Thủ / Huyền Thoại)", False, EMERALD_STROKE),
        (0, 1, "Chạm đáp án nhanh nhất trên màn hình", False, INDIGO_STROKE),
        (1, 2, "submitPlayer1Answer(option)", False, BLUE_STROKE),
        (2, 2, "Tính sát thương = Base + SpeedBonus + ComboCrit + FirstBlood", False, PURPLE_STROKE),
        (2, 4, "Kích hoạt hiệu ứng Sét đánh (strikeTarget) & Âm thanh Bạo kích", False, AMBER_STROKE),
        (2, 2, "Kiểm tra điều kiện K.O. (player2Hp == 0 hoặc hết 8 hiệp)", False, PURPLE_STROKE),
        (2, 5, "Cộng/Trừ Sao Xếp Hạng (+2 Sao khi K.O.) & Ký số SHA-256 mới", False, ROSE_STROKE),
        (2, 1, "Hiển thị Màn hình Kết quả Trận đấu & Huy hiệu Thăng hạng", True, BLUE_STROKE),
    ]
    blocks = [
        ("loop", "Các hiệp đấu 1v1 (Tối đa 8 hiệp hoặc tới khi 1 bên về 0 HP - K.O.)", 0, 4, 495, 920, PURPLE_STROKE),
    ]
    return draw_sequence_diagram(
        "uml_07_seq_battle.png",
        "HÌNH 7: SƠ ĐỒ TUẦN TỰ ĐẤU TRƯỜNG ÂM NHẠC 1V1 & TÍNH SÁT THƯƠNG HP/COMBO (SEQUENCE DIAGRAM 2)",
        "Quy trình tiêu hao lượt đấu, ghép trận, lập lịch Bot AI 4 cấp, tính sát thương bạo kích Combo và cập nhật Sao xếp hạng",
        participants,
        messages,
        blocks,
    )


# ==============================================================================
# 8. UML 08: SEQUENCE DIAGRAM 3 - GEM ECONOMY & INTEGRITY GUARD
# ==============================================================================
def build_uml_08_seq_gem_economy():
    participants = [
        ("Người dùng", "<<Actor>>", INDIGO_STROKE),
        ("Support / Modal UI", "<<Presentation>>", BLUE_STROKE),
        ("RewardedAdNotifier", "<<Gem Wallet>>", PURPLE_STROKE),
        ("SolfaIntegrityGuard", "<<SHA-256 & Clock>>", EMERALD_STROKE),
        ("Battle / Practice", "<<Feature Consumer>>", AMBER_STROKE),
        ("SharedPreferences", "<<Local Storage>>", ROSE_STROKE),
    ]
    messages = [
        (0, 1, "Bấm 'Xem Video 15s (+100 Gem & +1 Lượt)' hoặc Nhận thưởng Nhiệm vụ ngày", False, INDIGO_STROKE),
        (1, 2, "showRewardedVideoAdSimulationDialog() -> Xem trọn vẹn 15 giây", False, BLUE_STROKE),
        (2, 3, "checkAndAdvanceMonotonicClock(prefs) [Chống chỉnh lùi giờ thiết bị]", False, EMERALD_STROKE),
        (3, 2, "Đồng hồ hợp lệ (Monotonic Timestamp OK)", True, EMERALD_STROKE),
        (2, 3, "computeSignature(scope='ad_wallet', [total+100, spent, count+1])", False, EMERALD_STROKE),
        (2, 5, "Lưu totalPrestigePoints (+100 Gem) kèm chữ ký băm _sig_v2", False, ROSE_STROKE),
        (2, 4, "restoreTurnFromRewardedAd(turns: 1) -> Hồi ngay +1 Lượt Đấu Trường", False, AMBER_STROKE),
        (0, 1, "Chọn mở khóa Phiên 1 tiếng (200G) / Tự do (350G) / Scale VIP (300G) / +3 Lượt (500G)", False, INDIGO_STROKE),
        (1, 2, "spendGemsForOneHourSession(200) / spendPrestigePointsForTurns(500, 3)", False, BLUE_STROKE),
        (2, 3, "verifySignature(scope='ad_wallet') & Kiểm tra prestigePoints >= cost", False, EMERALD_STROKE),
        (2, 5, "Cộng spentPrestigePoints += cost & Ký lại chữ ký SHA-256 mới", False, ROSE_STROKE),
        (2, 4, "Kích hoạt quyền truy cập Phiên 1h / Tự do / Scale 12 ngăn / +3 Lượt Đấu", True, AMBER_STROKE),
    ]
    blocks = [
        ("alt", "Tích lũy Gem (Xem Video 15s / Nhiệm vụ) vs Chi tiêu Gem (200G / 300G / 350G / 500G / 800G)", 0, 5, 210, 1085, AMBER_STROKE),
    ]
    return draw_sequence_diagram(
        "uml_08_seq_gem_economy.png",
        "HÌNH 8: SƠ ĐỒ TUẦN TỰ KINH TẾ GEM, QUẢNG CÁO CÓ THƯỞNG & BẢO MẬT SHA-256 (SEQUENCE DIAGRAM 3)",
        "Cơ chế tích lũy Gem, đổi tính năng cao cấp (200/300/350/500/800 Gem) và chống gian lận ngoại tuyến bằng SolfaIntegrityGuard",
        participants,
        messages,
        blocks,
    )


# ==============================================================================
# 9. UML 09: ACTIVITY DIAGRAM (REVIEW RULE & STUDIO WORKFLOWS)
# ==============================================================================
def build_uml_09_activity():
    img, draw = create_canvas(
        1900,
        1160,
        "HÌNH 9: SƠ ĐỒ HOẠT ĐỘNG NGHIỆP VỤ ÔN TẬP CÂU SAI & PHÒNG STUDIO NHẠC CỤ (ACTIVITY DIAGRAM)",
        "Luồng A: Quy tắc Ôn tập 'Đúng 2 lần liên tiếp' • Luồng B: Tương tác Piano Studio (Chép nhạc) & Guitar Studio (44 Hợp âm / Jam)",
    )

    # Left Swimlane: Review Workflow
    draw.rounded_rectangle([50, 115, 925, 1125], radius=16, fill=BLUE_FILL, outline=BLUE_STROKE, width=3)
    draw.text((75, 128), "LUỒNG A: QUY TRÌNH ÔN TẬP CÂU SAI (QUY TẮC ĐÚNG 2 LẦN LIÊN TIẾP)", font=get_font(16, bold=True), fill=BLUE_DARK)

    # Start node A
    draw.ellipse([465, 170, 505, 210], fill=BLUE_DARK)
    steps_a = [
        ((270, 245, 700, 315), "1. Người học trả lời SAI câu hỏi Q trong Phiên học"),
        ((245, 355, 725, 435), "2. Ghi nhận vào bảng review_items:\nstatus = 'pending', wrong_count++, consecutive_correct = 0"),
        ((260, 475, 710, 545), "3. Người học mở 'Ôn tập câu sai' (/review) & Làm lại câu Q"),
        ((310, 680, 660, 755), "4A. Tăng consecutive_correct_count += 1"),
        ((70, 680, 290, 765), "4B. Reset về 0:\nconsecutive_correct = 0\nwrong_count += 1"),
        ((280, 910, 690, 985), "5. Cập nhật status = 'mastered'\n(Hoàn thành ôn tập & rút khỏi danh sách chờ)"),
    ]
    for box, txt in steps_a:
        draw_box(draw, box, txt, fill=(255, 255, 255), stroke=BLUE_STROKE, title_color=BLUE_DARK, title_size=14)

    # Decision diamonds A
    # Diamond 1: Correct or Wrong?
    d1 = [(485, 580), (575, 620), (485, 660), (395, 620)]
    draw.polygon(d1, fill=AMBER_FILL, outline=AMBER_STROKE)
    draw.text((442, 611), "Trả lời Đúng?", font=get_font(13, bold=True), fill=AMBER_DARK)

    # Diamond 2: consecutive >= 2?
    d2 = [(485, 790), (615, 835), (485, 880), (355, 835)]
    draw.polygon(d2, fill=EMERALD_FILL, outline=EMERALD_STROKE)
    draw.text((405, 826), "consecutive >= 2 ?", font=get_font(13, bold=True), fill=EMERALD_DARK)

    # End node A
    draw.ellipse([463, 1030, 507, 1074], fill=(255, 255, 255), outline=BLUE_DARK, width=3)
    draw.ellipse([471, 1038, 499, 1066], fill=BLUE_DARK)

    draw_arrow(draw, (485, 210), (485, 245), color=BLUE_STROKE)
    draw_arrow(draw, (485, 315), (485, 355), color=BLUE_STROKE)
    draw_arrow(draw, (485, 435), (485, 475), color=BLUE_STROKE)
    draw_arrow(draw, (485, 545), (485, 580), color=BLUE_STROKE)
    draw_arrow(draw, (485, 660), (485, 680), color=EMERALD_STROKE, label="Đúng")
    draw_arrow(draw, (395, 620), (177, 680), color=ROSE_STROKE, label="Sai")
    draw_arrow(draw, (485, 755), (485, 790), color=BLUE_STROKE)
    draw_arrow(draw, (485, 880), (485, 910), color=EMERALD_STROKE, label="Đạt >= 2 lần")
    draw_arrow(draw, (615, 835), (760, 510), color=AMBER_STROKE, label="Chưa đủ (Mới = 1)")
    draw_arrow(draw, (760, 510), (660, 510), color=AMBER_STROKE)
    draw_arrow(draw, (485, 985), (485, 1030), color=BLUE_STROKE)

    # Right Swimlane: Interactive Piano & Guitar Studios
    draw.rounded_rectangle([975, 115, 1850, 1125], radius=16, fill=EMERALD_FILL, outline=EMERALD_STROKE, width=3)
    draw.text((1000, 128), "LUỒNG B: HOẠT ĐỘNG PHÒNG STUDIO PIANO C3-C5 & GUITAR (THÙNG / ĐIỆN)", font=get_font(16, bold=True), fill=EMERALD_DARK)

    draw.ellipse([1392, 170, 1432, 210], fill=EMERALD_DARK)
    steps_b = [
        ((1170, 245, 1655, 315), "1. Chọn Công cụ Nhạc cụ từ Trang chủ hoặc Phòng luyện tập"),
        ((1010, 370, 1385, 465), "2A. Piano Studio (C3-C5):\n• Đàn tự do 25 phím + Khuông nhạc\n• Bật Chế độ Chép nhạc Giai điệu"),
        ((1435, 370, 1815, 465), "2B. Guitar Studio (Acoustic / Electric):\n• Chọn 44 Hợp âm / So dây 6 dây Hz\n• Bản đồ Scale 12 ngăn / 12 Bài luyện ngón"),
        ((1010, 515, 1385, 610), "3A. Nghe chuỗi 3-5 nốt mẫu ->\nBấm lại đúng thứ tự trên phím Piano"),
        ((1435, 515, 1815, 610), "3B. Bật Vòng Hợp âm tự động / Backing\nTrack Jam hoặc Mở khóa Scale VIP (300 Gem)"),
        ((1150, 665, 1675, 755), "4. Phát âm thanh đa âm (Polyphonic Pool 44.1kHz PCM WAV)\n& Hiển thị hiệu ứng rung dây / sáng phím thời gian thực (60fps)"),
        ((1150, 805, 1675, 895), "5. Chấm điểm 1-3 Sao (Bài luyện ngón Guitar) hoặc Hoàn thành\nChép nhạc Giai điệu -> Kích hoạt Nhiệm vụ ngày (+30 Gem)"),
        ((1180, 940, 1645, 1005), "6. Lưu tiến độ Sao & Tự động giải phóng Timer khi đóng Sheet"),
    ]
    for box, txt in steps_b:
        draw_box(draw, box, txt, fill=(255, 255, 255), stroke=EMERALD_STROKE, title_color=EMERALD_DARK, title_size=14)

    draw.ellipse([1390, 1035, 1434, 1079], fill=(255, 255, 255), outline=EMERALD_DARK, width=3)
    draw.ellipse([1398, 1043, 1426, 1071], fill=EMERALD_DARK)

    draw_arrow(draw, (1412, 210), (1412, 245), color=EMERALD_STROKE)
    draw_arrow(draw, (1320, 315), (1200, 370), color=EMERALD_STROKE, label="Đàn Piano")
    draw_arrow(draw, (1500, 315), (1625, 370), color=EMERALD_STROKE, label="Đàn Guitar")
    draw_arrow(draw, (1200, 465), (1200, 515), color=EMERALD_STROKE)
    draw_arrow(draw, (1625, 465), (1625, 515), color=EMERALD_STROKE)
    draw_arrow(draw, (1200, 610), (1320, 665), color=EMERALD_STROKE)
    draw_arrow(draw, (1625, 610), (1500, 665), color=EMERALD_STROKE)
    draw_arrow(draw, (1412, 755), (1412, 805), color=EMERALD_STROKE)
    draw_arrow(draw, (1412, 895), (1412, 940), color=EMERALD_STROKE)
    draw_arrow(draw, (1412, 1005), (1412, 1035), color=EMERALD_STROKE)

    out_path = UML_DIR / "uml_09_activity.png"
    img.save(out_path, "PNG")
    return out_path


# ==============================================================================
# 10. UML 10: STATE MACHINE DIAGRAM (BATTLE PHASE & METRONOME ENGINE)
# ==============================================================================
def build_uml_10_state_machine():
    img, draw = create_canvas(
        1900,
        1140,
        "HÌNH 10: SƠ ĐỒ MÁY TRẠNG THÁI ĐẤU TRƯỜNG 1V1 & MÁY ĐẾM NHỊP CƠ HỌC (STATE MACHINE DIAGRAM)",
        "Biểu đồ chuyển trạng thái của BattlePhase (Đấu Trường 1v1) và MetronomeStatus + Chu kỳ Phách (BeatState 2 -> 1 -> 0)",
    )

    # Top Frame: BattlePhase State Machine
    draw.rounded_rectangle([50, 115, 1850, 610], radius=16, fill=PURPLE_FILL, outline=PURPLE_STROKE, width=3)
    draw.text((75, 128), "A. MÁY TRẠNG THÁI ĐẤU TRƯỜNG ÂM NHẠC 1V1 (BattlePhase & Round State Machine)", font=get_font(16, bold=True), fill=PURPLE_DARK)

    draw.ellipse([85, 330, 125, 370], fill=PURPLE_DARK)
    battle_states = [
        ((185, 270, 485, 435), "BattlePhase.lobby", ["* Hiển thị Hạng Sao (6 bậc)", "* Kiểm tra Lượt đấu (5/5 lượt)", "* Chọn Chế độ & Chủ đề thi đấu", "* Đổi 200/500/800 Gem -> Lượt"]),
        ((575, 190, 885, 340), "BattlePhase.matchmaking", ["* Tìm đối thủ đồng hạng Sao", "* Hoặc khởi tạo Bot AI 4 cấp", "* Trừ 1 lượt đấu trong ngày"]),
        ((575, 390, 885, 540), "BattlePhase.vsIntro", ["* Hiển thị thẻ đối kháng VS", "* Danh hiệu & Tỷ lệ thắng", "* Đếm ngược sẵn sàng vào trận"]),
        ((985, 225, 1405, 515), "BattlePhase.fighting (100 HP vs 100 HP)", ["* Hiệp 1..8: Phát âm thanh & Đếm ngược 10s", "* Chấm điểm Tốc độ + Combo Bạo kích + First Blood", "* Phạt -12 HP & Khóa chọn nếu bấm Sai (LockedOut)", "* Kích hoạt hiệu ứng Sét đánh (strikeTarget)", "* Tạm dừng Timer khi khóa màn hình (onAppPaused)"]),
        ((1500, 270, 1810, 450), "BattlePhase.finished", ["* Xác định Thắng / Thua / Hòa", "* Thưởng +2 Sao nếu hạ K.O.", "* Lưu MatchRecord vào Lịch sử", "* Nút Tái đấu hoặc Về sảnh"]),
    ]
    for box, t, lines in battle_states:
        draw_box(draw, box, t, lines, fill=(255, 255, 255), stroke=PURPLE_STROKE, header_fill=PURPLE_STROKE, title_size=15, body_size=13)

    draw_arrow(draw, (125, 350), (185, 350), color=PURPLE_STROKE, width=2)
    draw_arrow(draw, (485, 315), (575, 265), color=PURPLE_STROKE, width=2, label="startBattle()")
    draw_arrow(draw, (730, 340), (730, 390), color=PURPLE_STROKE, width=2, label="Ghép thành công")
    draw_arrow(draw, (885, 460), (985, 380), color=PURPLE_STROKE, width=2, label="enterArenaNow()")
    draw_arrow(draw, (1405, 360), (1500, 360), color=ROSE_STROKE, width=3, label="K.O. / Hết hiệp")
    # Route backToLobby() along bottom corridor y=575
    draw.line([(1655, 450), (1655, 575), (335, 575)], fill=PURPLE_STROKE, width=2)
    draw_arrow(draw, (335, 575), (335, 435), color=PURPLE_STROKE, width=2, label="backToLobby()")

    # Bottom Frame: Metronome State Machine
    draw.rounded_rectangle([50, 645, 1850, 1105], radius=16, fill=EMERALD_FILL, outline=EMERALD_STROKE, width=3)
    draw.text((75, 658), "B. MÁY TRẠNG THÁI MÁY ĐẾM NHỊP CƠ HỌC (MetronomeStatus & Chu kỳ Đèn Phách BeatState)", font=get_font(16, bold=True), fill=EMERALD_DARK)

    draw.ellipse([85, 855, 125, 895], fill=EMERALD_DARK)
    metro_states = [
        ((185, 780, 505, 965), "MetronomeStatus.stopped", ["* Đèn phách nghỉ (currentBeat = 0)", "* Cho phép chỉnh BPM (30..300)", "* Gõ Tap Tempo / Chọn Preset", "* Tắt giữ sáng màn hình (Wakelock)"]),
        ((595, 715, 925, 865), "MetronomeStatus.countIn", ["* Đếm lấy đà 1-2 ô nhịp trước khi vào", "* Bật WakelockPlus giữ màn hình sáng", "* Khởi động Stopwatch Microsecond"]),
        ((595, 905, 925, 1065), "MetronomeStatus.paused", ["* Tự động kích hoạt khi ẩn App xuống nền", "  hoặc chuyển sang Tab khác (MainShell)", "* Giải phóng CPU & Dừng phát tiếng click"]),
        ((1015, 745, 1425, 1025), "MetronomeStatus.playing (<10ms Jitter)", ["* Vòng lặp Stopwatch bù trừ trễ vi giây", "* Phát tiếng Click phách chính & Subdivision (1x..4x)", "* Tự động tăng BPM sau mỗi N ô nhịp (Auto Speed-Up)", "* Đổi BPM/Loại nhịp trực tiếp không ngắt quãng"]),
        ((1495, 745, 1815, 1025), "Chu kỳ Chạm Đèn Phách (BeatState)", ["* Trạng thái 2: PHÁCH NHẤN (Màu Cam - Accent)", "   |  (Chạm vào ô đèn phách)", "   v", "* Trạng thái 1: PHÁCH THƯỜNG (Màu Xanh - Normal)", "   |  (Chạm vào ô đèn phách)", "   v", "* Trạng thái 0: TẮT TIẾNG (Màu Xám - Muted -> Quay về 2)"]),
    ]
    for box, t, lines in metro_states:
        draw_box(draw, box, t, lines, fill=(255, 255, 255), stroke=EMERALD_STROKE, header_fill=EMERALD_STROKE, title_size=15, body_size=13)

    draw_arrow(draw, (125, 875), (185, 875), color=EMERALD_STROKE, width=2)
    draw_arrow(draw, (505, 830), (595, 790), color=EMERALD_STROKE, width=2, label="start() [countIn > 0]")
    draw_arrow(draw, (505, 875), (1015, 875), color=EMERALD_STROKE, width=2, label="start() [countIn == 0]")
    draw_arrow(draw, (925, 790), (1015, 830), color=EMERALD_STROKE, width=2, label="Hết phách lấy đà")
    draw_arrow(draw, (1015, 945), (925, 975), color=AMBER_STROKE, width=2, label="pause() / AppPaused")
    draw_arrow(draw, (595, 975), (505, 920), color=ROSE_STROKE, width=2, label="stop()")

    out_path = UML_DIR / "uml_10_state_machine.png"
    img.save(out_path, "PNG")
    return out_path


def generate_all_uml_images():
    paths = [
        build_uml_01_use_case(),
        build_uml_02_architecture(),
        build_uml_03_navigation(),
        build_uml_04_class_diagram(),
        build_uml_05_erd(),
        build_uml_06_seq_practice(),
        build_uml_07_seq_battle(),
        build_uml_08_seq_gem_economy(),
        build_uml_09_activity(),
        build_uml_10_state_machine(),
    ]
    for p in paths:
        print(f"Generated UML image: {p} ({p.stat().st_size // 1024} KB)")
    return paths


# ==============================================================================
# STRUCTURED CONTENT FOR 19 CHAPTERS (SRS & SDD v2.0 - CHAONOTE / SOLFA v1.9.4+26)
# ==============================================================================
DOC_INFO_ROWS = [
    ("Tên hệ thống", "ChaoNote (Solfa) – Ứng dụng luyện cảm âm, khuông nhạc, Piano/Guitar Studio, Đấu Trường 1v1 & Máy đếm nhịp cơ học"),
    ("Mã gói phát hành (Package ID)", "vn.solfa.app.solfa (Google Play Console)"),
    ("Loại tài liệu", "Tài liệu Phân tích Yêu cầu & Thiết kế Hệ thống Toàn diện (SRS & SDD – Kèm Trọn bộ 10 Sơ đồ UML 2.5)"),
    ("Phiên bản tài liệu / Ứng dụng", "Tài liệu v2.0 • Ứng dụng v1.9.4+26 (Build 26)"),
    ("Nền tảng công nghệ", "Flutter 3.x (Dart ^3.5.3) • Riverpod 2.x • GoRouter 14.x • SQLite (sqflite) • Audioplayers 6.x (44.1kHz PCM DSP)"),
    ("Định hướng vận hành", "100% Offline-First • Không yêu cầu đăng ký tài khoản • Bảo mật chữ ký số cục bộ SolfaIntegrityGuard (SHA-256)"),
    ("Phạm vi phân phối quốc tế", "174+ Quốc gia & Vùng lãnh thổ • Tuân thủ Quy định (EU) 2018/302, GDPR, CCPA & Nghị định 13/2023/NĐ-CP"),
]

CHANGELOG_ROWS = [
    ("1.0", "09/11/2026", "Xây dựng tài liệu phân tích và thiết kế ban đầu (MVP: 3 chủ đề cảm âm cơ bản, Ôn tập câu sai và Máy đếm nhịp)."),
    ("1.5", "14/11/2026", "Mở rộng lên 7 chủ đề Cảm âm & Đọc khuông nhạc (Sol/Fa, dòng kẻ phụ), Phòng Piano Studio C3–C5 và Chép nhạc giai điệu."),
    ("1.8", "16/11/2026", "Bổ sung 4 chủ đề Guitar, Guitar Studio (Acoustic & Electric, 44 hợp âm, So dây Hz, 12 bài luyện ngón, Jam Track) và Đấu Trường 1v1."),
    ("2.0", "18/11/2026", "Phát hành v1.9.4+26: Mở rộng 81 câu hỏi Hợp âm Guitar & Piano (Hợp âm chặn, 7th, Sus/Add9, Power Chord, Capo), chống lặp 65% Window, đồng bộ Sáng/Tối, Header & Cài đặt 2 chiều, cân bằng bảng giá Gem (200/300/350/500/800 Gem) và bổ sung trọn bộ 10 sơ đồ UML 2.5."),
]

TOPICS_11_ROWS = [
    ("1. Nhận biết nốt (topic_notes)", "Cảm âm Piano", "4 Cấp (Mức 1..4)", "Nghe cao độ nốt đơn từ C3–C5 (Tự nhiên & Thăng/Giáng #/b), trả lời trắc nghiệm hoặc bấm trực tiếp phím Piano."),
    ("2. Đọc nốt nhạc (topic_staff_reading)", "Thị tấu Khuông nhạc", "4 Cấp (Mức 1..4)", "Đọc nốt trên Khuông 5 dòng kẻ Khóa Sol & Khóa Fa (C3–C6), bao gồm chế độ Chuyên luyện Dòng kẻ phụ."),
    ("3. Nhận biết quãng (topic_intervals)", "Cảm âm Hòa thanh", "3 Cấp (Cơ bản..Nâng cao)", "Phân biệt quãng 2, 3, 4, 5, 6, 7, 8 và quãng 4 tăng/5 giảm (Giai điệu đi lên/xuống & Hòa thanh)."),
    ("4. Nhận biết hợp âm Piano (topic_chords)", "Hòa âm Piano", "3 Cấp (32 câu hỏi)", "Nhận diện Hợp âm Trưởng, Thứ, Giảm (dim), Tăng (aug), Maj7, m7, Dom7, Sus2, Sus4, Add9 trên Piano."),
    ("5. Giai điệu ngắn (topic_melody)", "Trí nhớ Âm nhạc", "3 Cấp (Cơ bản..Nâng cao)", "Nghe và xác định chuỗi 3–4 nốt giai điệu đi lên, đi xuống, ngũ cung và bước nhảy quãng rộng."),
    ("6. Nhịp điệu & Tiết tấu (topic_rhythm)", "Tiết tấu", "3 Cấp (Cơ bản..Nâng cao)", "Nhận diện hình nốt Trắng, Đen, Móc đơn, Liên 3 (Triplet), Móc kép, Đảo phách (Syncopation) & nhịp 2/4, 3/4, 6/8."),
    ("7. Nhận biết giọng (topic_keys)", "Cảm âm Điệu tính", "3 Cấp (Cơ bản..Nâng cao)", "Nghe chuỗi hòa âm I–IV–V–I phân biệt Giọng Trưởng, Giọng Thứ tự nhiên, Thứ hòa thanh & Thứ giai điệu."),
    ("8. Nốt trên cần đàn Guitar (topic_guitar_notes)", "Nhạc cụ Guitar", "3 Cấp (Cơ bản..Nâng cao)", "Xác định vị trí nốt trên 6 dây đàn Guitar (E2–A2–D3–G3–B3–E4) từ ngăn buông đến ngăn 12."),
    ("9. Hợp âm Guitar (topic_guitar_chords)", "Hòa âm Guitar", "3 Cấp (49 câu hỏi)", "Nhận diện thế bấm & âm thanh Hợp âm mở, 8 Hợp âm chặn (F, Fm, Bm, B, F#m, Gm, Cm, Bb), Hợp âm 7, Màu sắc, Power Chord 5 & Capo."),
    ("10. Âm giai Guitar (topic_guitar_scales)", "Kỹ thuật Lead/Solo", "3 Cấp (Cơ bản..Nâng cao)", "Bản đồ âm giai Đô Trưởng, La Thứ, Ngũ cung (Pentatonic), Blues và La Thứ Hài Hòa trên cần đàn."),
    ("11. Đọc Tab & Riff Guitar (topic_guitar_tabs)", "Thị tấu Tab 6 dây", "3 Cấp (Cơ bản..Nâng cao)", "Đọc bản nhạc Tablature 6 dây, ký hiệu Hammer-on, Pull-off, Slide và các câu Riff kinh điển."),
]

GEM_ECONOMY_ROWS = [
    ("Xem Video Quảng cáo ngắn tự nguyện (15 giây)", "Tích lũy (+)", "+100 Gem & +1 Lượt Đấu", "Không ép buộc; người dùng chủ động mở tại Trạm Đổi Gem, Đấu Trường hoặc sau phiên học."),
    ("Hoàn thành Mục tiêu học tập hàng ngày (10..50 câu)", "Tích lũy (+)", "+20 Gem / ngày", "Chống nhận trùng trong cùng 1 ngày bằng khóa ngày ISO & chữ ký SHA-256."),
    ("Nhiệm vụ ngày 1: Luyện cảm âm 10 câu", "Tích lũy (+)", "+30 Gem / ngày", "Tự động mở khóa nút Nhận khi todayAnsweredCount >= 10."),
    ("Nhiệm vụ ngày 2: Đấu 1 trận Đấu Trường 1v1", "Tích lũy (+)", "+40 Gem / ngày", "Hoàn thành 1 trận ở bất kỳ chế độ Đấu Trường nào."),
    ("Nhiệm vụ ngày 3: Chép nhạc 1 giai điệu Piano", "Tích lũy (+)", "+30 Gem / ngày", "Hoàn thành 1 bài Chép nhạc giai điệu trong Piano Studio C3–C5."),
    ("Mở khóa Phiên luyện tập chuyên sâu 1 tiếng (3600s)", "Chi tiêu (-)", "200 Gem (kOneHourPracticeGemCost)", "Tương đương ~2 lượt xem video quảng cáo hoặc hoàn thành nhiệm vụ."),
    ("Mở khóa Chế độ Tự do không giới hạn thời gian", "Chi tiêu (-)", "350 Gem (kUnlimitedPracticeGemCost)", "Tương đương ~3.5 lượt xem video quảng cáo; luyện tập liên tục không đếm ngược."),
    ("Mở khóa vĩnh viễn Full Map Scale VIP 12 ngăn Guitar", "Chi tiêu (-)", "300 Gem (kGuitarProScaleGemCost)", "Mở khóa vĩnh viễn âm giai La Thứ Hài Hòa & toàn bộ 12 ngăn cần đàn."),
    ("Đổi Gói +1 Lượt Đấu Trường 1v1", "Chi tiêu (-)", "200 Gem (kSingleBattleTurnGemCost)", "Hồi ngay +1 lượt thi đấu Đấu Trường khi hết 5 lượt miễn phí/ngày."),
    ("Đổi Gói +3 Lượt Đấu Trường 1v1 (Tiết kiệm 100 Gem)", "Chi tiêu (-)", "500 Gem (kThreeBattleTurnsGemCost)", "Hồi ngay +3 lượt thi đấu Đấu Trường (ưu đãi tiết kiệm 100 Gem)."),
    ("Đổi Gói +5 Lượt Đấu Trường 1v1 (Tiết kiệm 200 Gem)", "Chi tiêu (-)", "800 Gem (kFiveBattleTurnsGemCost)", "Hồi đầy thanh +5 lượt thi đấu Đấu Trường (ưu đãi tiết kiệm 200 Gem)."),
]

BUSINESS_RULES_ROWS = [
    ("BR-01", "Hoạt động 100% Offline-First", "Toàn bộ 11 chủ đề, 283+ mẫu âm thanh WAV, Piano/Guitar Studio, Đấu Trường 1v1 và Máy đếm nhịp hoạt động ngoại tuyến không cần Internet."),
    ("BR-02", "Chống lặp câu hỏi Cửa sổ trượt 65%", "HybridQuestionGenerator lưu danh sách câu vừa xuất hiện với kích thước cửa sổ bằng 65% tổng số câu của cấp độ để ngăn lặp lại nhàm chán."),
    ("BR-03", "Cân bằng xác suất đáp án A/B/C/D", "Tự động đảo vị trí đáp án đúng và lấy mẫu ngẫu nhiên đáp án nhiễu (Dynamic Distractors) sao cho không vị trí nào vượt quá 2 lần liên tiếp."),
    ("BR-04", "Chống bấm trùng (Double-Tap Guard)", "Khi người dùng đã chọn đáp án, khóa cờ isSubmittingAnswer ngay lập tức để ngăn cộng điểm kép hoặc ghi bản ghi trùng."),
    ("BR-05", "Quy tắc Ôn tập 'Đúng 2 lần liên tiếp'", "Câu trả lời sai được đưa vào review_items (status='pending'). Chỉ khi trả lời đúng 2 lần liên tiếp (consecutive_correct_count >= 2) mới chuyển sang 'mastered'."),
    ("BR-06", "Đồng bộ Cài đặt 2 chiều bền vững", "Mọi thay đổi về Thời gian luyện tập mặc định (60s/15p/1h/Tự do), Âm sắc Metronome, Giao diện Sáng/Tối và Ngôn ngữ được đồng bộ tức thì và lưu vào SQLite."),
    ("BR-07", "Giới hạn 5 Lượt Đấu Trường miễn phí/ngày", "Mỗi ngày cấp mới 5 lượt Đấu Trường miễn phí. Khi hết lượt, người chơi có thể xem video 15s (+1 lượt & +100 Gem) hoặc đổi 200/500/800 Gem."),
    ("BR-08", "Công thức Sát thương & Bạo kích 1v1", "Mỗi đấu thủ có 100 HP. Trả lời đúng gây sát thương = Base (18) + SpeedBonus (0..8) + ComboCrit (+6..14) + FirstBlood (+4). Trả lời sai tự mất 12 HP và khóa chọn hiệp đó."),
    ("BR-09", "Bảo mật Chữ ký số & Chống lùi giờ", "SolfaIntegrityGuard ký SHA-256 Salted cho Ví Gem, Sao Đấu Trường và Nhiệm vụ ngày; Monotonic Clock Guard từ chối nhận thưởng nếu phát hiện chỉnh lùi đồng hồ thiết bị."),
    ("BR-10", "Quản lý Vòng đời Âm thanh & Nền", "Khi người dùng ẩn ứng dụng xuống nền (AppLifecycleState.paused) hoặc rời tab Công cụ, tự động dừng Metronome, Vòng hợp âm, Jam Track và giải phóng Timer."),
]

TEST_CASES_23_ROWS = [
    ("TC-01", "Khởi động Offline lần đầu", "Mở ứng dụng khi không có mạng -> Tự động seed SQLite, hiển thị Trang chủ bình thường.", "PASSED"),
    ("TC-02..05", "Luồng làm bài & Lưu lịch sử", "Chọn đáp án đúng/sai, phát phản hồi âm thanh, hoàn thành phiên và lưu vào practice_sessions.", "PASSED"),
    ("TC-06", "Quy tắc Ôn tập câu sai (2 lần)", "Trả lời sai -> vào danh sách ôn; đúng lần 1 vẫn pending; đúng lần 2 liên tiếp -> mastered.", "PASSED"),
    ("TC-07", "Đồng bộ Giao diện Sáng / Tối", "Chuyển đổi Light / Dark / System -> Tương phản nút bấm đồng nhất, lưu bền vững vào SQLite.", "PASSED"),
    ("TC-08..11", "Máy đếm nhịp cơ học & Tap Tempo", "Kiểm định chu kỳ 60 BPM (1.0s), 120 BPM (0.5s), lọc nhiễu Tap Tempo và đổi nhịp 1/4..6/8.", "PASSED"),
    ("TC-12", "Xem quảng cáo khi Offline", "Bấm xem video khi mất mạng -> Hiển thị hộp thoại thông báo thân thiện, không văng ứng dụng.", "PASSED"),
    ("TC-13", "Chống bấm trùng (Double-Tap)", "Chạm liên tiếp vào đáp án trong cùng 1 câu -> Chỉ ghi nhận 1 lần chấm điểm duy nhất.", "PASSED"),
    ("TC-14", "Bảo toàn dữ liệu khi nâng cấp", "Chạy lại seedContent() khi nâng cấp phiên bản -> Giữ nguyên 100% lịch sử học và chuỗi ngày.", "PASSED"),
    ("TC-15", "4 Chế độ Thời gian luyện tập", "Kiểm định đếm ngược 60 giây, 15 phút, 1 tiếng (200 Gem) và Tự do không giới hạn (350 Gem).", "PASSED"),
    ("TC-16", "4 Mức độ Nhận biết nốt & Piano", "Trả lời bằng bàn phím Piano C3–C5 và kiểm định đèn phách Nhấn/Thường/Tắt của Metronome.", "PASSED"),
    ("TC-17", "Độ ổn định UI màn hình nhỏ", "Render toàn bộ màn hình trên kích thước 360x680 ở cả Light/Dark Mode -> Không lỗi tràn khung hay cắt chữ (...).", "PASSED"),
    ("TC-18", "Xử lý tình huống biên (Edge Cases)", "Đổi chế độ giữa phiên, danh sách ôn tập rỗng, giới hạn BPM 30..300 -> Không phát sinh ngoại lệ.", "PASSED"),
    ("TC-19", "Chủ đề Hợp âm, Giai điệu, Nhịp", "Kiểm định mở khóa chủ đề mới, tính Combo liên tiếp, kỷ lục điểm cao và Mục tiêu hàng ngày.", "PASSED"),
    ("TC-20", "Thuật toán Random Hybrid (65%)", "Kiểm định phân phối đồng đều, không lặp câu hỏi liên tiếp, đảo A/B/C/D và nạp tiếp câu hỏi ở mốc câu 20.", "PASSED"),
    ("TC-21", "Đấu Trường Âm Nhạc 1v1 & Đổi Gem", "Ghép trận, Bot AI 4 cấp, Đấu 2 người 1 máy, tính sát thương HP/Combo, giới hạn 5 lượt/ngày & đổi gói 200/500 Gem.", "PASSED"),
    ("TC-22", "Kiểm định toàn diện 11 Chủ đề & Bảo mật", "Kiểm định 4 mức Đọc khuông Sol/Fa, 4 chủ đề Guitar, SolfaIntegrityGuard chống lùi giờ & bảng giá Gem mới (200/350 Gem).", "PASSED"),
    ("TC-23", "Độ ổn định Sóng âm PCM & Lifecycle", "Kiểm định Zero-Click PCM WAV, So dây Loop Hz, Vòng hợp âm, Backing Track Jam, chấm 3 Sao & tạm dừng khi khóa máy.", "PASSED"),
]


def generate_markdown_doc():
    md_path = ROOT / "SYSTEM_DESIGN_SRS_SDD.md"

    def md_table(headers, rows):
        lines = ["| " + " | ".join(headers) + " |"]
        lines.append("| " + " | ".join(["---"] * len(headers)) + " |")
        for r in rows:
            lines.append("| " + " | ".join(str(c) for c in r) + " |")
        return "\n".join(lines)

    t_doc_info = md_table(["Thuộc tính", "Chi tiết đặc tả"], DOC_INFO_ROWS)
    t_changelog = md_table(["Phiên bản", "Ngày cập nhật", "Nội dung nâng cấp"], CHANGELOG_ROWS)
    t_topics = md_table(["Chủ đề (Topic ID)", "Phân nhóm", "Số cấp độ", "Nội dung học thuật & Tương tác"], TOPICS_11_ROWS)
    t_rules = md_table(["Mã quy tắc", "Tên quy tắc nghiệp vụ", "Mô tả đặc tả kỹ thuật"], BUSINESS_RULES_ROWS)
    t_gems = md_table(["Hoạt động / Tính năng", "Loại giao dịch", "Định mức Gem", "Cơ chế vận hành & Bảo mật"], GEM_ECONOMY_ROWS)
    t_tests = md_table(["Mã Kịch bản", "Tên Kịch bản Kiểm thử", "Nội dung & Tiêu chí Nghiệm thu", "Kết quả"], TEST_CASES_23_ROWS)

    content = """# TÀI LIỆU PHÂN TÍCH YÊU CẦU & THIẾT KẾ HỆ THỐNG (SRS & SDD v2.0)
## DỰ ÁN: CHAONOTE (SOLFA v1.9.4+26) — ỨNG DỤNG LUYỆN CẢM ÂM, KHUÔNG NHẠC, PIANO/GUITAR STUDIO, ĐẤU TRƯỜNG 1v1 & MÁY ĐẾM NHỊP CƠ HỌC

---

### THÔNG TIN QUẢN LÝ TÀI LIỆU
__T_DOC_INFO__

### LỊCH SỬ THAY ĐỔI TÀI LIỆU (REVISION HISTORY)
__T_CHANGELOG__

---

## MỤC LỤC 19 CHƯƠNG & HỆ THỐNG 10 SƠ ĐỒ UML 2.5
1. **Chương 1**: Tổng quan dự án & Định hướng sản phẩm
2. **Chương 2**: Mục tiêu và phạm vi hệ thống (11 Chủ đề • 2 Studios • Đấu Trường 1v1 • Metronome)
3. **Chương 3**: Đối tượng sử dụng (Actors) và phân tích nhu cầu
4. **Chương 4**: Nguyên tắc thiết kế trải nghiệm & giao diện người dùng (UX/UI Light & Dark Mode)
5. **Chương 5**: Kiến trúc chức năng tổng thể & Sơ đồ Use Case (UML Use Case & Navigation Flow)
6. **Chương 6**: Đặc tả chức năng chi tiết (24 Use Cases cốt lõi)
7. **Chương 7**: Thiết kế luồng nghiệp vụ chính (UML Sequence & Activity Diagrams)
8. **Chương 8**: Quy tắc nghiệp vụ & Công thức tính toán (Business Rules BR-01 đến BR-10)
9. **Chương 9**: Thiết kế dữ liệu Offline-First (UML ERD: 9 bảng SQLite & Kho bảo mật SharedPreferences)
10. **Chương 10**: Kiến trúc kỹ thuật Flutter & Sơ đồ Lớp (UML Component Architecture & Class Diagram)
11. **Chương 11**: Thiết kế hạt nhân âm thanh 44.1kHz PCM DSP & Bộ sinh câu hỏi Hybrid (Anti-Repeat 65%)
12. **Chương 12**: Thiết kế Máy đếm nhịp cơ học độ trễ thấp (<10ms) & Sơ đồ Máy trạng thái (UML State Machine)
13. **Chương 13**: Hệ sinh thái Kinh tế Gem, Quảng cáo có thưởng & Bảo mật chống gian lận (`SolfaIntegrityGuard`)
14. **Chương 14**: Yêu cầu phi chức năng, Đa ngôn ngữ & Tuân thủ pháp lý quốc tế (EU 2018/302, GDPR, Nghị định 13)
15. **Chương 15**: Xử lý lỗi, Quản lý vòng đời ứng dụng (Lifecycle) và Tình huống ngoại lệ
16. **Chương 16**: Kiểm thử tự động (23 Kịch bản Nghiệm thu TC-01 -> TC-23)
17. **Chương 17**: Lộ trình phát triển sản phẩm (Roadmap v1.0 -> v2.0+)
18. **Chương 18**: Quản trị rủi ro kỹ thuật và Giải pháp giảm thiểu
19. **Chương 19**: Kết luận

---

## 1. TỔNG QUAN DỰ ÁN
### 1.1. Giới thiệu hệ thống
**ChaoNote (Solfa)** là ứng dụng di động đa nền tảng (Android & iOS) phát triển bằng **Flutter**, giúp người học rèn luyện khả năng **cảm âm (Ear Training)**, **thị tấu đọc bản nhạc trên khuông Khóa Sol/Fa & Tab Guitar**, thực hành trực tiếp trên **Đàn Piano Studio (C3–C5)** và **Đàn Guitar Studio (Acoustic & Electric)**, tranh tài phản xạ tại **Đấu Trường Âm Nhạc 1v1**, đồng thời giữ nhịp luyện đàn với **Máy đếm nhịp cơ học (Mechanical Metronome)** độ trễ dưới `10ms`.

Toàn bộ hệ thống vận hành theo kiến trúc **100% Offline-First**: không bắt buộc đăng ký tài khoản, không thu thập dữ liệu cá nhân, lưu trữ bền vững trên cơ sở dữ liệu cục bộ **SQLite** kết hợp cơ chế bảo vệ chống gian lận chữ ký số **SHA-256 (`SolfaIntegrityGuard`)**.

### 1.2. Định hướng cốt lõi
* **Đơn giản & Trực quan**: Mở ứng dụng là có thể bắt đầu luyện tập ngay chỉ với 1 chạm từ thẻ Hero *"Tiếp tục bài học"*.
* **Học qua Nghe & Chạm Nhạc Cụ**: Kết hợp 283+ mẫu âm thanh tổng hợp DSP 44.1kHz PCM WAV với bàn phím Piano 25 phím và cần đàn Guitar 6 dây tương tác trực tiếp.
* **Không cắt chữ & Đồng nhất Sáng/Tối**: Hệ thống Header tinh gọn (`[💎 Số dư]`, `[🔥 Chuỗi ngày]`, `[⚙️]`), hộp thoại xác nhận nút ngang đối xứng và độ tương phản chuẩn WCAG trên cả hai chế độ Light Mode và Dark Mode.
* **Kiếm tiền văn minh (Voluntary Rewarded Economy)**: Tuyệt đối không chèn quảng cáo tự động làm gián đoạn bài học; người dùng chủ động làm nhiệm vụ ngày hoặc xem video ngắn 15 giây để tích lũy **Gem** mở khóa phiên chuyên sâu.

---

## 2. MỤC TIÊU VÀ PHẠM VI HỆ THỐNG (11 CHỦ ĐỀ & 35 CẤP ĐỘ)
__T_TOPICS__

---

## 3. ĐỐI TƯỢNG SỬ DỤNG (ACTORS) VÀ NHU CẦU
1. **Người học nhạc (`Primary Actor`)**: Học sinh, sinh viên nhạc viện, người tự học Piano/Guitar và người luyện thanh cần công cụ rèn tai nghe, nhớ vị trí nốt trên khuông nhạc/cần đàn và giữ nhịp hàng ngày.
2. **Người chơi thứ 2 (`Local Split-Screen Actor`)**: Bạn bè cùng thi đấu phản xạ cảm âm trực tiếp trên cùng 1 thiết bị ở chế độ *Đấu 2 Người 1 Máy*.
3. **Hạt nhân Âm thanh DSP & SQLite (`Local Engine Actor`)**: Thực thi truy vấn dữ liệu ngoại tuyến và phát âm thanh đa âm (Polyphonic Pool) độ trễ cực thấp.
4. **Hệ thống Quảng cáo Có thưởng & Bảo mật (`Rewarded Ad & SolfaIntegrityGuard`)**: Cung cấp video nhận thưởng 15 giây và kiểm định chữ ký số SHA-256 cùng đồng hồ đơn điệu chống chỉnh lùi giờ.

---

## 4. NGUYÊN TẮC TRẢI NGHIỆM & GIAO DIỆN NGƯỜI DÙNG (UX/UI)
* **Header chính 4 Tab (`MainShell`)**: Chỉ hiển thị biểu tượng Logo tại Tab *Trang chủ (`ChaoNote`)*; ở 3 tab *Phòng luyện tập*, *Máy đếm nhịp* và *Tiến trình* ẩn Logo lặp lại để nhường 100% chiều ngang cho tiêu đề trang. Cụm huy hiệu bên phải chỉ hiển thị Icon + Số (`[💎 220]`, `[🔥 6]`, `[⚙️]`) bọc trong `FittedBox` chống cắt chữ `...` trên mọi kích thước màn hình (kể cả màn hình nhỏ `360x680`).
* **Header Đấu Trường 1v1 (`BattleScreen`)**: Hiển thị gọn `[←] [⚔️] Đấu Trường 1v1` và duy nhất 1 huy hiệu năng lượng `[⚡ 5/5]` bên phải (không lặp lại huy hiệu Sao đã có ở thẻ Hạng ngay bên dưới).
* **Hộp thoại xác nhận nút ngang đối xứng**: Toàn bộ các popup xác nhận (*Kết thúc phiên luyện tập*, *Xóa dữ liệu lịch sử*, *Đặt lại mẫu nhịp*) sử dụng bố cục `Row` + `Expanded` cân đối 2 nút trái/phải thay vì xếp chồng dọc.
* **Đồng bộ tương phản Sáng / Tối (`AppTheme`)**: Đặt `outlinedButtonTheme.backgroundColor = Colors.transparent` làm gốc và phủ nền kính mờ (`Colors.white.withOpacity(0.14)`) trên các thẻ Hero tối màu để không bao giờ xảy ra lỗi chữ trắng trên nền trắng.

---

## 5. KIẾN TRÚC CHỨC NĂNG TỔNG THỂ & SƠ ĐỒ USE CASE (UML)

### 5.1. Hình 1 — Sơ đồ Use Case Tổng Quát & Phân Rã Hệ Thống
![Hình 1 - Sơ đồ Use Case Tổng Quát](docs/uml/uml_01_use_case.png)

```mermaid
flowchart LR
    ActorUser(["👤 Người học nhạc"])
    ActorP2(["👥 Người chơi thứ 2"])
    ActorDSP(["🔊 DSP Audio & SQLite"])
    ActorGuard(["🛡️ Rewarded Ad & SHA-256 Guard"])

    subgraph SYS["HỆ THỐNG CHAONOTE (SOLFA v1.9.4+26 OFFLINE-FIRST)"]
        subgraph SUB1["1. Phân hệ Luyện tập 11 Chủ đề (35 Cấp độ)"]
            UC01("UC-01: Luyện nhanh & Tiếp tục bài học")
            UC02("UC-02: Luyện 7 Chủ đề Cảm âm & Khuông Sol/Fa")
            UC03("UC-03: Luyện 4 Chủ đề Guitar & 81 câu Hợp âm")
            UC04("UC-04: Trả lời bằng Phím Piano & Cần đàn 6 dây")
            UC05("UC-05: Ôn tập câu sai (Đúng 2 lần liên tiếp)")
            UC06("UC-06: Xem Tiến trình & Thẻ Vinh Danh")
            UC07("UC-07: Sinh câu hỏi Hybrid (Anti-Repeat 65%)")
        end
        subgraph SUB2["2. Phân hệ Studio Nhạc cụ & Metronome (<10ms)"]
            UC08("UC-08: Đàn Piano C3-C5 & Khuông nhạc")
            UC09("UC-09: Chép nhạc Giai điệu (Melodic Dictation)")
            UC10("UC-10: Guitar Studio 44 Hợp âm & So dây Hz")
            UC11("UC-11: Vòng Hòa âm, Jam Track & Scale VIP")
            UC12("UC-12: 12 Bài Luyện Ngón Guitar (36 Sao)")
            UC13("UC-13: Máy đếm nhịp cơ học 30-300 BPM")
        end
        subgraph SUB3["3. Phân hệ Đấu Trường Âm Nhạc 1v1"]
            UC15("UC-15: Đấu Hạng 1v1 (Smart Matchmaking)")
            UC16("UC-16: Đấu Máy AI 4 Cấp độ")
            UC17("UC-17: Đấu 2 Người 1 Máy (Split-Screen)")
            UC18("UC-18: Tính sát thương 100 HP & Bạo kích Combo")
        end
        subgraph SUB4["4. Phân hệ Kinh tế Gem, Bảo mật & Cài đặt"]
            UC20("UC-20: Làm 3 Nhiệm vụ ngày (+100 Gem)")
            UC21("UC-21: Xem Video 15s (+100 Gem & +1 Lượt)")
            UC22("UC-22: Đổi Gem (200/300/350/500/800 Gem)")
            UC23("UC-23: Cài đặt 2 chiều & 174+ Quốc gia")
            UC24("UC-24: Kiểm định Chữ ký SHA-256 & Đồng hồ")
        end
    end

    ActorUser --> UC01 & UC02 & UC03 & UC05 & UC08 & UC10 & UC13 & UC15 & UC20 & UC22 & UC23
    ActorP2 --> UC17
    UC02 & UC03 -.->|include| UC07
    UC15 & UC16 & UC17 -.->|include| UC18
    UC20 & UC21 & UC22 -.->|include| UC24
    UC07 & UC08 & UC10 & UC13 --> ActorDSP
    UC21 & UC24 --> ActorGuard
```

### 5.2. Hình 3 — Sơ đồ Luồng Điều Hướng Màn Hình (`GoRouter UI Navigation Flow`)
![Hình 3 - Sơ đồ Luồng Điều Hướng Màn Hình](docs/uml/uml_03_navigation.png)

---

## 6. ĐẶC TẢ CHỨC NĂNG CHI TIẾT
* **Phân hệ Trang chủ (`/home`)**: Hiển thị chuỗi ngày học (Streak), thẻ Hero *Tiếp tục bài học*, thanh 4 tiện ích nhanh (*Đàn Piano*, *Đàn Guitar*, *Ôn câu sai*, *Đấu trường*), thanh tiến độ *Mục tiêu hôm nay (`+20 Gem`)* và danh sách *3 Nhiệm vụ hàng ngày (`+100 Gem`)*.
* **Phân hệ Phòng luyện tập & Phòng thi (`/topics`, `/quiz`, `/session-result`)**: Hỗ trợ 4 chế độ thời gian: **60 giây (Miễn phí)**, **15 phút (Miễn phí)**, **1 tiếng (`200 Gem`)** và **Tự do không giới hạn (`350 Gem`)**. Hỗ trợ trả lời bằng 4 thẻ A/B/C/D, bàn phím Piano C3–C5 hoặc sơ đồ cần đàn Guitar 6 dây có huy hiệu `"Chặn 1"` cho hợp âm chặn (Barre chords).
* **Phân hệ Studio Nhạc cụ (`FreePianoExplorerSheet` & `GuitarStudioSheet`)**:
  * **Piano Studio**: Đàn tự do 25 phím (C3–C5) hiển thị vị trí nốt trên khuông Khóa Sol và chế độ *Chép nhạc giai điệu*.
  * **Guitar Studio**: Chuyển đổi âm sắc *Guitar Thùng (Acoustic)* & *Guitar Điện (Electric Overdrive)*, thư viện 44 hợp âm, bộ so dây 6 dây chuẩn tần số Hz có chế độ lặp (Loop Tuner), máy chạy vòng hòa âm tự động, phòng Jam Backing Track, bản đồ Scale 12 ngăn (mở khóa VIP bằng `300 Gem`) và lộ trình 12 bài luyện ngón chấm 36 Sao.
* **Phân hệ Đấu Trường Âm Nhạc 1v1 (`/battle`)**: Truy cập nhanh từ nút Diamond CTA ở chính giữa thanh điều hướng dưới. Hỗ trợ *Đấu Hạng 1v1*, *Đấu Máy AI (Tập Sự, Nhạc Công, Cao Thủ, Huyền Thoại)* và *2 Người 1 Máy (Chia đôi màn hình đối xứng)*.

---

## 7. LUỒNG NGHIỆP VỤ CHÍNH (UML SEQUENCE & ACTIVITY DIAGRAMS)

### 7.1. Hình 6 — Sơ đồ Tuần Tự Luồng Phiên Luyện Tập & Bộ Sinh Câu Hỏi Hybrid
![Hình 6 - Sơ đồ Tuần Tự Phiên Luyện Tập](docs/uml/uml_06_seq_practice.png)

```mermaid
sequenceDiagram
    autonumber
    actor U as Người học
    participant UI as Topics / QuizScreen
    participant PN as PracticeSessionNotifier
    participant HG as HybridQuestionGenerator
    participant AU as AudioService (44.1kHz)
    participant DB as AppDatabase (SQLite)

    U->>UI: Chọn Chủ đề, Cấp độ & Thời gian (60s / 15p / 1h 200G / Tự do 350G)
    UI->>PN: startSession(mode, topicId, levelId, timeLimit)
    PN->>DB: getQuestionsForPractice(topicId, levelId)
    DB-->>PN: Danh sách câu hỏi gốc (VD: 49 câu Hợp âm Guitar)
    PN->>HG: buildSessionQuestions(pool, antiRepeatWindow = 65%)
    HG->>HG: Lọc câu vừa hỏi + Sinh đáp án nhiễu + Cân bằng vị trí A/B/C/D
    HG-->>PN: Danh sách câu hỏi đã trộn không lặp
    loop Lặp qua từng câu hỏi hoặc tới khi hết giờ
        PN->>AU: playAsset(currentQuestion.audioPath)
        U->>UI: Chạm chọn đáp án (A/B/C/D / Phím Piano / Cần đàn Guitar)
        UI->>PN: submitAnswer(selectedOption) [Double-Tap Guard]
        PN->>AU: playFeedbackSfx(isCorrect) + HapticFeedback
        alt Trả lời SAI
            PN->>DB: recordReviewWrongAnswer(questionId)
        else Trả lời ĐÚNG trong chế độ Ôn tập
            PN->>DB: recordReviewCorrectAnswer(questionId)
        end
    end
    PN->>DB: saveCompletedSession(session, answers) & Cập nhật Streak
    PN-->>UI: Điều hướng tới /session-result & Hiển thị Thẻ Vinh Danh
```

### 7.2. Hình 7 — Sơ đồ Tuần Tự Đấu Trường Âm Nhạc 1v1
![Hình 7 - Sơ đồ Tuần Tự Đấu Trường 1v1](docs/uml/uml_07_seq_battle.png)

```mermaid
sequenceDiagram
    autonumber
    actor P1 as Người chơi 1
    participant UI as BattleScreen
    participant BN as BattleNotifier
    participant BOT as Bot AI / Người chơi 2
    participant AU as AudioService
    participant SEC as SolfaIntegrityGuard & Store

    P1->>UI: Bấm nút Diamond CTA -> Chọn Chế độ & Bắt đầu trận đấu
    UI->>BN: startBattle() [Kiểm tra remainingBattlesToday > 0]
    BN->>SEC: Trừ 1 lượt đấu & Ký chữ ký SHA-256
    BN-->>UI: BattlePhase.vsIntro -> BattlePhase.fighting (100 HP vs 100 HP)
    loop Tối đa 8 hiệp hoặc tới khi 1 bên về 0 HP (K.O.)
        BN->>AU: playAsset(roundQuestion.audioPath)
        BN->>BOT: Lập lịch phản xạ Bot AI theo cấp độ khó
        P1->>UI: Chạm chọn đáp án nhanh nhất
        UI->>BN: submitPlayer1Answer(option)
        BN->>BN: Tính sát thương = Base + SpeedBonus + ComboCrit + FirstBlood
        BN->>AU: Phát hiệu ứng Sét đánh (strikeTarget) & Âm thanh Bạo kích
    end
    BN->>SEC: Cộng/Trừ Sao Xếp Hạng (+2 Sao nếu K.O.) & Ký SHA-256
    BN-->>UI: Hiển thị BattlePhase.finished & Huy hiệu Thăng hạng
```

### 7.3. Hình 8 — Sơ đồ Tuần Tự Kinh Tế Gem, Quảng Cáo Có Thưởng & Bảo Mật SHA-256
![Hình 8 - Sơ đồ Tuần Tự Kinh Tế Gem](docs/uml/uml_08_seq_gem_economy.png)

### 7.4. Hình 9 — Sơ đồ Hoạt Động Nghiệp Vụ Ôn Tập Câu Sai & Phòng Studio Nhạc Cụ
![Hình 9 - Sơ đồ Hoạt Động Ôn Tập & Studio](docs/uml/uml_09_activity.png)

---

## 8. QUY TẮC NGHIỆP VỤ (BUSINESS RULES BR-01 ĐẾN BR-10)
__T_RULES__

---

## 9. THIẾT KẾ DỮ LIỆU OFFLINE-FIRST (UML ERD)

### 9.1. Hình 5 — Sơ đồ Thực Thể Liên Kết Cơ Sở Dữ Liệu Cục Bộ (`SQLite ERD & Secure Store`)
![Hình 5 - Sơ đồ ERD Cơ sở dữ liệu](docs/uml/uml_05_erd.png)

```mermaid
erDiagram
    topics ||--o{ levels : "has 3..4 levels"
    topics ||--o{ questions : "contains"
    levels ||--o{ questions : "categorizes"
    questions ||--|{ question_options : "has 4 options"
    practice_sessions ||--|{ practice_answers : "records"
    questions ||--o{ practice_answers : "answered in"
    questions ||--o| review_items : "tracked in"

    topics {
        TEXT id PK
        TEXT code UQ
        TEXT name
        INTEGER display_order
        INTEGER is_enabled
    }
    levels {
        TEXT id PK
        TEXT topic_id FK
        TEXT code
        INTEGER difficulty_order
        REAL pass_threshold
        INTEGER question_count
    }
    questions {
        TEXT id PK
        TEXT topic_id FK
        TEXT level_id FK
        TEXT question_type
        TEXT prompt_text
        TEXT audio_path
        TEXT correct_answer
        TEXT explanation_text
    }
    question_options {
        TEXT id PK
        TEXT question_id FK
        TEXT label
        TEXT content
        TEXT option_value
        INTEGER is_correct
    }
    practice_sessions {
        TEXT id PK
        TEXT session_type
        TEXT topic_id FK
        TEXT level_id FK
        INTEGER total_questions
        INTEGER correct_answers
        INTEGER score
        REAL accuracy_percent
        INTEGER duration_seconds
    }
    review_items {
        TEXT id PK
        TEXT question_id FK
        INTEGER wrong_count
        INTEGER consecutive_correct_count
        TEXT status
    }
    app_settings {
        TEXT setting_key PK
        TEXT setting_value
        TEXT updated_at
    }
```

---

## 10. KIẾN TRÚC KỸ THUẬT FLUTTER & SƠ ĐỒ LỚP (UML ARCHITECTURE & CLASS DIAGRAM)

### 10.1. Hình 2 — Kiến Trúc Phân Tầng & Thành Phần Hệ Thống (`Layered & Component Architecture`)
![Hình 2 - Kiến trúc Phân tầng Hệ thống](docs/uml/uml_02_architecture.png)

### 10.2. Hình 4 — Sơ đồ Lớp Chi Tiết (`UML Class Diagram`)
![Hình 4 - Sơ đồ Lớp Chi Tiết](docs/uml/uml_04_class_diagram.png)

```mermaid
classDiagram
    class QuestionModel {
        +String id
        +String topicId
        +String levelId
        +String questionType
        +String promptText
        +String? audioPath
        +String correctAnswer
        +List~QuestionOptionModel~ options
        +correctOption() QuestionOptionModel
    }
    class PracticeSessionNotifier {
        -AppDatabase _db
        -AudioService _audio
        -HybridQuestionGenerator _generator
        +startSession() Future~bool~
        +submitAnswer(QuestionOptionModel) Future~void~
        +nextQuestion() Future~bool~
        +finishSessionNow() Future~void~
    }
    class BattleNotifier {
        -AppDatabase _db
        -AudioService _audio
        +startBattle() Future~bool~
        +enterArenaNow() Future~void~
        +submitPlayer1Answer() Future~void~
        +submitPlayer2Answer() Future~void~
        +restoreTurnFromRewardedAd() Future~void~
    }
    class MetronomeNotifier {
        -Stopwatch _stopwatch
        -TapTempoCalculator _tapCalculator
        +setBpm(int) void
        +setTimeSignature(int, int) void
        +setSubdivision(int) void
        +cycleBeatState(int) void
        +togglePlayPause() Future~void~
    }
    class RewardedAdNotifier {
        +int kOneHourPracticeGemCost = 200
        +int kUnlimitedPracticeGemCost = 350
        +int kGuitarProScaleGemCost = 300
        +int kSingleBattleTurnGemCost = 200
        +completeWatchingAd() Future~void~
        +spendGemsForOneHourSession() Future~bool~
        +spendGemsForUnlimitedSession() Future~bool~
        +spendPrestigePointsForTurns() Future~bool~
    }
    class HybridQuestionGenerator {
        +buildSessionQuestions() List~QuestionModel~
    }
    class SolfaIntegrityGuard {
        +computeSignature() String
        +verifySignature() bool
        +checkAndAdvanceMonotonicClock() bool
    }

    PracticeSessionNotifier --> QuestionModel : manages
    PracticeSessionNotifier --> HybridQuestionGenerator : delegates
    BattleNotifier --> QuestionModel : uses
    RewardedAdNotifier --> SolfaIntegrityGuard : verifies
```

---

## 11. THIẾT KẾ HẠT NHÂN ÂM THANH 44.1kHz PCM DSP & BỘ SINH CÂU HỎI HYBRID
* **Tổng hợp âm thanh DSP Zero-Click (`tool/generate_audio_assets.py`)**: Toàn bộ 283+ tệp âm thanh `.wav` (Grand Piano, Guitar Acoustic Karplus-Strong, Guitar Electric Overdrive, Vòng hòa âm, Backing Track Jam và tiếng gõ Metronome) được tổng hợp ở tần số lấy mẫu `44.100 Hz`, `16-bit Mono PCM`, áp dụng đường bao biên độ (ADSR Envelope) và fade-out `15ms` cuối mẫu để triệt tiêu hoàn toàn tiếng nổ bốp (Zero-Click).
* **Thuật toán Sinh câu hỏi Hybrid (`HybridQuestionGenerator`)**:
  * Duy trì bộ nhớ đệm `_recentQuestionIdsByPool` với kích thước cửa sổ trượt bằng **65% tổng số câu hỏi của cấp độ** (`(pool.length * 0.65).round()`), đảm bảo người học làm liên tiếp hàng chục câu không gặp lại câu vừa xuất hiện.
  * Tự động lấy mẫu ngẫu nhiên 3 đáp án nhiễu (Dynamic Distractors) từ cùng nhóm hợp âm/cần đàn và đảo vị trí A/B/C/D cân bằng.

---

## 12. THIẾT KẾ MÁY ĐẾM NHỊP CƠ HỌC (<10ms) & SƠ ĐỒ MÁY TRẠNG THÁI (UML STATE MACHINE)

### 12.1. Hình 10 — Sơ đồ Máy Trạng Thái Đấu Trường 1v1 & Máy Đếm Nhịp Cơ Học
![Hình 10 - Sơ đồ Máy Trạng Thái](docs/uml/uml_10_state_machine.png)

```mermaid
stateDiagram-v2
    [*] --> Lobby : Mở Đấu Trường (/battle)
    Lobby --> Matchmaking : startBattle() [Còn lượt > 0]
    Matchmaking --> VsIntro : Ghép đối thủ / Khởi tạo Bot AI
    VsIntro --> Fighting : enterArenaNow() (100 HP vs 100 HP)
    Fighting --> Fighting : Hiệp tiếp theo (Chưa K.O. & Hiệp <= 8)
    Fighting --> Finished : Một bên về 0 HP (K.O.) hoặc Hết 8 hiệp
    Finished --> Lobby : backToLobby()
```

---

## 13. HỆ SINH THÁI KINH TẾ GEM, QUẢNG CÁO CÓ THƯỞNG & BẢO MẬT (`SolfaIntegrityGuard`)
__T_GEMS__

---

## 14. YÊU CẦU PHI CHỨC NĂNG & TUÂN THỦ PHÁP LÝ QUỐC TẾ (EU 2018/302 & GDPR)
* **Hiệu năng 60fps**: Bọc các thành phần đồ họa phức tạp (Khuông nhạc `StaffQuestionWidget`, Bàn phím Piano `PianoKeyboardAnswerWidget`, Cần đàn Guitar `GuitarQuestionBoardWidget`, Máy đếm nhịp) trong `RepaintBoundary` để cô lập vùng vẽ lại.
* **Tuân thủ Quy định (EU) 2018/302 (Chống chặn địa lý - Geo-blocking Regulation)**: Cung cấp quyền truy cập bình đẳng tại 27 quốc gia EU/EEA và hơn 174 quốc gia trên Google Play; tự động nhận diện vùng và chuyển đổi ngôn ngữ *Tiếng Việt / Tiếng Anh Quốc tế* hoàn toàn ngoại tuyến qua `PlatformDispatcher.instance.locale` mà không cần GPS.

---

## 15. XỬ LÝ LỖI, VÒNG ĐỜI ỨNG DỤNG (LIFECYCLE) & TÌNH HUỐNG NGOẠI LỆ
* **Quản lý vòng đời (`WidgetsBindingObserver`)**: Các màn hình có bộ đếm nhịp hoặc vòng lặp âm thanh (`MetronomeScreen`, `GuitarStudioSheet`, `BattleScreen`, `QuizScreen`) tự động tạm dừng âm thanh và hủy `Timer` ngay khi ứng dụng chuyển sang trạng thái `AppLifecycleState.paused` hoặc `detached`.
* **Chống lỗi mất tệp âm thanh (`AssetValidator`)**: Tự động kiểm tra sự tồn tại của tệp `.wav` trước khi phát; nếu thiết bị tắt tiếng hoặc lỗi phần cứng âm thanh, câu hỏi vẫn hiển thị đầy đủ gợi ý trực quan để người dùng không bị kẹt phiên học.

---

## 16. KIỂM THỬ TỰ ĐỘNG & TIÊU CHÍ NGHIỆM THU (23 TEST CASES TC-01 -> TC-23)
__T_TESTS__

---

## 17. LỘ TRÌNH PHÁT TRIỂN SẢN PHẨM (ROADMAP)
* **Giai đoạn 1 (v1.0 – Hoàn thành)**: Khung kiến trúc Offline-first SQLite, 3 chủ đề cảm âm cơ bản, Ôn tập câu sai và Máy đếm nhịp.
* **Giai đoạn 2 (v1.5 – Hoàn thành)**: Mở rộng 7 chủ đề Cảm âm & Khuông nhạc Sol/Fa, Đàn Piano Studio C3–C5 và Chép nhạc giai điệu.
* **Giai đoạn 3 (v1.8 -> v1.9.4+26 – Hoàn thành)**: Hoàn thiện 4 chủ đề Guitar (81 câu hỏi Hợp âm mở/chặn/7th/Sus/Add9/Power/Capo), Guitar Studio (Thùng & Điện, So dây Hz, Jam Track, 12 Bài luyện ngón), Đấu Trường 1v1, Kinh tế Gem mới và Bảo mật `SolfaIntegrityGuard`.
* **Giai đoạn 4 (Định hướng v2.0)**: Tích hợp giao diện Neo-Glass Studio 2.0 và phân tích cao độ giọng hát/nhạc cụ thực tế qua Microphone FFT Offline.

---

## 18. RỦI RO KỸ THUẬT VÀ GIẢI PHÁP
1. **Rủi ro trễ nhịp Metronome khi hệ điều hành tiết kiệm pin**: Giải pháp — Sử dụng `Stopwatch` độ phân giải micro-giây kết hợp lịch bù trễ động thay vì dùng `Timer.periodic` cố định.
2. **Rủi ro người dùng chỉnh giờ thiết bị để nhận thưởng nhiệm vụ ngày nhiều lần**: Giải pháp — Tích hợp `SolfaIntegrityGuard.checkAndAdvanceMonotonicClock()` kiểm tra mốc thời gian đơn điệu và chữ ký băm SHA-256 Salted.
3. **Rủi ro tràn chữ (`...`) trên màn hình điện thoại nhỏ hoặc cỡ chữ lớn**: Giải pháp — Thiết kế lại Header tinh gọn, kết hợp `FittedBox(fit: BoxFit.scaleDown)` và kiểm thử tự động trên khung nhìn `360x680` (`TC-17`).

---

## 19. KẾT LUẬN
Tài liệu Phân tích & Thiết kế Hệ thống (SRS & SDD v2.0) cùng trọn bộ **10 sơ đồ UML 2.5** đã phản ánh chính xác, đầy đủ và đồng bộ 100% kiến trúc thực tế của ứng dụng **ChaoNote (Solfa v1.9.4+26)**. Hệ thống vượt qua toàn bộ 16/16 nhóm kiểm thử tự động (`TC-01` đến `TC-23`), đạt 0 cảnh báo tĩnh (`flutter analyze`) và sẵn sàng triển khai trên Google Play Console.
"""
    content = (
        content.replace("__T_DOC_INFO__", t_doc_info)
        .replace("__T_CHANGELOG__", t_changelog)
        .replace("__T_TOPICS__", t_topics)
        .replace("__T_RULES__", t_rules)
        .replace("__T_GEMS__", t_gems)
        .replace("__T_TESTS__", t_tests)
    )
    md_path.write_text(content, encoding="utf-8")
    print(f"Generated Markdown SRS/SDD: {md_path} ({md_path.stat().st_size // 1024} KB)")
    return md_path


# ==============================================================================
# WORD (.DOCX) GENERATOR WITH EMBEDDED HIGH-RES UML DIAGRAMS
# ==============================================================================
def set_cell_bg(cell, hex_color: str):
    shading = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{hex_color}"/>')
    cell._tc.get_or_add_tcPr().append(shading)


def add_styled_table(doc: Document, headers: list, rows: list):
    table = doc.add_table(rows=1, cols=len(headers))
    table.style = "Table Grid"
    table.alignment = WD_TABLE_ALIGNMENT.CENTER

    hdr_cells = table.rows[0].cells
    for i, h_text in enumerate(headers):
        hdr_cells[i].text = ""
        p = hdr_cells[i].paragraphs[0]
        run = p.add_run(h_text)
        run.bold = True
        run.font.size = Pt(10.5)
        run.font.color.rgb = RGBColor(255, 255, 255)
        set_cell_bg(hdr_cells[i], "1E3A8A")

    for r_idx, row_data in enumerate(rows):
        row_cells = table.add_row().cells
        bg = "F8FAFC" if r_idx % 2 == 1 else "FFFFFF"
        for c_idx, val in enumerate(row_data):
            row_cells[c_idx].text = ""
            p = row_cells[c_idx].paragraphs[0]
            run = p.add_run(str(val))
            run.font.size = Pt(10)
            if c_idx == 0:
                run.bold = True
                run.font.color.rgb = RGBColor(30, 58, 138)
            set_cell_bg(row_cells[c_idx], bg)
    doc.add_paragraph()


def add_uml_figure(doc: Document, img_path: Path, caption: str):
    p_img = doc.add_paragraph()
    p_img.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run_img = p_img.add_run()
    run_img.add_picture(str(img_path), width=Inches(6.45))

    p_cap = doc.add_paragraph()
    p_cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run_cap = p_cap.add_run(caption)
    run_cap.italic = True
    run_cap.bold = True
    run_cap.font.size = Pt(10)
    run_cap.font.color.rgb = RGBColor(30, 58, 138)


def add_heading_1(doc: Document, text: str):
    h = doc.add_heading(text, level=1)
    for r in h.runs:
        r.font.color.rgb = RGBColor(30, 58, 138)
        r.font.size = Pt(15)


def add_heading_2(doc: Document, text: str):
    h = doc.add_heading(text, level=2)
    for r in h.runs:
        r.font.color.rgb = RGBColor(37, 99, 235)
        r.font.size = Pt(12.5)


def add_bullets(doc: Document, items: list):
    for item in items:
        p = doc.add_paragraph(style="List Bullet")
        if ":" in item:
            head, tail = item.split(":", 1)
            r1 = p.add_run(head + ":")
            r1.bold = True
            r2 = p.add_run(tail)
        else:
            p.add_run(item)


def generate_word_docx():
    docx_path = ROOT / "Phân tích thiết kế hệ thống Solfa.docx"
    doc = Document()

    # Page margins (narrow academic A4 margins so UML diagrams are wide & crisp)
    for section in doc.sections:
        section.top_margin = Inches(0.7)
        section.bottom_margin = Inches(0.7)
        section.left_margin = Inches(0.75)
        section.right_margin = Inches(0.75)

    # Cover / Header Block
    p_brand = doc.add_paragraph()
    p_brand.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_b = p_brand.add_run("CHAONOTE (SOLFA v1.9.4+26)\n")
    r_b.bold = True
    r_b.font.size = Pt(22)
    r_b.font.color.rgb = RGBColor(30, 58, 138)

    r_sub = p_brand.add_run("TÀI LIỆU PHÂN TÍCH YÊU CẦU & THIẾT KẾ HỆ THỐNG (SRS & SDD v2.0)\n")
    r_sub.bold = True
    r_sub.font.size = Pt(15)
    r_sub.font.color.rgb = RGBColor(37, 99, 235)

    r_desc = p_brand.add_run(
        "Ứng dụng Luyện Cảm Âm, Đọc Khuông Nhạc Sol/Fa, Piano & Guitar Studio, Đấu Trường 1v1 và Máy Đếm Nhịp Cơ Học\n"
        "Nền tảng: Flutter (Android & iOS)  |  Mô hình: 100% Offline-First  |  Kèm Trọn Bộ 10 Sơ Đồ Thiết Kế UML 2.5\n"
        "Phiên bản tài liệu: 2.0  |  Ngày cập nhật: 18/11/2026"
    )
    r_desc.font.size = Pt(10.5)
    r_desc.font.color.rgb = RGBColor(71, 85, 105)

    add_heading_2(doc, "THÔNG TIN QUẢN LÝ TÀI LIỆU")
    add_styled_table(doc, ["Thuộc tính", "Mô tả chi tiết"], DOC_INFO_ROWS)

    add_heading_2(doc, "LỊCH SỬ THAY ĐỔI (REVISION HISTORY)")
    add_styled_table(doc, ["Phiên bản", "Ngày", "Nội dung cập nhật"], CHANGELOG_ROWS)

    # Chapter 1
    add_heading_1(doc, "1. TỔNG QUAN DỰ ÁN")
    doc.add_paragraph(
        "ChaoNote (Solfa) là ứng dụng di động hỗ trợ người dùng rèn luyện khả năng cảm âm (Ear Training), "
        "thị tấu đọc nốt trên khuông nhạc 5 dòng kẻ (Khóa Sol & Khóa Fa), luyện tập hợp âm và kỹ thuật trên "
        "Đàn Piano Studio (C3–C5) cũng như Đàn Guitar Studio (Acoustic & Electric), thi đấu phản xạ tại "
        "Đấu Trường Âm Nhạc 1v1 và giữ nhịp với Máy đếm nhịp cơ học (Mechanical Metronome) độ trễ dưới 10ms."
    )
    add_bullets(
        doc,
        [
            "Đơn giản & Trực quan trước tiên: Mở ứng dụng là có thể bắt đầu học ngay qua thẻ Hero 'Tiếp tục bài học' mà không cần đăng ký tài khoản.",
            "Học qua Nghe & Tương tác Nhạc cụ: Tích hợp 283+ tệp âm thanh 44.1kHz 16-bit PCM WAV được tổng hợp bằng thuật toán DSP Zero-Click độc quyền.",
            "100% Offline-First & Bảo mật cục bộ: Toàn bộ bài học, âm thanh, thống kê SQLite và bảo mật chống gian lận SolfaIntegrityGuard (SHA-256) hoạt động ngoại tuyến.",
            "Đồng nhất giao diện Sáng / Tối & Không cắt chữ: Thanh Header tinh gọn, hộp thoại xác nhận nút ngang đối xứng và độ tương phản chuẩn trên mọi kích thước màn hình.",
            "Kinh tế Gem & Quảng cáo tự nguyện: Không hiển thị quảng cáo cưỡng bức; người dùng chủ động làm nhiệm vụ ngày hoặc xem video ngắn 15s để nhận Gem.",
        ],
    )

    # Chapter 2
    add_heading_1(doc, "2. MỤC TIÊU VÀ PHẠM VI HỆ THỐNG (11 CHỦ ĐỀ & 35 CẤP ĐỘ)")
    doc.add_paragraph(
        "Phiên bản v1.9.4+26 mở rộng phạm vi hệ thống lên 11 chủ đề học tập chính thức (7 chủ đề Cảm âm & Khuông nhạc Piano + "
        "4 chủ đề Guitar chuyên sâu) với tổng cộng 35 cấp độ và kho 81 câu hỏi Hợp âm Guitar & Piano:"
    )
    add_styled_table(
        doc,
        ["Chủ đề (Topic ID)", "Phân nhóm", "Số cấp độ", "Nội dung học thuật & Tương tác"],
        TOPICS_11_ROWS,
    )

    # Chapter 3
    add_heading_1(doc, "3. ĐỐI TƯỢNG SỬ DỤNG (ACTORS) VÀ NHU CẦU")
    add_bullets(
        doc,
        [
            "Người học nhạc (Primary Actor): Người mới học nhạc lý, người tự học Piano/Guitar, học viên luyện thi cảm âm cần lộ trình từ Cơ bản đến Nâng cao.",
            "Người chơi thứ 2 (Local Split-Screen Actor): Bạn bè cùng tranh tài phản xạ cảm âm trực tiếp trên 1 thiết bị ở chế độ Đấu 2 Người 1 Máy.",
            "Hạt nhân Âm thanh DSP & SQLite (Local Engine Actor): Cung cấp truy vấn dữ liệu tức thì và phát âm thanh đa âm (Polyphonic Pool) độ trễ thấp.",
            "Hệ thống Quảng cáo Có thưởng & SolfaIntegrityGuard: Xử lý thưởng +100 Gem khi xem video 15s và kiểm định chữ ký số SHA-256 chống chỉnh lùi giờ.",
        ],
    )

    # Chapter 4
    add_heading_1(doc, "4. NGUYÊN TẮC TRẢI NGHIỆM & GIAO DIỆN NGƯỜI DÙNG (UX/UI)")
    add_bullets(
        doc,
        [
            "Thiết kế Header thông minh không cắt chữ (...): Chỉ hiển thị Logo tại Tab Trang chủ (ChaoNote); 3 tab Phòng luyện tập, Máy đếm nhịp và Tiến trình ẩn Logo lặp lại để tiêu đề luôn hiển thị đủ 100%. Huy hiệu góc phải hiển thị gọn [💎 Số dư] và [🔥 Chuỗi ngày].",
            "Header Đấu Trường 1v1 tinh gọn: Hiển thị '[←] [⚔️] Đấu Trường 1v1' cùng duy nhất 1 pill năng lượng '[⚡ 5/5]' bên phải, loại bỏ thông tin Sao trùng lặp với thẻ Hạng bên dưới.",
            "Popup xác nhận nút ngang đối xứng: Mọi hộp thoại xác nhận (Thoát phiên học, Xóa lịch sử học tập, Đặt lại mẫu nhịp) đều bố trí các nút hành động nằm ngang cân đối bằng Row + Expanded.",
            "Đồng bộ tương phản Light Mode & Dark Mode: Các nút OutlinedButton trên nền thẻ tối sử dụng lớp kính mờ (translucent glass) với chữ trắng sắc nét; các nút chọn trong Cài đặt hiển thị rõ trạng thái đang chọn ở cả hai chế độ.",
        ],
    )

    # Chapter 5
    add_heading_1(doc, "5. KIẾN TRÚC CHỨC NĂNG TỔNG THỂ & SƠ ĐỒ USE CASE (UML)")
    doc.add_paragraph(
        "Hệ thống ChaoNote được chia thành 4 phân hệ nghiệp vụ chính kết nối chặt chẽ với nhau qua tầng quản lý trạng thái Riverpod. "
        "Dưới đây là Sơ đồ Use Case Tổng Quát (Hình 1) và Sơ đồ Luồng Điều Hướng Màn Hình GoRouter (Hình 3):"
    )
    add_uml_figure(
        doc,
        UML_DIR / "uml_01_use_case.png",
        "Hình 1: Sơ đồ Use Case Tổng Quát & Phân Rã 4 Phân Hệ Nghiệp Vụ của ChaoNote (Solfa v1.9.4+26)",
    )
    add_uml_figure(
        doc,
        UML_DIR / "uml_03_navigation.png",
        "Hình 3: Sơ đồ Luồng Điều Hướng Màn Hình (GoRouter StatefulShellRoute 4 Tab + Diamond Battle CTA + Studios)",
    )

    # Chapter 6
    add_heading_1(doc, "6. ĐẶC TẢ CHỨC NĂNG CHI TIẾT")
    add_bullets(
        doc,
        [
            "Phân hệ Trang chủ (/home): Hiển thị chuỗi ngày học, thẻ Hero 'Tiếp tục bài học', cụm 4 tiện ích nhanh (Đàn Piano, Đàn Guitar, Ôn câu sai, Đấu trường), thanh Mục tiêu hôm nay (+20 Gem) và bảng 3 Nhiệm vụ hàng ngày (+100 Gem).",
            "Phân hệ Phòng luyện tập & Phòng thi (/topics, /quiz, /session-result): Hỗ trợ 4 chế độ thời gian (60 giây Miễn phí, 15 phút Miễn phí, 1 tiếng 200 Gem, Tự do 350 Gem). Hỗ trợ trả lời bằng thẻ A/B/C/D, phím đàn Piano C3–C5 hoặc cần đàn Guitar 6 dây kèm nhãn 'Chặn 1' cho hợp âm chặn.",
            "Phân hệ Piano Studio (C3–C5): Đàn tự do 25 phím đa âm, hiển thị nốt trực tiếp trên khuông Khóa Sol và bài tập Chép nhạc giai điệu (Melodic Dictation).",
            "Phân hệ Guitar Studio (Acoustic & Electric): Chuyển đổi tiếng Guitar Thùng / Guitar Điện, tra cứu 44 hợp âm, bộ so dây 6 dây chuẩn Hz có chế độ Loop, vòng hòa âm tự động, phòng Jam Backing Track, bản đồ Scale 12 ngăn (mở khóa VIP 300 Gem) và 12 bài luyện ngón (36 Sao).",
            "Phân hệ Đấu Trường Âm Nhạc 1v1 (/battle): Gồm 3 chế độ (Đấu Hạng 1v1, Đấu Máy AI 4 cấp độ, Đấu 2 Người 1 Máy chia đôi màn hình), hệ thống máu 100 HP, bạo kích Combo, hiệu ứng sét đánh và 6 bậc xếp hạng Sao.",
        ],
    )

    # Chapter 7
    add_heading_1(doc, "7. LUỒNG NGHIỆP VỤ CHÍNH (UML SEQUENCE & ACTIVITY DIAGRAMS)")
    doc.add_paragraph(
        "Các luồng tương tác thời gian thực giữa Người dùng, Giao diện, Riverpod StateNotifiers, Bộ sinh câu hỏi Hybrid, "
        "Dịch vụ Âm thanh DSP và Cơ sở dữ liệu SQLite được mô hình hóa chi tiết qua các sơ đồ Tuần tự (Hình 6, Hình 7, Hình 8) "
        "và sơ đồ Hoạt động (Hình 9):"
    )
    add_uml_figure(
        doc,
        UML_DIR / "uml_06_seq_practice.png",
        "Hình 6: Sơ đồ Tuần tự (Sequence Diagram 1) — Luồng Phiên Luyện Tập, Sinh Câu Hỏi Hybrid 65% Window & Lưu Lịch Sử",
    )
    add_uml_figure(
        doc,
        UML_DIR / "uml_07_seq_battle.png",
        "Hình 7: Sơ đồ Tuần tự (Sequence Diagram 2) — Luồng Đấu Trường Âm Nhạc 1v1, Bot AI 4 Cấp & Tính Sát Thương HP/Combo",
    )
    add_uml_figure(
        doc,
        UML_DIR / "uml_08_seq_gem_economy.png",
        "Hình 8: Sơ đồ Tuần tự (Sequence Diagram 3) — Luồng Kinh Tế Gem, Xem Video Quảng Cáo & Bảo Mật SolfaIntegrityGuard",
    )
    add_uml_figure(
        doc,
        UML_DIR / "uml_09_activity.png",
        "Hình 9: Sơ đồ Hoạt động (Activity Diagram) — Quy tắc Ôn Tập 'Đúng 2 Lần Liên Tiếp' & Luồng Tương Tác Piano/Guitar Studio",
    )

    # Chapter 8
    add_heading_1(doc, "8. QUY TẮC NGHIỆP VỤ (BUSINESS RULES)")
    add_styled_table(
        doc,
        ["Mã quy tắc", "Tên quy tắc nghiệp vụ", "Đặc tả kỹ thuật chi tiết"],
        BUSINESS_RULES_ROWS,
    )

    # Chapter 9
    add_heading_1(doc, "9. THIẾT KẾ DỮ LIỆU OFFLINE-FIRST (UML ERD)")
    doc.add_paragraph(
        "Hệ thống lưu trữ cục bộ kết hợp 9 bảng quan hệ chuẩn hóa trong SQLite (solfa_offline.db) cho dữ liệu học thuật/lịch sử "
        "và kho khóa bảo mật SharedPreferences có chữ ký SHA-256 cho Ví Gem, Sao Đấu Trường và Tiến độ Luyện ngón Guitar:"
    )
    add_uml_figure(
        doc,
        UML_DIR / "uml_05_erd.png",
        "Hình 5: Sơ đồ Thực Thể Liên Kết Cơ Sở Dữ Liệu Cục Bộ (SQLite ERD 9 Bảng & Kho Bảo Mật SharedPreferences)",
    )

    # Chapter 10
    add_heading_1(doc, "10. KIẾN TRÚC KỸ THUẬT FLUTTER & SƠ ĐỒ LỚP (UML ARCHITECTURE & CLASS DIAGRAM)")
    doc.add_paragraph(
        "Ứng dụng tuân thủ kiến trúc phân tầng Clean Feature-First gồm 4 tầng rõ rệt (Presentation -> Application Riverpod -> "
        "Domain Engine -> Data & Infrastructure). Hình 2 và Hình 4 mô tả chi tiết cấu trúc thành phần và quan hệ giữa các lớp:"
    )
    add_uml_figure(
        doc,
        UML_DIR / "uml_02_architecture.png",
        "Hình 2: Sơ đồ Kiến trúc Phân tầng & Thành phần Hệ thống Flutter (Component & Layered Architecture)",
    )
    add_uml_figure(
        doc,
        UML_DIR / "uml_04_class_diagram.png",
        "Hình 4: Sơ đồ Lớp Chi Tiết (UML Class Diagram — Domain Entities, Riverpod StateNotifiers & Infrastructure Services)",
    )

    # Chapter 11
    add_heading_1(doc, "11. THIẾT KẾ ÂM THANH 44.1kHz PCM DSP VÀ BỘ SINH CÂU HỎI HYBRID")
    add_bullets(
        doc,
        [
            "Tổng hợp âm thanh DSP Zero-Click (283+ tệp WAV): Toàn bộ mẫu âm Piano, Guitar Acoustic, Guitar Electric, hợp âm chặn, hợp âm 7, hợp âm màu, Power Chord và tiếng gõ Metronome được tổng hợp ở chuẩn 44.1kHz 16-bit PCM WAV kèm xử lý triệt tiêu xung nhiễu đầu/cuối mẫu.",
            "Cửa sổ chống lặp 65% (Anti-Repeat Sliding Window): HybridQuestionGenerator duy trì hàng đợi FIFO lưu 65% số câu hỏi vừa xuất hiện trong từng cấp độ để loại trừ khỏi lần bốc thăm kế tiếp.",
            "Lấy mẫu đáp án nhiễu động (Dynamic Distractor Sampling): Với các bài nhận diện Hợp âm Guitar và Nốt trên cần đàn, hệ thống tự động chọn ngẫu nhiên 3 đáp án sai từ kho hợp âm cùng cấp độ và cân bằng vị trí A/B/C/D.",
        ],
    )

    # Chapter 12
    add_heading_1(doc, "12. THIẾT KẾ MÁY ĐẾM NHỊP CƠ HỌC (<10ms) & SƠ ĐỒ MÁY TRẠNG THÁI")
    doc.add_paragraph(
        "Máy đếm nhịp cơ học sử dụng đồng hồ đo vi giây (Stopwatch Microsecond) kết hợp cơ chế bù trễ động giúp duy trì độ lệch nhịp "
        "dưới 10ms trên toàn dải tốc độ 30–300 BPM. Hình 10 biểu diễn Máy trạng thái của Đấu Trường 1v1 và Máy đếm nhịp:"
    )
    add_uml_figure(
        doc,
        UML_DIR / "uml_10_state_machine.png",
        "Hình 10: Sơ đồ Máy Trạng Thái (UML State Machine) — Vòng Đời Đấu Trường 1v1 (BattlePhase) & Máy Đếm Nhịp Cơ Học",
    )

    # Chapter 13
    add_heading_1(doc, "13. KINH TẾ GEM, QUẢNG CÁO CÓ THƯỞNG VÀ HỖ TRỢ NHÀ PHÁT TRIỂN")
    doc.add_paragraph(
        "Hệ thống kinh tế Gem nội bộ được thiết kế cân bằng giữa quyền lợi học tập miễn phí và động lực xem video quảng cáo ủng hộ nhà phát triển:"
    )
    add_styled_table(
        doc,
        ["Hoạt động / Tính năng", "Loại", "Định mức Gem", "Mô tả cơ chế vận hành"],
        GEM_ECONOMY_ROWS,
    )

    # Chapter 14
    add_heading_1(doc, "14. YÊU CẦU PHI CHỨC NĂNG & TUÂN THỦ PHÁP LÝ QUỐC TẾ")
    add_bullets(
        doc,
        [
            "Hiệu năng đồ họa 60fps: Sử dụng RepaintBoundary cô lập khuông nhạc, bàn phím Piano, cần đàn Guitar và đèn phách Metronome.",
            "Đồng bộ Cài đặt 2 chiều: Mọi thay đổi tại màn hình Cài đặt hệ thống (Thời gian luyện tập mặc định, Âm sắc Metronome, Ngôn ngữ, Giao diện Sáng/Tối) đồng bộ hai chiều với các màn hình chức năng và lưu bền vững vào SQLite.",
            "Tuân thủ Quy định (EU) 2018/302, GDPR & Nghị định 13/2023/NĐ-CP: Hỗ trợ 174+ quốc gia không phân biệt vùng địa lý, không thu thập dữ liệu định danh cá nhân và cho phép xóa sạch lịch sử học tập cục bộ bất kỳ lúc nào.",
        ],
    )

    # Chapter 15
    add_heading_1(doc, "15. XỬ LÝ LỖI, VÒNG ĐỜI ỨNG DỤNG VÀ TÌNH HUỐNG NGOẠI LỆ")
    add_bullets(
        doc,
        [
            "Tạm dừng tự động khi ẩn ứng dụng (WidgetsBindingObserver): Khi có cuộc gọi đến hoặc khóa màn hình, ứng dụng tự động tạm dừng Metronome, Vòng hợp âm, Jam Track và bộ đếm thời gian Đấu Trường.",
            "Kiểm tra toàn vẹn tài nguyên âm thanh (AssetValidator): Xác thực đường dẫn WAV trước khi phát; nếu thiết bị lỗi âm thanh vẫn hiển thị đầy đủ gợi ý trực quan để không làm kẹt phiên học.",
            "Phát hiện chỉnh lùi giờ hệ thống (Monotonic Clock Guard): Tự động khóa nhận thưởng nhiệm vụ trùng lặp nếu phát hiện đồng hồ thiết bị bị chỉnh lùi.",
        ],
    )

    # Chapter 16
    add_heading_1(doc, "16. KIỂM THỬ TỰ ĐỘNG VÀ TIÊU CHÍ NGHIỆM THU (TC-01 ĐẾN TC-23)")
    doc.add_paragraph(
        "Hệ thống được kiểm định tự động toàn diện bằng bộ kiểm thử tích hợp (test/widget_test.dart) gồm 23 kịch bản nghiệm thu (TC-01 đến TC-23), đạt tỷ lệ vượt qua 100%:"
    )
    add_styled_table(
        doc,
        ["Mã TC", "Tên kịch bản kiểm thử", "Nội dung & Tiêu chí nghiệm thu", "Trạng thái"],
        TEST_CASES_23_ROWS,
    )

    # Chapter 17
    add_heading_1(doc, "17. LỘ TRÌNH PHÁT TRIỂN SẢN PHẨM (ROADMAP)")
    add_bullets(
        doc,
        [
            "Phiên bản v1.0 (Hoàn thành): Kiến trúc SQLite Offline-first, 3 chủ đề cảm âm cơ bản, Ôn tập câu sai và Máy đếm nhịp.",
            "Phiên bản v1.5 (Hoàn thành): 7 chủ đề Cảm âm & Khuông nhạc Sol/Fa, Piano Studio C3–C5 và Chép nhạc giai điệu.",
            "Phiên bản v1.9.4+26 (Hiện tại – Hoàn thành): 11 chủ đề (81 câu Hợp âm Guitar & Piano), Guitar Studio (Thùng/Điện, So dây Hz, Jam Track, 12 Bài luyện ngón), Đấu Trường 1v1, Kinh tế Gem mới và Bảo mật SolfaIntegrityGuard.",
            "Phiên bản v2.0 (Tương lai): Giao diện Neo-Glass Studio 2.0 và nhận diện cao độ âm thanh thực tế qua Microphone FFT Offline.",
        ],
    )

    # Chapter 18
    add_heading_1(doc, "18. RỦI RO KỸ THUẬT VÀ GIẢI PHÁP GIẢM THIỂU")
    add_bullets(
        doc,
        [
            "Rủi ro trễ nhịp Metronome do bộ lập lịch OS: Giải pháp — Dùng Stopwatch vi giây kết hợp phép tính bù thời gian động cho từng xung phách.",
            "Rủi ro gian lận điểm Gem hoặc chỉnh giờ thiết bị khi Offline: Giải pháp — Áp dụng chữ ký số SHA-256 Salted và Monotonic Clock Guard trong SolfaIntegrityGuard.",
            "Rủi ro cắt chữ (...) trên màn hình hẹp 360dp: Giải pháp — Tinh gọn Header, sử dụng FittedBox tự động co giãn và kiểm thử tự động trên khung nhìn 360x680 (TC-17).",
        ],
    )

    # Chapter 19
    add_heading_1(doc, "19. KẾT LUẬN")
    doc.add_paragraph(
        "Tài liệu Phân tích & Thiết kế Hệ thống (SRS & SDD v2.0) cùng 10 sơ đồ UML 2.5 đã mô tả đầy đủ, chính xác và đồng bộ 100% "
        "với mã nguồn thực tế của ứng dụng ChaoNote (Solfa v1.9.4+26). Sản phẩm đáp ứng trọn vẹn các yêu cầu chức năng, phi chức năng, "
        "hiệu năng 60fps, bảo mật ngoại tuyến và tiêu chuẩn phát hành quốc tế trên Google Play Console."
    )

    doc.save(str(docx_path))
    print(f"Generated Word SRS/SDD (.docx): {docx_path} ({docx_path.stat().st_size // 1024} KB)")
    return docx_path


if __name__ == "__main__":
    generate_all_uml_images()
    generate_markdown_doc()
    generate_word_docx()

