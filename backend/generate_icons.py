"""
Generate PWA icons (192x192 and 512x512) for Masareefi.
Draws a wallet with Iraqi banknotes using Pillow.
Run automatically during Railway build.
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter


def hex2rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def draw_rounded_rect(draw, xy, radius, fill):
    x0, y0, x1, y1 = xy
    # Clamp radius so it fits both dimensions
    max_r = min((x1 - x0) // 2, (y1 - y0) // 2, radius)
    r = max(1, max_r)
    draw.rectangle([x0 + r, y0, x1 - r, y1], fill=fill)
    draw.rectangle([x0, y0 + r, x1, y1 - r], fill=fill)
    draw.ellipse([x0, y0, x0 + r * 2, y0 + r * 2], fill=fill)
    draw.ellipse([x1 - r * 2, y0, x1, y0 + r * 2], fill=fill)
    draw.ellipse([x0, y1 - r * 2, x0 + r * 2, y1], fill=fill)
    draw.ellipse([x1 - r * 2, y1 - r * 2, x1, y1], fill=fill)


def rotate_paste(base, layer, angle, center):
    rotated = layer.rotate(angle, expand=True, resample=Image.BICUBIC)
    cx, cy = center
    pw, ph = rotated.size
    pos = (cx - pw // 2, cy - ph // 2)
    base.paste(rotated, pos, rotated)


def draw_banknote(size, w, h, bg_color, stripe_color):
    """Draw a single banknote as an RGBA image."""
    note = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(note)
    r = max(4, h // 8)
    draw_rounded_rect(d, [0, 0, w - 1, h - 1], r, hex2rgb(bg_color) + (255,))
    # Top stripe
    draw_rounded_rect(d, [0, 0, w - 1, h // 5], r, hex2rgb(stripe_color) + (255,))
    # 3 horizontal lines
    lc = (*hex2rgb(stripe_color), 160)
    lw = max(1, size // 90)
    for line_y in [h * 2 // 5, h * 3 // 5, h * 4 // 5]:
        d.line([(w // 10, line_y), (w * 8 // 10, line_y)], fill=lc, width=lw)
    # Small decorative circle
    cr = max(5, h // 6)
    cx, cy = w // 8, h // 2
    d.ellipse([cx - cr, cy - cr, cx + cr, cy + cr], outline=(*hex2rgb(stripe_color), 120), width=lw)
    return note


def generate_icon(size):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    s = size / 200  # scale factor relative to 200×200 design

    def sc(v):
        return int(v * s)

    # ── Background circle ──────────────────────────────
    # Dark navy gradient (approximated with two ellipses + blend)
    bg = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    bg_d = ImageDraw.Draw(bg)
    bg_d.ellipse([0, 0, size - 1, size - 1], fill='#1e1b4b')
    # Lighter inner glow
    glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    gw_d = ImageDraw.Draw(glow)
    gw_d.ellipse([sc(20), sc(20), size - sc(20), size - sc(20)], fill='#26236a')
    glow = glow.filter(ImageFilter.GaussianBlur(sc(14)))
    bg.paste(glow, (0, 0), glow)
    img.paste(bg, (0, 0), bg)

    # Border ring
    draw.ellipse([sc(2), sc(2), size - sc(2), size - sc(2)],
                 outline='#6d28d9', width=max(1, sc(2)))

    # ── Notes ──────────────────────────────────────────
    nw, nh = sc(72), sc(42)
    center_x = sc(100)
    center_y = sc(90)

    # Note 1: green (1000) - tilted left
    n1 = draw_banknote(size, nw, nh, '#16a34a', '#166534')
    rotate_paste(img, n1, 18, (center_x - sc(5), center_y - sc(5)))

    # Note 2: red (5000) - tilted right
    n2 = draw_banknote(size, nw, nh, '#dc2626', '#991b1b')
    rotate_paste(img, n2, -15, (center_x + sc(5), center_y - sc(5)))

    # Note 3: blue (10000) - center/front
    n3 = draw_banknote(size, nw, nh, '#2563eb', '#1e40af')
    rotate_paste(img, n3, 4, (center_x, center_y))

    # ── Wallet body ────────────────────────────────────
    wx0, wy0 = sc(34), sc(98)
    wx1, wy1 = sc(166), sc(175)
    wr = sc(12)
    draw_rounded_rect(draw, [wx0, wy0, wx1, wy1], wr, hex2rgb('#7c3aed') + (255,))

    # Wallet top flap
    draw_rounded_rect(draw, [sc(34), sc(85), sc(166), sc(112)], sc(10),
                      hex2rgb('#8b5cf6') + (255,))

    # Inner pocket shadow
    draw_rounded_rect(draw, [sc(40), sc(112), sc(160), sc(168)], sc(8),
                      (76, 29, 149, 120))

    # Coin pocket
    draw_rounded_rect(draw, [sc(118), sc(118), sc(155), sc(142)], sc(6),
                      (91, 33, 182, 180))

    # Coin
    cr = sc(9)
    ccx, ccy = sc(135), sc(130)
    # Gold gradient approximated
    for i in range(cr, 0, -1):
        t = i / cr
        r_c = int(253 * t + 245 * (1 - t))
        g_c = int(224 * t + 158 * (1 - t))
        b_c = int(71 * t + 11 * (1 - t))
        draw.ellipse([ccx - i, ccy - i, ccx + i, ccy + i],
                     fill=(r_c, g_c, b_c, 255))

    # Clasp button
    bc_r = sc(6)
    bcx, bcy = sc(100), sc(85)
    draw.ellipse([bcx - bc_r, bcy - bc_r, bcx + bc_r, bcy + bc_r],
                 fill='#a78bfa')
    draw.ellipse([bcx - sc(3), bcy - sc(3), bcx + sc(3), bcy + sc(3)],
                 fill='#7c3aed')

    # ── Sparkles ───────────────────────────────────────
    def sparkle(cx, cy, r, alpha=200):
        for angle in range(0, 360, 45):
            rad = math.radians(angle)
            ex = cx + int(r * math.cos(rad))
            ey = cy + int(r * math.sin(rad))
            lw = max(1, sc(1))
            draw.line([(cx, cy), (ex, ey)], fill=(253, 224, 71, alpha), width=lw)
        draw.ellipse([cx - sc(2), cy - sc(2), cx + sc(2), cy + sc(2)],
                     fill=(253, 224, 71, alpha))

    sparkle(sc(165), sc(38), sc(7))
    sparkle(sc(32),  sc(28), sc(5), 160)
    sparkle(sc(168), sc(158), sc(5), 160)

    # ── Smooth edges ───────────────────────────────────
    # Anti-alias the circle edge
    mask = Image.new('L', (size, size), 0)
    mask_d = ImageDraw.Draw(mask)
    mask_d.ellipse([0, 0, size - 1, size - 1], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(sc(1)))
    img.putalpha(mask)

    return img


def main():
    out_dir = os.path.join(os.path.dirname(__file__), 'static', 'icons')
    os.makedirs(out_dir, exist_ok=True)

    for size in [192, 512]:
        icon = generate_icon(size)
        path = os.path.join(out_dir, f'icon-{size}.png')
        icon.save(path, 'PNG', optimize=True)
        print(f'✅ Generated {path} ({size}x{size})')


if __name__ == '__main__':
    main()
