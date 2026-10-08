r"""Ritar UlatekEggs-ikonen: Ula'tek (orm) slingrad runt ett grönt ägg.

    python tools\make_icon.py

Skapar docs/logo.png (512x512), docs/social-preview.png (1280x640, laddas upp
manuellt under GitHub > Settings > Social preview) och Media/icon.png (64x64,
addonlistans ikon via ## IconTexture).
"""
import math
import pathlib

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
S = 4  # supersampling

BG, GOO = (18, 40, 32), (120, 190, 40)
SNAKE, SNAKE_DARK, SNAKE_BELLY = (108, 64, 165), (40, 20, 65), (160, 120, 210)
EGG, EGG_DARK, EGG_LIGHT = (76, 220, 76), (20, 60, 20), (170, 250, 170)


def bezier(p0, p1, p2, p3, n=300):
    pts = []
    for i in range(n + 1):
        t = i / n
        x = (1 - t) ** 3 * p0[0] + 3 * (1 - t) ** 2 * t * p1[0] + 3 * (1 - t) * t ** 2 * p2[0] + t ** 3 * p3[0]
        y = (1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * p1[1] + 3 * (1 - t) * t ** 2 * p2[1] + t ** 3 * p3[1]
        pts.append((x, y))
    return pts


def stroke(draw, pts, radii, color):
    for (x, y), r in zip(pts, radii):
        draw.ellipse((x - r, y - r, x + r, y + r), fill=color)


def draw_art(size):
    """Ikonen i given storlek (kvadrat), ritad i supersampling och nedskalad."""
    W = size * S
    im = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    u = W / 512  # enhet: 512-koordinater

    # bakgrund: rundad platta med grön goo-glöd
    d.rounded_rectangle((0, 0, W - 1, W - 1), radius=90 * u, fill=BG)
    glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((60 * u, 120 * u, 452 * u, 512 * u), fill=GOO + (150,))
    glow = glow.filter(ImageFilter.GaussianBlur(70 * u))
    im.alpha_composite(glow)
    d = ImageDraw.Draw(im)

    # ormens bana: bakre del (bakom ägget) och främre del (framför)
    back = bezier((70 * u, 440 * u), (150 * u, 520 * u), (380 * u, 500 * u), (445 * u, 350 * u))
    front = bezier((445 * u, 350 * u), (470 * u, 250 * u), (110 * u, 290 * u), (150 * u, 190 * u)) + \
        bezier((150 * u, 190 * u), (175 * u, 120 * u), (260 * u, 90 * u), (330 * u, 118 * u))[1:]
    n_back, n_front = len(back), len(front)
    r_back = [(6 + 26 * i / n_back) * u for i in range(n_back)]
    r_front = [(32 - 4 * i / n_front) * u for i in range(n_front)]

    def body(pts, radii):
        stroke(d, pts, [r + 5 * u for r in radii], SNAKE_DARK)
        stroke(d, pts, radii, SNAKE)
        # ljusare buk: tunnare linje något förskjuten
        stroke(d, [(x + 3 * u, y + 6 * u) for x, y in pts], [r * 0.45 for r in radii], SNAKE_BELLY)
        # fjällmönster: mörka prickar längs ryggen
        for i in range(0, len(pts), 22):
            x, y = pts[i]
            rr = radii[i] * 0.22
            d.ellipse((x - rr - 8 * u, y - rr - 9 * u, x + rr - 8 * u, y + rr - 9 * u), fill=SNAKE_DARK)

    body(back, r_back)

    # ägget
    ex, ey, rx, ry = 256 * u, 300 * u, 112 * u, 142 * u
    d.ellipse((ex - rx - 7 * u, ey - ry - 7 * u, ex + rx + 7 * u, ey + ry + 7 * u), fill=EGG_DARK)
    d.ellipse((ex - rx, ey - ry, ex + rx, ey + ry), fill=EGG)
    d.ellipse((ex - 60 * u, ey - 110 * u, ex - 10 * u, ey - 40 * u), fill=EGG_LIGHT)  # glans
    for sx, sy, sr in ((-30, 30, 9), (35, -10, 7), (20, 70, 8), (-55, 80, 6), (55, 50, 5)):
        d.ellipse((ex + sx * u - sr * u, ey + sy * u - sr * u, ex + sx * u + sr * u, ey + sy * u + sr * u), fill=EGG_DARK)

    body(front, r_front)

    # huvud
    hx, hy = 330 * u, 118 * u
    d.ellipse((hx - 58 * u, hy - 44 * u, hx + 58 * u, hy + 40 * u), fill=SNAKE_DARK)
    d.ellipse((hx - 52 * u, hy - 38 * u, hx + 52 * u, hy + 34 * u), fill=SNAKE)
    for ox in (-22, 18):  # ögon
        d.ellipse((hx + ox * u - 14 * u, hy - 22 * u, hx + ox * u + 14 * u, hy + 6 * u), fill=(255, 255, 255))
        d.ellipse((hx + ox * u - 5 * u, hy - 18 * u, hx + ox * u + 7 * u, hy + 2 * u), fill=(10, 10, 10))
        d.ellipse((hx + ox * u - 1 * u, hy - 15 * u, hx + ox * u + 4 * u, hy - 10 * u), fill=(255, 255, 255))
    # kluven tunga
    tx, ty = hx + 50 * u, hy + 14 * u
    d.line([(tx, ty), (tx + 40 * u, ty + 8 * u)], fill=(230, 40, 60), width=int(6 * u))
    d.line([(tx + 40 * u, ty + 8 * u), (tx + 56 * u, ty - 4 * u)], fill=(230, 40, 60), width=int(5 * u))
    d.line([(tx + 40 * u, ty + 8 * u), (tx + 56 * u, ty + 20 * u)], fill=(230, 40, 60), width=int(5 * u))

    return im.resize((size, size), Image.LANCZOS)


def main():
    docs = ROOT / "docs"
    docs.mkdir(exist_ok=True)
    logo = draw_art(512)
    logo.save(docs / "logo.png")
    draw_art(64).save(ROOT / "Media" / "icon.png")

    # Social preview 1280x640: ikon till vänster, text till höger
    sp = Image.new("RGBA", (1280, 640), BG + (255,))
    sp.alpha_composite(logo.resize((480, 480), Image.LANCZOS), (80, 80))
    d = ImageDraw.Draw(sp)
    fonts = pathlib.Path(r"C:\Windows\Fonts")
    big = ImageFont.truetype(str(fonts / "segoeuib.ttf"), 96)
    mid = ImageFont.truetype(str(fonts / "segoeui.ttf"), 44)
    small = ImageFont.truetype(str(fonts / "segoeui.ttf"), 32)
    d.text((620, 170), "UlatekEggs", font=big, fill=(255, 255, 255))
    d.text((624, 290), "Ditt ägg i fas 2 på Ula'tek", font=mid, fill=EGG)
    d.text((624, 350), "WoW-addon av Tjocksmock", font=small, fill=(220, 220, 220))
    d.text((624, 395), "For Science", font=small, fill=(255, 209, 0))
    d.text((624, 470), "WowUp: Install from URL", font=small, fill=(170, 170, 170))
    d.text((624, 510), "github.com/nucce1/UlatekEggs", font=small, fill=(170, 170, 170))
    sp.convert("RGB").save(docs / "social-preview.png")
    print("ok:", docs / "logo.png", docs / "social-preview.png", ROOT / "Media" / "icon.png")


if __name__ == "__main__":
    main()
