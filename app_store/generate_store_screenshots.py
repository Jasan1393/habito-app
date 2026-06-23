from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
IPHONE_OUT = ROOT / "app_store" / "screenshots" / "iphone_6_5"
IPAD_OUT = ROOT / "app_store" / "screenshots" / "ipad_13"
IPHONE_OUT.mkdir(parents=True, exist_ok=True)
IPAD_OUT.mkdir(parents=True, exist_ok=True)

BG = (239, 236, 230)
INK = (17, 17, 17)
MUTED = (104, 99, 91)
GOLD = (205, 181, 118)
CARD = (249, 248, 245)
BORDER = (216, 207, 190)


def font(size, bold=False):
    paths = []
    if bold:
        paths.extend(
            [
                "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
                "/System/Library/Fonts/Supplemental/Helvetica Bold.ttf",
            ]
        )
    paths.extend(
        [
            "/System/Library/Fonts/Supplemental/Arial.ttf",
            "/System/Library/Fonts/Supplemental/Helvetica.ttf",
        ]
    )
    for path in paths:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def palette_fonts(scale=1):
    return {
        "eyebrow": font(int(34 * scale), True),
        "hero": font(int(76 * scale), True),
        "body": font(int(34 * scale)),
        "bodyb": font(int(34 * scale), True),
        "small": font(int(25 * scale)),
        "smallb": font(int(25 * scale), True),
        "nav": font(int(23 * scale), True),
        "metric": font(int(42 * scale), True),
    }


F = palette_fonts()


