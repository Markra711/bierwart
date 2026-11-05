"""Erzeugt die Grafiken für den Play-Store-Eintrag (docs/store/).

Aufruf aus dem Projektordner:  python3 tool/store_grafiken.py
Braucht Inkscape und ImageMagick. Die Feature-Grafik folgt dem Cover aus dem Design System
(Blöcke in grad-start, grad-end, ink, line-strong, positive), die Farben
kommen aus docs/design/tokens.json.
"""

import json
import os
import subprocess
import tempfile
from pathlib import Path

WURZEL = Path(__file__).resolve().parent.parent
STORE = WURZEL / "docs" / "store"
FARBE = {
    t["name"]: t["value"]
    for t in json.loads((WURZEL / "docs/design/tokens.json").read_text())["color"]["tokens"]
}

# Cover aus dem Design System (960 × 288), skaliert und nach rechts geschoben.
# Der pinke Block ist länger, damit er wie im Cover unten anschneidet.
S, DX, DY = 1.3, 510 - 536 * 1.3, 24


def p(x, y):
    return x * S + DX, y * S + DY


def rect(klasse, x, y, w, h, r):
    x, y = p(x, y)
    return f'<rect fill="{klasse}" x="{x:.1f}" y="{y:.1f}" width="{w * S:.1f}" height="{h * S:.1f}" rx="{r * S:.1f}"/>'


def feature_svg():
    sx, sy = p(832, 64)
    schraffur = "".join(
        f'<line x1="{p(832, y)[0]:.1f}" y1="{p(832, y)[1]:.1f}" x2="{p(992, y - 160)[0]:.1f}" y2="{p(992, y - 160)[1]:.1f}"/>'
        for y in range(96, 361, 24)
    )
    gx, gy = p(872, 32)
    rx_, ry_ = p(508, 40)
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="500" viewBox="0 0 1024 500">
<defs><clipPath id="stahl"><rect x="{sx:.1f}" y="{sy:.1f}" width="{160 * S:.1f}" height="{224 * S:.1f}" rx="{26 * S:.1f}"/></clipPath></defs>
<rect width="1024" height="500" fill="{FARBE['bg']}"/>
{rect(FARBE['grad-start'], 536, 56, 160, 400, 26)}
{rect(FARBE['grad-end'], 712, -26, 104, 170, 26)}
{rect(FARBE['ink'], 712, 160, 104, 72, 36)}
{rect(FARBE['line-strong'], 832, 64, 160, 224, 26)}
<g clip-path="url(#stahl)" stroke="{FARBE['bg']}" stroke-width="{2 * S:.1f}">{schraffur}</g>
<circle fill="{FARBE['positive']}" cx="{gx:.1f}" cy="{gy:.1f}" r="{16 * S:.1f}"/>
<circle fill="none" stroke="{FARBE['line']}" stroke-width="{1.5 * S:.1f}" cx="{rx_:.1f}" cy="{ry_:.1f}" r="{10 * S:.1f}"/>
<text x="64" y="318" fill="{FARBE['ink']}" font-family="Barlow Condensed" font-weight="700" font-size="112" letter-spacing="2.2">BIERWART</text>
<text x="66" y="366" fill="{FARBE['ink-muted']}" font-family="Barlow" font-weight="600" font-size="28">Strichliste und Kasse</text>
<text x="66" y="402" fill="{FARBE['ink-muted']}" font-family="Barlow" font-weight="600" font-size="28">für die Mannschaft</text>
</svg>
"""


def rendern(svg: Path, png: Path, breite: int, hoehe: int, umgebung):
    subprocess.run(
        ["inkscape", str(svg), "--export-type=png", f"--export-filename={png}",
         f"--export-width={breite}", f"--export-height={hoehe}", "--export-background-opacity=1"],
        check=True, env=umgebung, capture_output=True,
    )


def main():
    # Barlow aus assets/fonts für Inkscape sichtbar machen, ohne sie zu installieren.
    with tempfile.TemporaryDirectory() as tmp:
        conf = Path(tmp) / "fonts.conf"
        conf.write_text(
            '<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "fonts.dtd"><fontconfig>'
            '<include ignore_missing="yes">/etc/fonts/fonts.conf</include>'
            f'<dir>{WURZEL / "assets" / "fonts"}</dir><cachedir>{tmp}</cachedir></fontconfig>'
        )
        umgebung = {**os.environ, "FONTCONFIG_FILE": str(conf)}

        feature = STORE / "feature-grafik.svg"
        feature.write_text(feature_svg())
        rendern(feature, STORE / "feature-grafik.png", 1024, 500, umgebung)
        # Play nimmt die Feature-Grafik nur ohne Alphakanal (24-Bit-PNG).
        subprocess.run(["magick", str(STORE / "feature-grafik.png"), "-alpha", "off",
                        "-define", "png:color-type=2", str(STORE / "feature-grafik.png")], check=True)
        rendern(STORE / "icon-play.svg", STORE / "icon-512.png", 512, 512, umgebung)

        res = WURZEL / "android/app/src/main/res"
        for dichte, px in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]:
            rendern(STORE / "icon-play.svg", res / f"mipmap-{dichte}" / "ic_launcher.png", px, px, umgebung)


if __name__ == "__main__":
    main()
