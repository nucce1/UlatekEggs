r"""Bygger UlatekEggs-ikonen som SVG (Ula'tek slingrad runt ett glödande ägg)
och renderar den till PNG med Edge headless.

    python tools/make_icon.py

Skapar docs/icon.svg, docs/logo.png (512), docs/social-preview.png (1280x640,
laddas upp manuellt under GitHub > Settings > Social preview) och Media/icon.png
(64, addonlistans ikon). Ormkroppen beräknas som en avsmalnande polygon längs
en bezierkedja så att fyllning, gradient och fjällmönster kan läggas på i SVG.
"""
import math
import pathlib
import subprocess
import tempfile
import time

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"


def bezier(p0, p1, p2, p3, n=120):
    pts = []
    for i in range(n + 1):
        t = i / n
        x = (1 - t) ** 3 * p0[0] + 3 * (1 - t) ** 2 * t * p1[0] + 3 * (1 - t) * t ** 2 * p2[0] + t ** 3 * p3[0]
        y = (1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * p1[1] + 3 * (1 - t) * t ** 2 * p2[1] + t ** 3 * p3[1]
        pts.append((x, y))
    return pts


def ribbon(pts, width_at):
    """Polygon runt en mittlinje: bredd width_at(t) (t 0..1) per punkt."""
    n = len(pts)
    left, right = [], []
    for i, (x, y) in enumerate(pts):
        x0, y0 = pts[max(i - 1, 0)]
        x1, y1 = pts[min(i + 1, n - 1)]
        dx, dy = x1 - x0, y1 - y0
        length = math.hypot(dx, dy) or 1
        nx, ny = -dy / length, dx / length
        w = width_at(i / (n - 1)) / 2
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    poly = left + right[::-1]
    return "M " + " L ".join(f"{x:.1f},{y:.1f}" for x, y in poly) + " Z"


def centerline(pts):
    return "M " + " L ".join(f"{x:.1f},{y:.1f}" for x, y in pts)


def build_svg(plate=True):
    # Kroppen: svans nere till vänster, bakom ägget nedtill, upp på höger sida,
    # framför ägget snett upp åt vänster, upp till huvudet uppe till höger.
    back = bezier((54, 430), (120, 540), (420, 530), (462, 330), n=160)
    front = bezier((462, 330), (480, 220), (90, 300), (132, 190), n=160) + \
        bezier((132, 190), (160, 110), (250, 70), (318, 96), n=120)[1:]
    back_poly = ribbon(back, lambda t: 10 + 46 * t)
    front_poly = ribbon(front, lambda t: 56 - 8 * t)
    back_belly = centerline([(x + 2, y + 9) for x, y in back[20:]])
    front_belly = centerline([(x + 2, y + 9) for x, y in front[:-25]])

    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
<defs>
  <radialGradient id="bg" cx="50%" cy="58%" r="70%">
    <stop offset="0" stop-color="#15362a"/><stop offset="1" stop-color="#050b08"/>
  </radialGradient>
  <radialGradient id="glow" cx="50%" cy="50%" r="50%">
    <stop offset="0" stop-color="#9dff3c" stop-opacity="0.55"/><stop offset="0.6" stop-color="#5ab52a" stop-opacity="0.18"/><stop offset="1" stop-color="#5ab52a" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="egg" cx="38%" cy="28%" r="78%">
    <stop offset="0" stop-color="#e9ffd6"/><stop offset="0.25" stop-color="#8ef05a"/><stop offset="0.7" stop-color="#3aa83a"/><stop offset="1" stop-color="#145a24"/>
  </radialGradient>
  <linearGradient id="skin" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#8f67d8"/><stop offset="0.5" stop-color="#5a3496"/><stop offset="1" stop-color="#2d1650"/>
  </linearGradient>
  <linearGradient id="head" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#a07be8"/><stop offset="1" stop-color="#3b1f66"/>
  </linearGradient>
  <pattern id="scales" width="22" height="16" patternUnits="userSpaceOnUse" patternTransform="rotate(-25)">
    <path d="M0,0 Q11,10 22,0 L22,16 Q11,6 0,16 Z" fill="#000" fill-opacity="0.22"/>
    <path d="M0,0 Q11,10 22,0" fill="none" stroke="#d9c9ff" stroke-opacity="0.35" stroke-width="1.6"/>
  </pattern>
  <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
    <feDropShadow dx="0" dy="8" stdDeviation="8" flood-color="#000" flood-opacity="0.6"/>
  </filter>
  <filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="12"/></filter>
  <clipPath id="eggclip"><ellipse cx="256" cy="302" rx="118" ry="150"/></clipPath>
</defs>

{'<rect width="512" height="512" rx="96" fill="url(#bg)"/>' if plate else ''}
<ellipse cx="256" cy="330" rx="230" ry="200" fill="url(#glow)"/>

<!-- bakre kroppen -->
<g filter="url(#shadow)">
  <path d="{back_poly}" fill="#1a0b33"/>
  <path d="{back_poly}" fill="url(#skin)" transform="translate(0,0)" style="paint-order:stroke" stroke="#1a0b33" stroke-width="6"/>
  <path d="{back_poly}" fill="url(#scales)"/>
  <path d="{back_belly}" fill="none" stroke="#e2d4ff" stroke-opacity="0.28" stroke-width="12" stroke-linecap="round"/>
</g>

<!-- ägget -->
<g filter="url(#shadow)">
  <ellipse cx="256" cy="302" rx="118" ry="150" fill="url(#egg)" stroke="#0b3a16" stroke-width="7"/>
  <g clip-path="url(#eggclip)" fill="#0f4a1b" fill-opacity="0.55">
    <ellipse cx="226" cy="330" rx="11" ry="8" transform="rotate(-20 226 330)"/>
    <ellipse cx="292" cy="290" rx="8" ry="6" transform="rotate(30 292 290)"/>
    <ellipse cx="275" cy="372" rx="10" ry="7" transform="rotate(10 275 372)"/>
    <ellipse cx="202" cy="384" rx="7" ry="5"/>
    <ellipse cx="312" cy="345" rx="6" ry="5"/>
    <ellipse cx="250" cy="420" rx="9" ry="6" transform="rotate(-15 250 420)"/>
  </g>
  <ellipse cx="214" cy="212" rx="34" ry="52" fill="#ffffff" fill-opacity="0.35" transform="rotate(-18 214 212)" filter="url(#soft)"/>
</g>

<!-- främre kroppen -->
<g filter="url(#shadow)">
  <path d="{front_poly}" fill="url(#skin)" stroke="#1a0b33" stroke-width="6" style="paint-order:stroke"/>
  <path d="{front_poly}" fill="url(#scales)"/>
  <path d="{front_belly}" fill="none" stroke="#e2d4ff" stroke-opacity="0.28" stroke-width="12" stroke-linecap="round"/>
</g>

<!-- huvudet: kilformat, vänt åt höger -->
<g transform="translate(318,96) rotate(12)" filter="url(#shadow)">
  <path d="M-52,-26 C-20,-50 40,-46 76,-8 C86,2 86,10 76,16 C40,42 -20,44 -52,22 C-64,12 -64,-14 -52,-26 Z" fill="url(#head)" stroke="#1a0b33" stroke-width="6"/>
  <path d="M-52,-26 C-20,-50 40,-46 76,-8 C86,2 86,10 76,16 C40,42 -20,44 -52,22 C-64,12 -64,-14 -52,-26 Z" fill="url(#scales)" fill-opacity="0.7"/>
  <path d="M-30,-30 C0,-44 36,-40 62,-18" fill="none" stroke="#c7b2ff" stroke-opacity="0.5" stroke-width="5" stroke-linecap="round"/>
  <!-- öga: gult med vertikal pupill -->
  <ellipse cx="18" cy="-10" rx="15" ry="11" fill="#f6e23a" stroke="#1a0b33" stroke-width="3"/>
  <ellipse cx="19" cy="-10" rx="3.5" ry="9" fill="#0a0a0a"/>
  <circle cx="14" cy="-14" r="2.5" fill="#fff" fill-opacity="0.9"/>
  <!-- ögonbrynsplåt -->
  <path d="M0,-24 C10,-30 30,-28 40,-20" fill="none" stroke="#1a0b33" stroke-width="5" stroke-linecap="round"/>
  <!-- huggtänder -->
  <path d="M52,14 L58,34 L64,14 Z" fill="#f4f0e6" stroke="#1a0b33" stroke-width="2"/>
  <path d="M30,20 L36,38 L42,20 Z" fill="#f4f0e6" stroke="#1a0b33" stroke-width="2"/>
  <!-- kluven tunga -->
  <path d="M80,6 C100,8 110,8 122,2 M110,6 C118,12 124,18 128,24" fill="none" stroke="#e8304a" stroke-width="5" stroke-linecap="round"/>
</g>
</svg>
"""


def render(svg_or_html: str, out: pathlib.Path, w: int, h: int, scale: int = 2):
    """Edge returnerar direkt och skriver skärmbilden i bakgrunden, så sidan och
    profilen måste överleva anropet och vi väntar in filen."""
    work = pathlib.Path(tempfile.gettempdir()) / "UlatekEggs-edge"
    work.mkdir(exist_ok=True)
    page = work / f"{out.stem}.html"
    page.write_text(svg_or_html, encoding="utf-8")
    if out.exists():
        out.unlink()
    subprocess.run([EDGE, "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars", "--no-first-run",
                    f"--user-data-dir={work / 'profile'}", f"--force-device-scale-factor={scale}", f"--window-size={w},{h}",
                    f"--screenshot={out}", page.as_uri()], check=True, capture_output=True, timeout=90)
    last = -1
    for _ in range(60):
        time.sleep(1)
        size = out.stat().st_size if out.exists() else -1
        if size > 0 and size == last:
            return
        last = size
    raise RuntimeError(f"Edge skrev ingen skärmbild till {out}")


def main():
    docs = ROOT / "docs"
    docs.mkdir(exist_ok=True)
    svg = build_svg()
    (docs / "icon.svg").write_text(svg, encoding="utf-8")
    page = f"<html><body style='margin:0;background:transparent'>{svg}</body></html>"
    big = docs / "logo_1024.png"
    render(page, big, 512, 512, scale=2)
    im = Image.open(big).convert("RGBA")
    im.resize((512, 512), Image.LANCZOS).save(docs / "logo.png")
    im.resize((64, 64), Image.LANCZOS).save(ROOT / "Media" / "icon.png")
    big.unlink()

    preview = f"""<html><body style="margin:0;width:1280px;height:640px;background:radial-gradient(ellipse at 30% 50%,#15362a,#050b08 70%);
font-family:'Segoe UI',Arial,sans-serif;color:#fff;position:relative;overflow:hidden">
<div style="position:absolute;left:60px;top:40px;width:560px;height:560px">{build_svg(plate=False).replace('width="512" height="512"', 'width="560" height="560"')}</div>
<div style="position:absolute;left:640px;top:150px">
  <div style="font-size:92px;font-weight:700;letter-spacing:-1px;line-height:1">UlatekEggs</div>
  <div style="font-size:40px;color:#8ef05a;margin-top:18px">Ditt ägg i fas 2 på Ula'tek</div>
  <div style="font-size:30px;color:#ddd;margin-top:26px">WoW-addon av Tjocksmock</div>
  <div style="font-size:30px;color:#ffd100">For Science</div>
  <div style="font-size:26px;color:#9a9a9a;margin-top:50px">WowUp → Install from URL<br>github.com/nucce1/UlatekEggs</div>
</div></body></html>"""
    render(preview, docs / "social-preview.png", 1280, 640, scale=1)
    print("ok:", docs / "icon.svg", docs / "logo.png", docs / "social-preview.png", ROOT / "Media" / "icon.png")


if __name__ == "__main__":
    main()