def rr(draw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def center_text(draw, text, cx, y, fnt, fill):
    draw.text((cx - draw.textlength(text, font=fnt) / 2, y), text, font=fnt, fill=fill)


def wrap(draw, text, x, y, max_width, fnt, fill, spacing=6):
    line = ""
    lines = []
    for word in text.split():
        trial = (line + " " + word).strip()
        if draw.textlength(trial, font=fnt) <= max_width:
            line = trial
        else:
            if line:
                lines.append(line)
            line = word
    if line:
        lines.append(line)
    for line in lines:
        draw.text((x, y), line, font=fnt, fill=fill)
        y += int(fnt.size * 1.2) + spacing
    return y


def draw_icon(draw, kind, box, color):
    x1, y1, x2, y2 = box
    w = x2 - x1
    h = y2 - y1
    cx = (x1 + x2) / 2
    cy = (y1 + y2) / 2
    lw = max(3, int(w * 0.06))
    if kind == "calendar":
        draw.rounded_rectangle((x1 + w * 0.2, y1 + h * 0.22, x2 - w * 0.2, y2 - h * 0.16), radius=w * 0.08, outline=color, width=lw)
        draw.line((x1 + w * 0.2, y1 + h * 0.38, x2 - w * 0.2, y1 + h * 0.38), fill=color, width=lw)
        draw.line((x1 + w * 0.36, y1 + h * 0.16, x1 + w * 0.36, y1 + h * 0.30), fill=color, width=lw)
        draw.line((x2 - w * 0.36, y1 + h * 0.16, x2 - w * 0.36, y1 + h * 0.30), fill=color, width=lw)
    elif kind == "bag":
        draw.rounded_rectangle((x1 + w * 0.22, y1 + h * 0.30, x2 - w * 0.22, y2 - h * 0.12), radius=w * 0.08, outline=color, width=lw)
        draw.arc((x1 + w * 0.36, y1 + h * 0.15, x2 - w * 0.36, y1 + h * 0.48), 180, 360, fill=color, width=lw)
    elif kind == "star":
        pts = []
        for i in range(10):
            r = w * (0.32 if i % 2 == 0 else 0.14)
            a = -1.5708 + i * 3.14159 / 5
            pts.append((cx + r * __import__("math").cos(a), cy + r * __import__("math").sin(a)))
        draw.line(pts + [pts[0]], fill=color, width=lw, joint="curve")
    elif kind == "location":
        draw.ellipse((cx - w * 0.22, y1 + h * 0.18, cx + w * 0.22, y1 + h * 0.62), outline=color, width=lw)
        draw.ellipse((cx - w * 0.07, y1 + h * 0.33, cx + w * 0.07, y1 + h * 0.47), outline=color, width=lw)
        draw.line((cx, y1 + h * 0.62, cx, y2 - h * 0.14), fill=color, width=lw)
    elif kind == "user":
        draw.ellipse((cx - w * 0.13, y1 + h * 0.20, cx + w * 0.13, y1 + h * 0.46), outline=color, width=lw)
        draw.arc((cx - w * 0.28, y1 + h * 0.48, cx + w * 0.28, y2 - h * 0.08), 200, 340, fill=color, width=lw)
    elif kind == "search":
        draw.ellipse((x1 + w * 0.18, y1 + h * 0.18, x1 + w * 0.58, y1 + h * 0.58), outline=color, width=lw)
        draw.line((x1 + w * 0.52, y1 + h * 0.52, x2 - w * 0.16, y2 - h * 0.16), fill=color, width=lw)
    elif kind == "bell":
        draw.arc((cx - w * 0.22, y1 + h * 0.24, cx + w * 0.22, y2 - h * 0.12), 190, 350, fill=color, width=lw)
        draw.line((cx - w * 0.26, y2 - h * 0.28, cx + w * 0.26, y2 - h * 0.28), fill=color, width=lw)
        draw.ellipse((cx - w * 0.05, y2 - h * 0.20, cx + w * 0.05, y2 - h * 0.10), fill=color)
    elif kind == "scissors":
        draw.line((x1 + w * 0.30, y1 + h * 0.30, x2 - w * 0.22, y2 - h * 0.22), fill=color, width=lw)
        draw.line((x2 - w * 0.30, y1 + h * 0.30, x1 + w * 0.34, y2 - h * 0.26), fill=color, width=lw)
        draw.ellipse((x1 + w * 0.16, y1 + h * 0.18, x1 + w * 0.34, y1 + h * 0.36), outline=color, width=lw)
        draw.ellipse((x1 + w * 0.16, y2 - h * 0.36, x1 + w * 0.34, y2 - h * 0.18), outline=color, width=lw)
    elif kind == "product":
        draw.rounded_rectangle((x1 + w * 0.28, y1 + h * 0.20, x2 - w * 0.28, y2 - h * 0.15), radius=w * 0.08, outline=color, width=lw)
        draw.line((x1 + w * 0.36, y1 + h * 0.20, x2 - w * 0.36, y1 + h * 0.20), fill=color, width=lw)
        draw.line((x1 + w * 0.34, y1 + h * 0.08, x2 - w * 0.34, y1 + h * 0.08), fill=color, width=lw)
        draw.line((cx, y1 + h * 0.08, cx, y1 + h * 0.20), fill=color, width=lw)
    else:
        draw.ellipse((cx - w * 0.18, cy - h * 0.18, cx + w * 0.18, cy + h * 0.18), fill=color)


def draw_icon_button(draw, box, kind):
    rr(draw, box, 26, (10, 10, 10), (160, 134, 61), 2)
    draw_icon(draw, kind, (box[0] + 14, box[1] + 14, box[2] - 14, box[3] - 14), (238, 238, 238))
    draw.ellipse((box[2] - 22, box[1] + 10, box[2] - 8, box[1] + 24), fill=GOLD)


def make_base(size, title, subtitle):
    width, height = size
    image = Image.new("RGB", size, BG)
    draw = ImageDraw.Draw(image)
    for y in range(0, height, 36):
        draw.line((0, y, width, y), fill=(235, 232, 226), width=1)
    draw.text((86 if width < 1500 else 110, 96 if width < 1500 else 105), "HABITO BARBERIA CUENCA", font=F["eyebrow"], fill=(126, 101, 45))
    x = 86 if width < 1500 else 110
    y = 150 if width < 1500 else 160
    max_width = width - x * 2 if width < 1500 else 900
    y = wrap(draw, title, x, y, max_width, F["hero"], INK)
    wrap(draw, subtitle, x + 4, y + 18, max_width, F["body"], MUTED)
    return image


def phone_shell(image):
    draw = ImageDraw.Draw(image)
    px, py, pw, ph = 156, 610, 930, 1900
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((px - 12, py - 10, px + pw + 12, py + ph + 28), radius=86, fill=(0, 0, 0, 70))
    image.paste(Image.alpha_composite(image.convert("RGBA"), shadow.filter(ImageFilter.GaussianBlur(24))).convert("RGB"))
    rr(draw, (px, py, px + pw, py + ph), 82, (8, 8, 8))
    rr(draw, (px + 26, py + 30, px + pw - 26, py + ph - 30), 60, (244, 242, 236))
    rr(draw, (px + 345, py + 54, px + 585, py + 112), 32, (0, 0, 0))
    draw.text((px + 64, py + 62), "9:41", font=F["smallb"], fill=INK)
    draw.text((px + 735, py + 62), "5G", font=F["small"], fill=INK)
    return (px + 26, py + 30, px + pw - 26, py + ph - 30)


def bottom_nav(draw, box, active):
    x1, y1, x2, y2 = box
    nav_h = 170
    draw.rectangle((x1, y2 - nav_h, x2, y2), fill=(8, 8, 8))
    items = [
        ("Inicio", "home"),
        ("Tienda", "bag"),
        ("Citas", "calendar"),
        ("Puntos", "star"),
        ("Perfil", "user"),
    ]
    step = (x2 - x1) / 5
    for i, (label, kind) in enumerate(items):
        cx = x1 + step * (i + 0.5)
        color = GOLD if label == active else (170, 170, 170)
        if label == active:
            rr(draw, (cx - 68, y2 - nav_h + 20, cx + 68, y2 - nav_h + 82), 34, GOLD)
            draw_icon(draw, kind, (cx - 24, y2 - nav_h + 30, cx + 24, y2 - nav_h + 76), (10, 10, 10))
        else:
            draw_icon(draw, kind, (cx - 26, y2 - nav_h + 28, cx + 26, y2 - nav_h + 80), color)
        center_text(draw, label, cx, y2 - nav_h + 106, F["nav"], color)


def header(draw, box):
    x1, y1, x2, _ = box
    rr(draw, (x1 + 36, y1 + 128, x2 - 250, y1 + 218), 38, (238, 235, 229), BORDER, 2)
    draw_icon(draw, "search", (x1 + 62, y1 + 150, x1 + 112, y1 + 200), MUTED)
    draw.text((x1 + 130, y1 + 153), "Buscar productos y favoritos", font=F["small"], fill=MUTED)
    rr(draw, (x2 - 222, y1 + 128, x2 - 142, y1 + 218), 30, (8, 8, 8))
    draw_icon(draw, "bell", (x2 - 202, y1 + 150, x2 - 162, y1 + 196), (240, 240, 240))
    rr(draw, (x2 - 116, y1 + 128, x2 - 36, y1 + 218), 30, (8, 8, 8))
    draw_icon(draw, "bag", (x2 - 96, y1 + 150, x2 - 56, y1 + 196), (240, 240, 240))


def screenshot_home():
    image = make_base((1242, 2688), "Reserva tu estilo en segundos", "Agenda citas, encuentra servicios y gestiona tu experiencia desde una sola app.")
    box = phone_shell(image)
    draw = ImageDraw.Draw(image)
    x1, y1, x2, _ = box
    header(draw, box)
    rr(draw, (x1 + 36, y1 + 260, x2 - 36, y1 + 530), 46, (22, 21, 19))
    draw.rectangle((x1 + 76, y1 + 302, x1 + 86, y1 + 420), fill=GOLD)
    rr(draw, (x1 + 120, y1 + 300, x1 + 440, y1 + 360), 28, (36, 32, 20), (103, 88, 36), 2)
    draw.text((x1 + 150, y1 + 315), "Estilo con intencion", font=F["smallb"], fill=GOLD)
    draw_icon(draw, "scissors", (x2 - 150, y1 + 315, x2 - 82, y1 + 390), GOLD)
    draw.text((x1 + 116, y1 + 398), "Habito Barberia", font=F["metric"], fill=(244, 244, 244))
    draw.text((x1 + 116, y1 + 460), "Reserva y gestiona tu experiencia", font=F["smallb"], fill=(205, 201, 194))
    rr(draw, (x1 + 94, y1 + 560, x2 - 94, y1 + 646), 42, (38, 37, 34), (70, 66, 58), 2)
    center_text(draw, "Reservar cita", (x1 + x2) // 2, y1 + 582, F["bodyb"], (230, 218, 180))
    draw.text((x1 + 36, y1 + 720), "Accesos rapidos", font=F["metric"], fill=INK)
    cards = [
        ("Reserva", "Agenda tu proxima experiencia", "calendar"),
        ("Puntos", "Consulta tus beneficios", "star"),
        ("Sucursales", "Encuentra la mas cercana", "location"),
        ("Perfil", "Tus datos y preferencias", "user"),
    ]
    for idx, (title, subtitle, kind) in enumerate(cards):
        cx = x1 + 36 + (idx % 2) * 430
        cy = y1 + 805 + (idx // 2) * 335
        rr(draw, (cx, cy, cx + 390, cy + 285), 28, CARD, BORDER, 2)
        draw_icon_button(draw, (cx + 42, cy + 46, cx + 128, cy + 132), kind)
        draw.text((cx + 48, cy + 170), title, font=F["bodyb"], fill=INK)
        wrap(draw, subtitle, cx + 48, cy + 218, 300, F["small"], MUTED, 2)
    bottom_nav(draw, box, "Inicio")
    return image


def screenshot_booking():
    image = make_base((1242, 2688), "Agenda con tu barbero favorito", "Elige servicio, sucursal, profesional, fecha y horario disponible en pocos pasos.")
    box = phone_shell(image)
    draw = ImageDraw.Draw(image)
    x1, y1, x2, _ = box
    draw.text((x1 + 44, y1 + 146), "Reservar cita", font=F["metric"], fill=INK)
    draw.text((x1 + 44, y1 + 198), "Completa los pasos para confirmar tu visita.", font=F["small"], fill=MUTED)
    y = y1 + 270
    steps = [("1", "Servicio", "Corte de cabello", "Desde $10"), ("2", "Sucursal", "Habito Barberia Cuenca", "Centro"), ("3", "Barbero", "Equipo Habito", "Disponible hoy")]
    for number, title, value, meta in steps:
        rr(draw, (x1 + 44, y, x2 - 44, y + 160), 30, CARD, BORDER, 2)
        rr(draw, (x1 + 72, y + 40, x1 + 132, y + 100), 30, (20, 20, 20))
        center_text(draw, number, x1 + 102, y + 53, F["smallb"], GOLD)
        draw.text((x1 + 160, y + 34), title, font=F["smallb"], fill=MUTED)
        draw.text((x1 + 160, y + 78), value, font=F["bodyb"], fill=INK)
        draw.text((x2 - 250, y + 82), meta, font=F["smallb"], fill=(126, 101, 45))
        y += 188
    draw.text((x1 + 44, y + 12), "Selecciona horario", font=F["bodyb"], fill=INK)
    for i, time in enumerate(["10:00", "10:30", "11:00", "12:00", "15:30", "17:00"]):
        cx = x1 + 50 + (i % 3) * 275
        cy = y + 78 + (i // 3) * 98
        selected = i == 2
        rr(draw, (cx, cy, cx + 220, cy + 68), 24, (23, 22, 20) if selected else CARD, BORDER, 2)
        center_text(draw, time, cx + 110, cy + 16, F["bodyb"], GOLD if selected else INK)
    rr(draw, (x1 + 44, y + 318, x2 - 44, y + 590), 34, (24, 23, 21))
    draw.text((x1 + 82, y + 358), "Resumen", font=F["bodyb"], fill=(245, 245, 245))
    draw.text((x1 + 82, y + 414), "Corte de cabello · Equipo Habito", font=F["small"], fill=(211, 207, 198))
    draw.text((x1 + 82, y + 462), "Hoy 11:00 · Pago en local", font=F["small"], fill=(211, 207, 198))
    rr(draw, (x1 + 82, y + 512, x2 - 82, y + 566), 24, GOLD)
    center_text(draw, "Confirmar cita", (x1 + x2) // 2, y + 524, F["smallb"], (20, 18, 14))
    bottom_nav(draw, box, "Citas")
    return image


def screenshot_appointments():
    image = make_base((1242, 2688), "Tus citas siempre a mano", "Consulta reservas, reprograma horarios y guarda recordatorios en tu calendario.")
    box = phone_shell(image)
    draw = ImageDraw.Draw(image)
    x1, y1, x2, _ = box
    draw.text((x1 + 44, y1 + 146), "Mis citas", font=F["metric"], fill=INK)
    for i, label in enumerate(["Todas", "Confirmadas", "Historial"]):
        x = x1 + 44 + i * 245
        active = i == 1
        rr(draw, (x, y1 + 230, x + 215, y1 + 292), 28, (20, 20, 20) if active else CARD, BORDER, 2)
        center_text(draw, label, x + 107, y1 + 246, F["smallb"], GOLD if active else MUTED)
    y = y1 + 340
    for name, date, status in [("Corte de cabello", "Jueves 25 jun · 11:00", "Confirmada"), ("Perfilado de barba", "Sabado 27 jun · 16:30", "Pendiente"), ("Corte + barba", "Martes 30 jun · 10:00", "Confirmada")]:
        rr(draw, (x1 + 44, y, x2 - 44, y + 245), 34, CARD, BORDER, 2)
        draw.text((x1 + 86, y + 40), name, font=F["bodyb"], fill=INK)
        draw.text((x1 + 86, y + 92), date, font=F["small"], fill=MUTED)
        draw.text((x1 + 86, y + 136), "Habito Barberia Cuenca", font=F["small"], fill=MUTED)
        rr(draw, (x2 - 285, y + 42, x2 - 86, y + 96), 24, (231, 223, 201))
        center_text(draw, status, x2 - 185, y + 55, F["smallb"], (97, 76, 28))
        rr(draw, (x1 + 86, y + 170, x2 - 86, y + 218), 20, (18, 18, 18))
        center_text(draw, "Ver detalle y compartir", (x1 + x2) // 2, y + 180, F["smallb"], (240, 232, 205))
        y += 285
    rr(draw, (x1 + 44, y + 12, x2 - 44, y + 190), 34, (24, 23, 21))
    draw.text((x1 + 84, y + 48), "Recordatorios inteligentes", font=F["bodyb"], fill=(245, 245, 245))
    wrap(draw, "Recibe avisos de cambios, confirmaciones y promociones importantes.", x1 + 84, y + 98, 660, F["small"], (210, 207, 198), 2)
    bottom_nav(draw, box, "Citas")
    return image


def screenshot_points():
    image = make_base((1242, 2688), "Beneficios por volver", "Acumula puntos, comparte tu enlace y usa recompensas en tus reservas.")
    box = phone_shell(image)
    draw = ImageDraw.Draw(image)
    x1, y1, x2, _ = box
    draw.text((x1 + 44, y1 + 146), "Puntos Habito", font=F["metric"], fill=INK)
    rr(draw, (x1 + 44, y1 + 235, x2 - 44, y1 + 535), 42, (21, 20, 18))
    draw.text((x1 + 90, y1 + 285), "Saldo disponible", font=F["smallb"], fill=(215, 208, 190))
    draw.text((x1 + 90, y1 + 340), "1.250", font=font(92, True), fill=GOLD)
    draw.text((x1 + 90, y1 + 452), "puntos para reservar", font=F["bodyb"], fill=(245, 245, 245))
    rr(draw, (x1 + 44, y1 + 585, x2 - 44, y1 + 760), 34, CARD, BORDER, 2)
    draw_icon_button(draw, (x1 + 74, y1 + 627, x1 + 150, y1 + 703), "star")
    draw.text((x1 + 178, y1 + 625), "Cumpleanos", font=F["bodyb"], fill=INK)
    draw.text((x1 + 178, y1 + 678), "Beneficios especiales para reservas.", font=F["small"], fill=MUTED)
    draw.text((x1 + 44, y1 + 830), "Invita y gana", font=F["bodyb"], fill=INK)
    rr(draw, (x1 + 44, y1 + 895, x2 - 44, y1 + 1115), 34, CARD, BORDER, 2)
    wrap(draw, "Comparte tu enlace personal. Cuando tu referido reserve y facture su primera cita, ambos reciben beneficios.", x1 + 84, y1 + 935, 730, F["small"], MUTED, 4)
    rr(draw, (x1 + 84, y1 + 1030, x2 - 84, y1 + 1088), 24, (18, 18, 18))
    center_text(draw, "Compartir enlace", (x1 + x2) // 2, y1 + 1043, F["smallb"], (240, 232, 205))
    bottom_nav(draw, box, "Puntos")
    return image


def screenshot_shop():
    image = make_base((1242, 2688), "Productos para cuidar tu estilo", "Explora favoritos, productos de barberia y complementos para tu rutina.")
    box = phone_shell(image)
    draw = ImageDraw.Draw(image)
    x1, y1, x2, _ = box
    header(draw, box)
    draw.text((x1 + 44, y1 + 260), "Tienda", font=F["metric"], fill=INK)
    draw.text((x1 + 44, y1 + 315), "Productos y favoritos recomendados.", font=F["small"], fill=MUTED)
    products = [("Pomada mate", "Fijacion natural", "$12"), ("Aceite barba", "Cuidado diario", "$10"), ("Shampoo", "Limpieza premium", "$14"), ("Kit Habito", "Rutina completa", "$28")]
    for i, (name, desc, price) in enumerate(products):
        cx = x1 + 44 + (i % 2) * 420
        cy = y1 + 400 + (i // 2) * 430
        rr(draw, (cx, cy, cx + 380, cy + 370), 30, CARD, BORDER, 2)
        rr(draw, (cx + 42, cy + 36, cx + 338, cy + 200), 28, (32, 31, 29))
        draw_icon(draw, "product", (cx + 138, cy + 72, cx + 242, cy + 176), GOLD)
        draw.text((cx + 42, cy + 230), name, font=F["bodyb"], fill=INK)
        draw.text((cx + 42, cy + 282), desc, font=F["small"], fill=MUTED)
        draw.text((cx + 42, cy + 322), price, font=F["bodyb"], fill=(126, 101, 45))
    rr(draw, (x1 + 44, y1 + 1295, x2 - 44, y1 + 1465), 34, (21, 20, 18))
    draw.text((x1 + 84, y1 + 1335), "Carrito y favoritos", font=F["bodyb"], fill=(245, 245, 245))
    draw.text((x1 + 84, y1 + 1390), "Guarda productos y compra mas rapido.", font=F["small"], fill=(211, 207, 198))
    bottom_nav(draw, box, "Tienda")
    return image


def make_iphone():
    screens = [
        ("01-reserva-rapida.png", screenshot_home),
        ("02-agendar-cita.png", screenshot_booking),
        ("03-mis-citas.png", screenshot_appointments),
        ("04-puntos-beneficios.png", screenshot_points),
        ("05-tienda-productos.png", screenshot_shop),
    ]
    for name, factory in screens:
        image = factory()
        image.save(IPHONE_OUT / name, optimize=True)


def make_contact_sheet(folder, width, height):
    paths = [p for p in sorted(folder.glob("0*.png"))]
    thumbs = [Image.open(path).resize((width, height)) for path in paths]
    sheet = Image.new("RGB", (width * len(thumbs) + 24 * (len(thumbs) + 1), height + 48), (245, 245, 245))
    for index, thumb in enumerate(thumbs):
        sheet.paste(thumb, (24 + index * (width + 24), 24))
    sheet.save(folder / "preview-contact-sheet.png")


if __name__ == "__main__":
    make_iphone()
    make_contact_sheet(IPHONE_OUT, 248, 538)
    print("Generated corrected iPhone screenshots in", IPHONE_OUT)
