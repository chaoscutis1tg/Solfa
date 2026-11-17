#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generates high-resolution Modern Minimalist Studio branding & Google Play Store Listing assets for ChaoNote:
1. store_listing/app_icon_512x512.png (512x512) + assets/images/solfa_logo.png + Android mipmap ic_launcher.png
2. store_listing/feature_graphic_1024x500.png (1024x500)
3. 4 Full-HD Store Screenshots (1080x1920) showcasing the redesigned ChaoNote UI:
   - screenshot_1_bang_diem_sang.png (Trang chủ 4 khối tinh gọn & Mục tiêu +20 Gem)
   - screenshot_2_cai_dat_am_thanh.png (Luyện đọc nốt Khuông nhạc + Dòng kẻ phụ & Đàn Piano C3-C5)
   - screenshot_3_che_do_toi_dark_mode.png (Guitar Studio: Cần đàn 6 dây, Hợp âm & Rải Ballad sáng đèn)
   - screenshot_4_dau_truong_1v1_split.png (Đấu Trường Âm Nhạc 1v1: Đấu độc lập, Combo Sét Đánh & 180° Split-Screen)
"""

import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORE_DIR = os.path.join(BASE_DIR, "store_listing")
ASSETS_IMG_DIR = os.path.join(BASE_DIR, "assets", "images")
ANDROID_RES_DIR = os.path.join(BASE_DIR, "android", "app", "src", "main", "res")


def load_font(size: int, bold: bool = True) -> ImageFont.FreeTypeFont:
    candidates = [
        r"C:\Windows\Fonts\segoeuib.ttf" if bold else r"C:\Windows\Fonts\segoeui.ttf",
        r"C:\Windows\Fonts\arialbd.ttf" if bold else r"C:\Windows\Fonts\arial.ttf",
        r"C:\Windows\Fonts\calibrib.ttf" if bold else r"C:\Windows\Fonts\calibri.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            return ImageFont.truetype(path, size=size)
    return ImageFont.load_default()


def make_vertical_gradient(
    w: int, h: int, top_rgb: tuple[int, int, int], bot_rgb: tuple[int, int, int]
) -> Image.Image:
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        r = int(top_rgb[0] * (1 - t) + bot_rgb[0] * t)
        g = int(top_rgb[1] * (1 - t) + bot_rgb[1] * t)
        b = int(top_rgb[2] * (1 - t) + bot_rgb[2] * t)
        for x in range(w):
            px[x, y] = (r, g, b, 255)
    return img


def draw_gem_diamond(draw: ImageDraw.ImageDraw, cx: int, cy: int, r: int) -> None:
    pts = [(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)]
    draw.polygon(pts, fill=(56, 189, 248, 255), outline=(224, 242, 254, 255))


def draw_crossed_swords(draw: ImageDraw.ImageDraw, cx: int, cy: int, r: int) -> None:
    draw.line([(cx - r, cy + r), (cx + r, cy - r)], fill=(255, 255, 255, 255), width=4)
    draw.line([(cx - r, cy - r), (cx + r, cy + r)], fill=(255, 255, 255, 255), width=4)
    draw.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=(251, 191, 36, 255))


def draw_chaonote_emblem(size: int = 512, include_badge: bool = True) -> Image.Image:
    """Draws the Modern Minimalist ChaoNote icon (Indigo/Cyan/Amber Studio Emblem)."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    pad = int(size * 0.04)
    radius = int(size * 0.23)

    # Base gradient squircle
    bg = make_vertical_gradient(size, size, (23, 21, 58), (67, 56, 202))
    mask = Image.new("L", (size, size), 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.rounded_rectangle([pad, pad, size - pad, size - pad], radius=radius, fill=255)
    canvas.paste(bg, (0, 0), mask)

    # Subtle ambient glow circle inside
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.ellipse(
        [int(size * 0.16), int(size * 0.10), int(size * 0.84), int(size * 0.76)],
        fill=(56, 189, 248, 60),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(radius=int(size * 0.06)))
    canvas = Image.alpha_composite(canvas, glow)
    draw = ImageDraw.Draw(canvas)

    # Outer border rim
    draw.rounded_rectangle(
        [pad, pad, size - pad, size - pad],
        radius=radius,
        outline=(129, 140, 248, 200),
        width=max(2, int(size * 0.015)),
    )

    # 5-line subtle staff across middle
    for i in range(5):
        ly = int(size * (0.29 + i * 0.046))
        draw.line(
            [(int(size * 0.14), ly), (int(size * 0.86), ly)],
            fill=(148, 163, 184, 90),
            width=max(1, int(size * 0.005)),
        )

    # Mini Piano Keys motif at bottom-left of emblem
    pk_top = int(size * 0.51)
    pk_bot = int(size * 0.67)
    pk_left = int(size * 0.18)
    key_w = int(size * 0.055)
    for k in range(5):
        kx0 = pk_left + k * (key_w + int(size * 0.008))
        draw.rounded_rectangle(
            [kx0, pk_top, kx0 + key_w, pk_bot],
            radius=int(size * 0.012),
            fill=(248, 250, 252, 245),
        )
    for bk in [0, 1, 3]:
        bx0 = pk_left + (bk + 1) * (key_w + int(size * 0.008)) - int(key_w * 0.38)
        draw.rounded_rectangle(
            [bx0, pk_top, bx0 + int(key_w * 0.65), pk_top + int((pk_bot - pk_top) * 0.60)],
            radius=int(size * 0.008),
            fill=(15, 23, 42, 255),
        )

    # Stylized Golden-Cyan Eighth Note in center-right
    note_cx = int(size * 0.52)
    note_cy = int(size * 0.50)
    rx = int(size * 0.112)
    ry = int(size * 0.085)
    stem_x = note_cx + rx - int(size * 0.022)
    stem_top = int(size * 0.17)
    stem_w = max(4, int(size * 0.044))

    # Stem
    draw.rounded_rectangle(
        [stem_x - stem_w // 2, stem_top, stem_x + stem_w // 2, note_cy],
        radius=stem_w // 2,
        fill=(56, 189, 248, 255),
    )
    # Flag
    flag_pts = [
        (stem_x, stem_top),
        (stem_x + int(size * 0.19), stem_top + int(size * 0.08)),
        (stem_x + int(size * 0.16), stem_top + int(size * 0.20)),
        (stem_x, stem_top + int(size * 0.11)),
    ]
    draw.polygon(flag_pts, fill=(251, 191, 36, 255))

    # Notehead
    draw.ellipse(
        [note_cx - rx, note_cy - ry, note_cx + rx, note_cy + ry],
        fill=(56, 189, 248, 255),
        outline=(255, 255, 255, 240),
        width=max(2, int(size * 0.012)),
    )
    draw.ellipse(
        [note_cx - int(rx * 0.52), note_cy - int(ry * 0.52), note_cx, note_cy],
        fill=(224, 242, 254, 210),
    )

    if include_badge and size >= 128:
        badge_font = load_font(int(size * 0.118), bold=True)
        pill_top = int(size * 0.72)
        pill_bot = int(size * 0.89)
        pill_left = int(size * 0.12)
        pill_right = int(size * 0.88)
        draw.rounded_rectangle(
            [pill_left, pill_top, pill_right, pill_bot],
            radius=int(size * 0.065),
            fill=(15, 23, 42, 245),
            outline=(251, 191, 36, 235),
            width=max(2, int(size * 0.011)),
        )
        draw.text(
            ((pill_left + pill_right) // 2, (pill_top + pill_bot) // 2),
            "ChaoNote",
            font=badge_font,
            fill=(255, 255, 255, 255),
            anchor="mm",
        )

    return canvas


def generate_icons() -> None:
    os.makedirs(STORE_DIR, exist_ok=True)
    os.makedirs(ASSETS_IMG_DIR, exist_ok=True)

    icon_512 = draw_chaonote_emblem(512, include_badge=True)
    icon_512.save(os.path.join(STORE_DIR, "app_icon_512x512.png"), "PNG")
    icon_512.save(os.path.join(STORE_DIR, "image.png"), "PNG")

    logo_256 = draw_chaonote_emblem(256, include_badge=False)
    logo_256.save(os.path.join(ASSETS_IMG_DIR, "solfa_logo.png"), "PNG")

    mipmap_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, px_size in mipmap_sizes.items():
        out_dir = os.path.join(ANDROID_RES_DIR, folder)
        os.makedirs(out_dir, exist_ok=True)
        resized = icon_512.resize((px_size, px_size), Image.Resampling.LANCZOS)
        resized.save(os.path.join(out_dir, "ic_launcher.png"), "PNG")


def generate_feature_graphic() -> None:
    """Generates store_listing/feature_graphic_1024x500.png (1024x500)."""
    w, h = 1024, 500
    banner = make_vertical_gradient(w, h, (15, 23, 42), (30, 27, 75))

    # Add soft indigo & amber studio spotlights
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.ellipse([-80, -60, 460, 480], fill=(79, 70, 229, 95))
    gdraw.ellipse([620, 40, 1080, 520], fill=(217, 119, 6, 70))
    # Subtle 5-line staff on the glow layer so it stays behind cards
    for i in range(5):
        y = 360 + i * 18
        gdraw.line([(0, y), (w, y)], fill=(148, 163, 184, 32), width=2)
    glow = glow.filter(ImageFilter.GaussianBlur(radius=1))
    banner = Image.alpha_composite(banner, glow)
    draw = ImageDraw.Draw(banner)

    # Left: ChaoNote 268x268 Emblem
    emblem = draw_chaonote_emblem(268, include_badge=True)
    banner.alpha_composite(emblem, (48, 86))

    # Pill under emblem
    f_badge = load_font(15, bold=True)
    draw.rounded_rectangle(
        [48, 376, 316, 416],
        radius=20,
        fill=(16, 185, 129, 255),
    )
    draw.text(
        (182, 396),
        "100% OFFLINE • MIỄN PHÍ",
        font=f_badge,
        fill=(255, 255, 255, 255),
        anchor="mm",
    )

    # Right Content Column
    x0 = 352
    f_tag = load_font(15, bold=True)
    f_title = load_font(44, bold=True)
    f_sub = load_font(21, bold=True)
    f_item = load_font(16, bold=True)

    # Top Tag Pill
    draw.rounded_rectangle(
        [x0, 44, x0 + 388, 80],
        radius=18,
        fill=(67, 56, 202, 255),
        outline=(129, 140, 248, 220),
        width=2,
    )
    draw.text(
        (x0 + 194, 62),
        "CHÁO NHẠC • PIANO, GUITAR & NHẠC LÝ",
        font=f_tag,
        fill=(224, 231, 255, 255),
        anchor="mm",
    )

    # Main Brand Title
    draw.text((x0, 94), "CHAONOTE STUDIO", font=f_title, fill=(255, 255, 255, 255))
    draw.text(
        (x0, 150),
        "Học Piano, Guitar, Khuông Nhạc & Đấu Trường 1v1",
        font=f_sub,
        fill=(251, 191, 36, 255),
    )

    # 4 Feature cards
    features = [
        ("7 Chủ đề Piano & Khuông nhạc (Khóa Sol, Fa & Dòng kẻ phụ C3–C6)", (56, 189, 248)),
        ("Guitar Studio: Cần đàn 6 dây, Hợp âm, Scale, Tab & Rải Ballad sáng đèn", (251, 191, 36)),
        ("Đấu Trường Âm Nhạc 1v1: Đấu Độc lập, Combo Sét Đánh & Chia đôi 180°", (244, 114, 182)),
        ("Máy đếm nhịp cơ học chuẩn xác (<10ms) • Đa ngôn ngữ Việt – Anh", (52, 211, 153)),
    ]

    for idx, (text, accent) in enumerate(features):
        cy = 204 + idx * 58
        draw.rounded_rectangle(
            [x0, cy, 988, cy + 46],
            radius=12,
            fill=(30, 41, 59, 245),
            outline=(accent[0], accent[1], accent[2], 200),
            width=2,
        )
        draw.ellipse([x0 + 14, cy + 15, x0 + 30, cy + 31], fill=(accent[0], accent[1], accent[2], 255))
        draw.text((x0 + 42, cy + 23), text, font=f_item, fill=(248, 250, 252, 255), anchor="lm")

    banner.convert("RGB").save(os.path.join(STORE_DIR, "feature_graphic_1024x500.png"), "PNG")


def _draw_phone_frame(
    title_top: str,
    subtitle_top: str,
    accent_rgb: tuple[int, int, int],
    screen_drawer,
) -> Image.Image:
    """Creates a 1080x1920 Google Play Store poster with marketing headline and phone frame."""
    w, h = 1080, 1920
    poster = make_vertical_gradient(w, h, (15, 23, 42), (30, 27, 75))
    draw = ImageDraw.Draw(poster)

    f_badge = load_font(22, bold=True)
    f_h1 = load_font(44, bold=True)
    f_sub = load_font(24, bold=False)

    # Top brand pill
    draw.rounded_rectangle(
        [330, 48, 750, 96],
        radius=24,
        fill=(accent_rgb[0], accent_rgb[1], accent_rgb[2], 255),
    )
    draw.text(
        (540, 72),
        "CHAONOTE • CHÁO NHẠC",
        font=f_badge,
        fill=(255, 255, 255, 255),
        anchor="mm",
    )

    # Marketing headline
    draw.text((540, 140), title_top, font=f_h1, fill=(255, 255, 255, 255), anchor="mm")
    draw.text((540, 198), subtitle_top, font=f_sub, fill=(203, 213, 225, 255), anchor="mm")

    # Phone bezel frame (860 x 1560)
    px0, py0, px1, py1 = 110, 255, 970, 1845
    draw.rounded_rectangle(
        [px0 - 12, py0 - 12, px1 + 12, py1 + 12],
        radius=56,
        fill=(30, 41, 59, 255),
        outline=(148, 163, 184, 150),
        width=4,
    )
    draw.rounded_rectangle(
        [px0, py0, px1, py1],
        radius=46,
        fill=(15, 23, 42, 255),
    )

    # App Top Bar inside phone
    draw.rounded_rectangle([px0 + 28, py0 + 24, px1 - 28, py0 + 96], radius=20, fill=(30, 41, 59, 255))
    f_app = load_font(28, bold=True)
    f_pill = load_font(19, bold=True)
    draw.text((px0 + 52, py0 + 60), "ChaoNote", font=f_app, fill=(255, 255, 255, 255), anchor="lm")

    # Gem pill with vector diamond
    draw.rounded_rectangle([px1 - 335, py0 + 38, px1 - 175, py0 + 82], radius=22, fill=(49, 46, 129, 255), outline=(129, 140, 248, 220), width=2)
    draw_gem_diamond(draw, px1 - 310, py0 + 60, 9)
    draw.text((px1 - 245, py0 + 60), "250 Gem", font=f_pill, fill=(224, 231, 255, 255), anchor="mm")

    # Streak pill
    draw.rounded_rectangle([px1 - 160, py0 + 38, px1 - 48, py0 + 82], radius=22, fill=(120, 53, 15, 255), outline=(251, 191, 36, 220), width=2)
    draw.text((px1 - 104, py0 + 60), "7 ngày", font=f_pill, fill=(253, 230, 138, 255), anchor="mm")

    screen_drawer(draw, px0 + 28, py0 + 116, px1 - 28, py1 - 120)

    # Bottom Navigation Bar with Center Diamond Battle CTA
    nav_y0 = py1 - 104
    draw.rounded_rectangle(
        [px0 + 28, nav_y0, px1 - 28, py1 - 20],
        radius=30,
        fill=(30, 41, 59, 255),
        outline=(71, 85, 105, 180),
        width=2,
    )
    f_nav = load_font(18, bold=True)
    tabs = [("Trang chủ", px0 + 110), ("Luyện tập", px0 + 275), ("Công cụ", px1 - 275), ("Tiến trình", px1 - 110)]
    for t_label, tx in tabs:
        draw.text((tx, nav_y0 + 42), t_label, font=f_nav, fill=(203, 213, 225, 255), anchor="mm")

    # Center Diamond CTA with vector crossed swords
    cx = (px0 + px1) // 2
    cy = nav_y0 + 18
    diamond = [(cx, cy - 38), (cx + 38, cy), (cx, cy + 38), (cx - 38, cy)]
    draw.polygon(diamond, fill=(79, 70, 229, 255), outline=(255, 255, 255, 240))
    draw_crossed_swords(draw, cx, cy, 13)

    return poster


def generate_store_screenshots() -> None:
    f_h2 = load_font(30, bold=True)
    f_h3 = load_font(23, bold=True)
    f_body = load_font(20, bold=False)
    f_small = load_font(18, bold=True)

    # SCREENSHOT 1: Clean 4-Block Home Screen
    def draw_home(draw: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int):
        draw.text((x0 + 8, y0), "Học cảm âm mỗi ngày", font=f_h2, fill=(255, 255, 255, 255))
        draw.text((x0 + 8, y0 + 40), "Chọn bài học tại tab Luyện tập hoặc tiếp tục bên dưới", font=f_body, fill=(148, 163, 184, 255))

        # Block 2: Continue Learning Hero Card
        hy0 = y0 + 86
        draw.rounded_rectangle([x0, hy0, x1, hy0 + 280], radius=28, fill=(67, 56, 202, 255), outline=(129, 140, 248, 220), width=2)
        draw.rounded_rectangle([x0 + 24, hy0 + 22, x0 + 220, hy0 + 58], radius=18, fill=(49, 46, 129, 255))
        draw.text((x0 + 122, hy0 + 40), "TIẾP TỤC BÀI HỌC", font=f_small, fill=(224, 231, 255, 255), anchor="mm")
        draw.text((x1 - 24, hy0 + 40), "Đúng 9/10 câu", font=f_small, fill=(167, 243, 208, 255), anchor="rm")
        draw.text((x0 + 24, hy0 + 78), "Luyện đọc nốt & Dòng kẻ phụ", font=f_h2, fill=(255, 255, 255, 255))
        draw.text((x0 + 24, hy0 + 120), "Mức 3: Khóa Sol & Khóa Fa (C3–C6)", font=f_body, fill=(224, 231, 255, 255))
        draw.rounded_rectangle([x0 + 24, hy0 + 162, x1 - 24, hy0 + 178], radius=8, fill=(49, 46, 129, 255))
        draw.rounded_rectangle([x0 + 24, hy0 + 162, x1 - 95, hy0 + 178], radius=8, fill=(255, 255, 255, 255))
        draw.rounded_rectangle([x0 + 24, hy0 + 200, x1 - 190, hy0 + 258], radius=18, fill=(255, 255, 255, 255))
        draw.text(((x0 + 24 + x1 - 190) // 2, hy0 + 229), "Tiếp tục học ngay", font=f_h3, fill=(49, 46, 129, 255), anchor="mm")
        draw.rounded_rectangle([x1 - 172, hy0 + 200, x1 - 24, hy0 + 258], radius=18, outline=(255, 255, 255, 220), width=2)
        draw.text(((x1 - 172 + x1 - 24) // 2, hy0 + 229), "Đổi bài", font=f_h3, fill=(255, 255, 255, 255), anchor="mm")

        # Block 3: 4 Quick Access Items (Đàn Piano | Đàn Guitar | Ôn câu sai | Đấu trường)
        qy0 = hy0 + 305
        draw.rounded_rectangle([x0, qy0, x1, qy0 + 150], radius=24, fill=(30, 41, 59, 255), outline=(71, 85, 105, 160), width=2)
        cols = [
            ("Đàn Piano", "Khuông C3–C5", (99, 102, 241), "C4"),
            ("Đàn Guitar", "Map & Tab", (245, 158, 11), "6d"),
            ("Ôn câu sai", "Đúng 2 lần", (239, 68, 68), "2x"),
            ("Đấu trường", "So tài 1v1", (56, 189, 248), "1v1"),
        ]
        cw = (x1 - x0) // 4
        for idx, (ctitle, csub, ccol, badge_txt) in enumerate(cols):
            cx_mid = x0 + idx * cw + cw // 2
            draw.ellipse([cx_mid - 26, qy0 + 16, cx_mid + 26, qy0 + 68], fill=(ccol[0], ccol[1], ccol[2], 255))
            draw.text((cx_mid, qy0 + 42), badge_txt, font=load_font(16, True), fill=(255, 255, 255, 255), anchor="mm")
            draw.text((cx_mid, qy0 + 90), ctitle, font=f_small, fill=(255, 255, 255, 255), anchor="mm")
            draw.text((cx_mid, qy0 + 118), csub, font=load_font(16, False), fill=(148, 163, 184, 255), anchor="mm")

        # Block 4: Daily Goal (+20 Gem) & Daily Quests
        gy0 = qy0 + 175
        draw.rounded_rectangle([x0, gy0, x1, gy0 + 135], radius=24, fill=(30, 41, 59, 255), outline=(16, 185, 129, 180), width=2)
        draw.text((x0 + 24, gy0 + 40), "Mục tiêu hôm nay: 20 / 20 câu", font=f_h3, fill=(255, 255, 255, 255), anchor="lm")
        draw.rounded_rectangle([x1 - 220, gy0 + 18, x1 - 24, gy0 + 64], radius=22, fill=(16, 185, 129, 255))
        draw.text(((x1 - 220 + x1 - 24) // 2, gy0 + 41), "+20 Gem thưởng", font=f_small, fill=(255, 255, 255, 255), anchor="mm")
        draw.rounded_rectangle([x0 + 24, gy0 + 86, x1 - 24, gy0 + 104], radius=9, fill=(16, 185, 129, 255))

        dy0 = gy0 + 160
        draw.rounded_rectangle([x0, dy0, x1, y1 - 10], radius=24, fill=(30, 41, 59, 255), outline=(71, 85, 105, 160), width=2)
        draw.text((x0 + 24, dy0 + 34), "Nhiệm vụ hàng ngày (3/3 hoàn thành)", font=f_h3, fill=(255, 255, 255, 255), anchor="lm")
        quests = [
            "Hoàn thành: Luyện cảm âm 10 câu (+30 Gem)",
            "Hoàn thành: Thi đấu 1 trận Đấu Trường 1v1 (+40 Gem)",
            "Hoàn thành: Chép nhạc 1 câu giai điệu (+30 Gem)",
        ]
        for qi, qtxt in enumerate(quests):
            qy = dy0 + 92 + qi * 56
            draw.ellipse([x0 + 24, qy - 12, x0 + 48, qy + 12], fill=(16, 185, 129, 255))
            draw.text((x0 + 62, qy), qtxt, font=f_body, fill=(167, 243, 208, 255), anchor="lm")

    s1 = _draw_phone_frame(
        "TRANG CHỦ TINH GỌN & TRỰC QUAN",
        "Học Piano, Guitar & Nhạc lý theo lộ trình từ Cơ bản đến Nâng cao",
        (79, 70, 229),
        draw_home,
    )
    s1.convert("RGB").save(os.path.join(STORE_DIR, "screenshot_1_bang_diem_sang.png"), "PNG")

    # SCREENSHOT 2: 2-Column Big Grid Practice + Staff Reading Ledger Lines
    def draw_practice(draw: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int):
        draw.rounded_rectangle([x0, y0, x1, y0 + 68], radius=18, fill=(30, 41, 59, 255))
        draw.rounded_rectangle([x0 + 6, y0 + 6, (x0 + x1) // 2 - 4, y0 + 62], radius=14, fill=(79, 70, 229, 255))
        draw.text(((x0 + 6 + (x0 + x1) // 2 - 4) // 2, y0 + 34), "Piano & Nhạc lý", font=f_h3, fill=(255, 255, 255, 255), anchor="mm")
        draw.text((((x0 + x1) // 2 + x1) // 2, y0 + 34), "Học Guitar & Cần đàn", font=f_h3, fill=(251, 191, 36, 255), anchor="mm")

        cards = [
            ("Luyện nghe nốt", "Cảm âm C3–C5", (79, 70, 229), "C4"),
            ("Luyện đọc nốt", "Khuông & Dòng kẻ phụ", (56, 189, 248), "Sol"),
            ("Luyện nghe quãng", "Quãng 2 -> Quãng 8", (16, 185, 129), "2-8"),
            ("Nhận biết hợp âm", "Trưởng, Thứ, 7, Sus4", (245, 158, 11), "III"),
            ("Nhận biết giọng", "Hóa biểu & I–IV–V–I", (236, 72, 153), "#b"),
            ("Nghe giai điệu", "Chép nhạc 3–5 nốt", (139, 92, 246), "Mel"),
        ]
        cw = (x1 - x0 - 20) // 2
        ch = 185
        for idx, (ctitle, csub, ccol, sym) in enumerate(cards):
            r = idx // 2
            c = idx % 2
            cx0 = x0 + c * (cw + 20)
            cy0 = y0 + 92 + r * (ch + 18)
            cx_mid = cx0 + cw // 2
            draw.rounded_rectangle([cx0, cy0, cx0 + cw, cy0 + ch], radius=24, fill=(30, 41, 59, 255), outline=(ccol[0], ccol[1], ccol[2], 190), width=2)
            draw.rounded_rectangle([cx_mid - 38, cy0 + 20, cx_mid + 38, cy0 + 86], radius=20, fill=(ccol[0], ccol[1], ccol[2], 255))
            draw.text((cx_mid, cy0 + 53), sym, font=load_font(22, True), fill=(255, 255, 255, 255), anchor="mm")
            draw.text((cx_mid, cy0 + 118), ctitle, font=f_h3, fill=(255, 255, 255, 255), anchor="mm")
            draw.text((cx_mid, cy0 + 152), csub, font=f_body, fill=(148, 163, 184, 255), anchor="mm")

        # Bottom Preview: 5-Line Staff with Ledger Lines & Landmarks
        sy0 = y0 + 710
        draw.rounded_rectangle([x0, sy0, x1, y1 - 10], radius=24, fill=(24, 30, 54, 255), outline=(56, 189, 248, 200), width=2)
        draw.text((x0 + 24, sy0 + 32), "Khuông nhạc Khóa Sol & Fa • Dòng kẻ phụ (Mốc chuẩn)", font=f_h3, fill=(56, 189, 248, 255), anchor="lm")
        for i in range(5):
            ly = sy0 + 140 + i * 26
            draw.line([(x0 + 40, ly), (x1 - 40, ly)], fill=(148, 163, 184, 180), width=2)
        draw.line([(x0 + 260, sy0 + 92), (x0 + 340, sy0 + 92)], fill=(251, 191, 36, 255), width=4)
        draw.ellipse([x0 + 282, sy0 + 78, x0 + 318, sy0 + 106], fill=(251, 191, 36, 255))
        draw.text(((x0 + x1) // 2, sy0 + 298), "Đô chuẩn C4 (Phụ 1 dưới) • Sol G4 (Dòng 2) • Đô cao C6 (Phụ 2 trên)", font=f_body, fill=(226, 232, 240, 255), anchor="mm")

    s2 = _draw_phone_frame(
        "LƯỚI LUYỆN TẬP 2 CỘT & DÒNG KẺ PHỤ",
        "Chọn chủ đề trực quan • Luyện đọc nốt Khóa Sol, Khóa Fa & Dòng kẻ phụ C3–C6",
        (56, 189, 248),
        draw_practice,
    )
    s2.convert("RGB").save(os.path.join(STORE_DIR, "screenshot_2_cai_dat_am_thanh.png"), "PNG")

    # SCREENSHOT 3: Guitar Studio (6-String Fretboard, Chords & Visual Strum/Ballad)
    def draw_guitar(draw: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int):
        draw.text((x0 + 8, y0), "Phòng Học Guitar & Bản Đồ Cần Đàn 6 Dây", font=f_h2, fill=(251, 191, 36, 255))
        draw.text((x0 + 8, y0 + 42), "Nhớ nốt E2–E5 • Hợp âm mở & chặn • Scale Pentatonic • Đọc Tab", font=f_body, fill=(203, 213, 225, 255))

        fy0 = y0 + 92
        draw.rounded_rectangle([x0, fy0, x1, fy0 + 370], radius=22, fill=(30, 27, 24, 255), outline=(217, 119, 6, 220), width=3)
        strings = ["d1 (e4)", "d2 (B3)", "d3 (G3)", "d4 (D3)", "d5 (A2)", "d6 (E2)"]
        for s_idx, s_name in enumerate(strings):
            sy = fy0 + 48 + s_idx * 52
            draw.text((x0 + 18, sy), s_name, font=f_small, fill=(253, 230, 138, 255), anchor="lm")
            draw.line([(x0 + 115, sy), (x1 - 24, sy)], fill=(203, 213, 225, 200), width=2 + s_idx // 2)
        for f_idx in range(1, 8):
            fx = x0 + 115 + f_idx * 94
            draw.line([(fx, fy0 + 30), (fx, fy0 + 340)], fill=(148, 163, 184, 130), width=2)

        chord_dots = [
            (1, 1, "1", (59, 130, 246)),
            (3, 2, "2", (59, 130, 246)),
            (4, 3, "C3", (245, 158, 11)),
        ]
        for s_i, f_i, lbl, col in chord_dots:
            cx = x0 + 115 + f_i * 94 - 47
            cy = fy0 + 48 + s_i * 52
            draw.ellipse([cx - 24, cy - 24, cx + 24, cy + 24], fill=(col[0], col[1], col[2], 255), outline=(255, 255, 255, 255), width=2)
            draw.text((cx, cy), lbl, font=load_font(15, True), fill=(255, 255, 255, 255), anchor="mm")

        cy0 = fy0 + 395
        draw.rounded_rectangle([x0, cy0, x1, cy0 + 175], radius=22, fill=(30, 41, 59, 255), outline=(245, 158, 11, 180), width=2)
        draw.text((x0 + 24, cy0 + 34), "Hợp âm Đô Trưởng (C • X-3-2-0-1-0) • Đa âm 4 kênh", font=f_h3, fill=(255, 255, 255, 255), anchor="lm")
        b1_x0, b1_x1 = x0 + 24, (x0 + x1) // 2 - 10
        b2_x0, b2_x1 = (x0 + x1) // 2 + 10, x1 - 24
        draw.rounded_rectangle([b1_x0, cy0 + 82, b1_x1, cy0 + 148], radius=16, fill=(217, 119, 6, 255))
        draw.text(((b1_x0 + b1_x1) // 2, cy0 + 115), "Rải từ Bass xuống (Strum)", font=f_small, fill=(255, 255, 255, 255), anchor="mm")
        draw.rounded_rectangle([b2_x0, cy0 + 82, b2_x1, cy0 + 148], radius=16, fill=(79, 70, 229, 255))
        draw.text(((b2_x0 + b2_x1) // 2, cy0 + 115), "Rải Ballad (Bass-3-2-3-1)", font=f_small, fill=(255, 255, 255, 255), anchor="mm")

        ty0 = cy0 + 200
        draw.rounded_rectangle([x0, ty0, x1, y1 - 10], radius=22, fill=(30, 41, 59, 255), outline=(71, 85, 105, 160), width=2)
        draw.text((x0 + 24, ty0 + 36), "Khuông Tab 6 Dây & Luyện Ngón Spider Walk 1–2–3–4", font=f_h3, fill=(251, 191, 36, 255), anchor="lm")
        draw.text((x0 + 24, ty0 + 92), "e|---0-------1-------3---|   B|---1-------3-------5---|", font=f_h3, fill=(167, 243, 208, 255), anchor="lm")
        draw.text((x0 + 24, ty0 + 148), "• Tự động gảy mẫu & sáng đèn theo từng bước ngón tay trái 1-2-3-4", font=f_body, fill=(226, 232, 240, 255), anchor="lm")

    s3 = _draw_phone_frame(
        "HỌC GUITAR, HỢP ÂM & RẢI BALLAD SÁNG ĐÈN",
        "Bản đồ Cần đàn 6 dây chuẩn tần số E2–E5 • Rải dây trực quan & Đọc Tab",
        (217, 119, 6),
        draw_guitar,
    )
    s3.convert("RGB").save(os.path.join(STORE_DIR, "screenshot_3_che_do_toi_dark_mode.png"), "PNG")

    # SCREENSHOT 4: 1v1 Battle Arena
    def draw_battle(draw: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int):
        draw.rounded_rectangle([x0, y0, x1, y0 + 390], radius=24, fill=(40, 18, 48, 255), outline=(236, 72, 153, 200), width=2)
        draw.text((x0 + 24, y0 + 34), "NGƯỜI CHƠI 2 (Đối diện 180° • Đề bài độc lập Câu #5)", font=f_h3, fill=(244, 114, 182, 255), anchor="lm")
        draw.rounded_rectangle([x0 + 24, y0 + 68, x1 - 24, y0 + 92], radius=12, fill=(236, 72, 153, 255))
        draw.text((x0 + 24, y0 + 130), "Nhận diện Quãng hòa thanh vừa phát: Quãng 5 đúng (P5)", font=f_body, fill=(255, 255, 255, 255), anchor="lm")

        cy = y0 + 415
        draw.rounded_rectangle([x0, cy, x1, cy + 95], radius=22, fill=(217, 119, 6, 255), outline=(254, 240, 138, 255), width=3)
        draw.text(((x0 + x1) // 2, cy + 47), "SÉT ĐÁNH BẠO KÍCH COMBO x4! -22 HP + RUNG HAPTIC", font=f_h3, fill=(255, 255, 255, 255), anchor="mm")

        py0 = cy + 120
        draw.rounded_rectangle([x0, py0, x1, y1 - 10], radius=24, fill=(23, 37, 84, 255), outline=(56, 189, 248, 220), width=2)
        draw.text((x0 + 24, py0 + 34), "BẠN (100 HP • Chuỗi Combo x4 • Đề bài độc lập Câu #6)", font=f_h3, fill=(56, 189, 248, 255), anchor="lm")
        draw.rounded_rectangle([x0 + 24, py0 + 70, x1 - 24, py0 + 94], radius=12, fill=(16, 185, 129, 255))
        draw.text((x0 + 24, py0 + 132), "Quan sát khuông nhạc & chọn tên nốt trên Dòng kẻ phụ:", font=f_body, fill=(255, 255, 255, 255), anchor="lm")

        opts = [("A. Sol trầm (G3)", True), ("B. La trầm (A3)", False), ("C. Đô chuẩn (C4)", False), ("D. Đô rất cao (C6)", False)]
        ow = (x1 - x0 - 64) // 2
        for idx, (olbl, is_ok) in enumerate(opts):
            r = idx // 2
            c = idx % 2
            ox = x0 + 24 + c * (ow + 16)
            oy = py0 + 185 + r * 92
            draw.rounded_rectangle(
                [ox, oy, ox + ow, oy + 74],
                radius=16,
                fill=(16, 185, 129, 255) if is_ok else (30, 41, 59, 255),
                outline=(167, 243, 208, 255) if is_ok else (100, 116, 139, 180),
                width=2,
            )
            draw.text((ox + 22, oy + 37), olbl, font=f_h3, fill=(255, 255, 255, 255), anchor="lm")

    s4 = _draw_phone_frame(
        "ĐẤU TRƯỜNG ÂM NHẠC 1V1 & CHIA ĐÔI 180°",
        "2 bên giải đề độc lập theo tốc độ riêng • Hiệu ứng Sét đánh khi dồn Combo",
        (236, 72, 153),
        draw_battle,
    )
    s4.convert("RGB").save(os.path.join(STORE_DIR, "screenshot_4_dau_truong_1v1_split.png"), "PNG")


if __name__ == "__main__":
    generate_icons()
    generate_feature_graphic()
    generate_store_screenshots()
    print("Refined ChaoNote icons, feature graphic (1024x500), and 4 Full-HD store screenshots successfully!")
