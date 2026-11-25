#!/usr/bin/env python3
"""App icon: three stacked gold ingots on deep charcoal.

Writes the launcher icons (legacy + adaptive foreground), the splash mark and the
512 px Play Store icon. Needs playwright (Chromium). Run from the repo root.
"""
import os

from playwright.sync_api import sync_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')

DEFS = '''<defs>
 <linearGradient id="front" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#F7DC86"/><stop offset=".45" stop-color="#D9A93A"/><stop offset="1" stop-color="#9C7416"/>
 </linearGradient>
 <linearGradient id="top" x1="0" y1="0" x2="1" y2="0">
  <stop offset="0" stop-color="#FFF1C2"/><stop offset=".6" stop-color="#F3D27A"/><stop offset="1" stop-color="#E2B850"/>
 </linearGradient>
 <radialGradient id="bg" cx=".5" cy=".38" r=".75">
  <stop offset="0" stop-color="#2E281D"/><stop offset="1" stop-color="#14110C"/>
 </radialGradient>
</defs>'''


def ingot(cx, base, scale=1.0):
    """Front trapezoid + top face; `base` is the y of the bottom edge."""
    wb, wt, h, th, inset = 150 * scale, 120 * scale, 58 * scale, 20 * scale, 14 * scale
    x0, x1 = cx - wb / 2, cx + wb / 2
    t0, t1 = cx - wt / 2, cx + wt / 2
    y = base - h
    front = f'<path d="M{x0:.1f},{base:.1f} L{x1:.1f},{base:.1f} L{t1:.1f},{y:.1f} L{t0:.1f},{y:.1f} Z" fill="url(#front)"/>'
    top = (f'<path d="M{t0:.1f},{y:.1f} L{t1:.1f},{y:.1f} L{t1 - inset:.1f},{y - th:.1f} L{t0 + inset:.1f},{y - th:.1f} Z" '
           f'fill="url(#top)"/>')
    shine = (f'<path d="M{t0 + 10 * scale:.1f},{y + 8 * scale:.1f} L{t0 + 40 * scale:.1f},{y + 8 * scale:.1f} '
             f'L{x0 + 44 * scale:.1f},{base - 8 * scale:.1f} L{x0 + 16 * scale:.1f},{base - 8 * scale:.1f} Z" '
             f'fill="#FFFFFF" opacity=".18"/>')
    return front + top + shine


def sparkle(cx, cy, r):
    return (f'<path d="M{cx},{cy - r} Q{cx + r * .18},{cy - r * .18} {cx + r},{cy} Q{cx + r * .18},{cy + r * .18} {cx},{cy + r} '
            f'Q{cx - r * .18},{cy + r * .18} {cx - r},{cy} Q{cx - r * .18},{cy - r * .18} {cx},{cy - r} Z" fill="#FFF3CF"/>')


def mark(cy=256, s=1.0):
    """The ingot pyramid centred at (256, cy)."""
    b = cy + 92 * s
    return (ingot(256 - 80 * s, b, s) + ingot(256 + 80 * s, b, s) + ingot(256, b - 78 * s, s)
            + sparkle(256 + 118 * s, cy - 92 * s, 22 * s))


def full(rounded=True):
    r = 112 if rounded else 0
    return DEFS + f'<rect width="512" height="512" rx="{r}" fill="url(#bg)"/>' + mark(262, 1.12)


def foreground():
    # adaptive icon: 108dp canvas, masked to ~66dp in the middle
    return DEFS + mark(262, .8)


def render(page, svg, size, path, transparent=True):
    page.set_viewport_size({'width': size, 'height': size})
    page.set_content(f'<html><body style="margin:0;background:transparent"><svg xmlns="http://www.w3.org/2000/svg" '
                     f'width="{size}" height="{size}" viewBox="0 0 512 512">{svg}</svg></body></html>')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    page.screenshot(path=path, omit_background=transparent)


with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    for name, px in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
        render(page, full(), px, f'{RES}/mipmap-{name}/ic_launcher.png')
    for name, px in {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}.items():
        render(page, foreground(), px, f'{RES}/mipmap-{name}/ic_launcher_foreground.png')
    render(page, full(rounded=False), 512, os.path.join(ROOT, 'store', 'listing', 'icon-512.png'), transparent=False)
    render(page, full(), 1024, os.path.join(ROOT, 'store', 'icon-preview.png'))
    browser.close()
os.makedirs(f'{RES}/mipmap-anydpi-v26', exist_ok=True)
open(f'{RES}/mipmap-anydpi-v26/ic_launcher.xml', 'w').write('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
''')
print('ok')
