"""
Masareefi icon — Premium redesign v2.
Large Iraqi dinar notes (10K olive-green + 25K rose) fanning from a
luxury leather wallet on a deep violet background with gold accents.
"""
import math
import os
import shutil

from PIL import Image, ImageDraw, ImageFilter

try:
    from PIL import ImageFont
    _F = next(
        (p for p in [
            "C:/Windows/Fonts/arialbd.ttf",
            "C:/Windows/Fonts/arial.ttf",
            "C:/Windows/Fonts/calibrib.ttf",
            "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        ] if os.path.exists(p)),
        None,
    )
except Exception:
    _F = None


def load_font(sz):
    if _F:
        try:
            return ImageFont.truetype(_F, max(1, sz))
        except Exception:
            pass
    return ImageFont.load_default()


def rpaste(base, layer, angle, cx, cy):
    """Rotate layer and paste it centred at (cx, cy) on base."""
    rot = layer.rotate(angle, expand=True, resample=Image.BICUBIC)
    pw, ph = rot.size
    base.paste(rot, (cx - pw // 2, cy - ph // 2), rot)


def make_note(W, H, body, header, side, cream, denom_txt):
    """Draw a crisp landscape banknote (W × H)."""
    n = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(n)
    R = max(5, W // 11)
    lw = max(1, W // 70)

    # ── Main body ──────────────────────────────────────────────
    d.rounded_rectangle([0, 0, W - 1, H - 1], radius=R, fill=body)

    # Top strip
    d.rounded_rectangle([0, 0, W - 1, H // 5], radius=R, fill=header)
    d.rectangle([R, H // 5 - R // 2, W - R, H // 5], fill=header)

    # Bottom strip
    d.rounded_rectangle([0, H * 4 // 5, W - 1, H - 1], radius=R, fill=header)
    d.rectangle([R, H * 4 // 5, W - R, H * 4 // 5 + R // 2], fill=header)

    # Left ornament strip
    d.rectangle([0, H // 5, W // 9, H * 4 // 5], fill=side)
    # Right ornament strip
    d.rectangle([W - W // 9, H // 5, W - 1, H * 4 // 5], fill=side)

    # ── Centre ivory/cream panel ────────────────────────────────
    m = W // 7
    d.rounded_rectangle([m, H // 6, W - m, H * 5 // 6], radius=R - 2, fill=cream)

    # Subtle paper texture lines inside cream area
    line_col = (*cream[:3], max(0, cream[3] - 180)) if len(cream) == 4 else (cream[0], cream[1], cream[2], 35)
    for yl in range(H // 4, H * 3 // 4, max(2, H // 14)):
        d.line([(m + R, yl), (W - m - R, yl)], fill=(*header[:3], 22), width=max(1, lw // 2))

    # Inner border
    d.rounded_rectangle(
        [lw * 2, lw * 2, W - lw * 2, H - lw * 2],
        radius=R, outline=(*header[:3], 170), width=lw,
    )

    # ── Denomination text ───────────────────────────────────────
    fsz = max(6, W // 8)
    f = load_font(fsz)
    try:
        bb = d.textbbox((0, 0), denom_txt, font=f)
        tw, th = bb[2] - bb[0], bb[3] - bb[1]
        tx_pos = (W - tw) // 2
        ty_pos = (H - th) // 2
        # Shadow
        d.text((tx_pos + 1, ty_pos + 2), denom_txt, fill=(*header[:3], 100), font=f)
        # Main text
        d.text((tx_pos, ty_pos), denom_txt, fill=(*header[:3], 255), font=f)
    except Exception:
        pass

    # ── Gold corner circles ─────────────────────────────────────
    cr = max(3, H // 9)
    for qx, qy in [(cr, cr), (W - cr, cr), (cr, H - cr), (W - cr, H - cr)]:
        d.ellipse([qx - cr, qy - cr, qx + cr, qy + cr], fill=(212, 175, 55, 215))
        d.ellipse([qx - cr // 2, qy - cr // 2, qx + cr // 2, qy + cr // 2],
                  fill=(255, 235, 130, 240))

    # Gold security strip (vertical)
    stx = W - W // 9 - lw * 3
    d.rectangle([stx, H // 6 + 2, stx + max(2, lw * 2), H * 5 // 6 - 2],
                fill=(212, 175, 55, 130))

    return n


def generate_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def sc(v):
        return int(v * size / 200)

    # ── Background: deep violet circle ───────────────────────────
    d.ellipse([0, 0, size - 1, size - 1], fill=(14, 8, 48, 255))

    # Radial glow: warm amber at top-centre (makes gold pop)
    for layer_data in [
        (sc(50), sc(-40), sc(150), sc(110), (200, 150, 30, 28), sc(30)),
        (sc(30), sc(30), sc(170), sc(150), (80, 40, 160, 20), sc(35)),
    ]:
        x0, y0, x1, y1, col, blur = layer_data
        gl = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        ImageDraw.Draw(gl).ellipse([x0, y0, x1, y1], fill=col)
        gl = gl.filter(ImageFilter.GaussianBlur(blur))
        img.paste(gl, (0, 0), gl)

    # ── Gold border ring (thick + inner shine) ────────────────────
    rw = max(3, sc(5))
    d.ellipse([sc(2), sc(2), size - sc(2) - 1, size - sc(2) - 1],
              outline=(180, 140, 30, 255), width=rw)
    d.ellipse([sc(2) + rw, sc(2) + rw, size - sc(2) - rw - 1, size - sc(2) - rw - 1],
              outline=(255, 220, 80, 120), width=max(1, sc(2)))
    d.ellipse([sc(2) + rw * 2 + sc(2), sc(2) + rw * 2 + sc(2),
               size - sc(2) - rw * 2 - sc(2) - 1, size - sc(2) - rw * 2 - sc(2) - 1],
              outline=(255, 245, 180, 40), width=max(1, sc(1)))

    # ── Banknotes — large, dramatic fan ──────────────────────────
    NW = sc(106)   # wide notes (real IQD landscape proportions)
    NH = sc(63)    # height
    CY = sc(80)    # vertical centre of notes

    # 10,000 IQD — olive/yellow-green (back note, drawn first)
    n10 = make_note(
        NW, NH,
        body=(95, 140, 18, 255),
        header=(38, 80, 6, 255),
        side=(26, 60, 4, 220),
        cream=(212, 238, 160, 248),
        denom_txt="10,000",
    )
    rpaste(img, n10, 24, sc(72), CY + sc(3))

    # 25,000 IQD — rose/magenta (front note)
    n25 = make_note(
        NW, NH,
        body=(195, 65, 95, 255),
        header=(135, 18, 50, 255),
        side=(110, 22, 115, 220),
        cream=(250, 205, 222, 248),
        denom_txt="25,000",
    )
    rpaste(img, n25, -24, sc(130), CY - sc(2))

    # ── Wallet drop shadow ────────────────────────────────────────
    wx0, wy0 = sc(18), sc(106)
    wx1, wy1 = sc(182), sc(186)
    WR = sc(16)

    sh = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    sd.rounded_rectangle(
        [wx0 + sc(7), wy0 + sc(9), wx1 + sc(7), wy1 + sc(9)],
        radius=WR, fill=(0, 0, 0, 110),
    )
    sh = sh.filter(ImageFilter.GaussianBlur(sc(10)))
    img.paste(sh, (0, 0), sh)

    # ── Wallet body — rich leather ────────────────────────────────
    # Main body (medium-dark saddle brown)
    d.rounded_rectangle([wx0, wy0, wx1, wy1], radius=WR, fill=(108, 50, 14, 255))

    # Top flap (lighter, sunlit leather)
    d.rounded_rectangle([wx0, wy0, wx1, wy0 + sc(30)], radius=WR, fill=(162, 90, 38, 255))
    d.rectangle([wx0 + WR, wy0 + sc(22), wx1 - WR, wy0 + sc(30)], fill=(135, 68, 22, 255))

    # Specular highlight on top edge
    d.rectangle([wx0 + WR, wy0 + sc(2), wx1 - WR, wy0 + sc(6)],
                fill=(210, 148, 78, 80))

    # Interior pocket (warm dark, not black)
    d.rounded_rectangle(
        [wx0 + sc(11), wy0 + sc(24), wx1 - sc(11), wy1 - sc(7)],
        radius=sc(11), fill=(62, 24, 6, 235),
    )

    # Interior depth: darker strip at top of pocket
    d.rounded_rectangle(
        [wx0 + sc(11), wy0 + sc(24), wx1 - sc(11), wy0 + sc(38)],
        radius=sc(11), fill=(35, 10, 2, 180),
    )

    # Interior highlight (bottom of pocket, warm reflection)
    d.rounded_rectangle(
        [wx0 + sc(20), wy1 - sc(22), wx1 - sc(20), wy1 - sc(10)],
        radius=sc(6), fill=(88, 38, 10, 80),
    )

    # ── Leather stitching ─────────────────────────────────────────
    stitch = (190, 130, 55, 185)
    sw = max(1, sc(1))
    for yst in [wy0 + sc(5), wy1 - sc(6)]:
        x = wx0 + sc(18)
        while x < wx1 - sc(18):
            x2 = min(x + sc(6), wx1 - sc(18))
            d.line([(x, yst), (x2, yst)], fill=stitch, width=sw)
            x += sc(11)
    for xst in [wx0 + sc(6), wx1 - sc(6)]:
        y = wy0 + sc(16)
        while y < wy1 - sc(16):
            y2 = min(y + sc(5), wy1 - sc(16))
            d.line([(xst, y), (xst, y2)], fill=stitch, width=sw)
            y += sc(10)

    # ── Gold clasp (oval, detailed) ───────────────────────────────
    clx, cly = sc(100), sc(109)
    # Outer shadow
    d.ellipse([clx - sc(13), cly - sc(9), clx + sc(13), cly + sc(9)],
              fill=(60, 40, 0, 180))
    # Outer ring
    d.ellipse([clx - sc(12), cly - sc(8), clx + sc(12), cly + sc(8)],
              fill=(150, 110, 12, 255))
    # Mid ring
    d.ellipse([clx - sc(10), cly - sc(6), clx + sc(10), cly + sc(6)],
              fill=(218, 182, 52, 255))
    # Inner bright
    d.ellipse([clx - sc(7), cly - sc(4), clx + sc(7), cly + sc(4)],
              fill=(248, 220, 90, 255))
    # Centre highlight
    d.ellipse([clx - sc(3), cly - sc(2), clx + sc(3), cly + sc(2)],
              fill=(255, 252, 195, 255))

    # ── Coloured glow around the exposed notes ────────────────────
    gl2 = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    g2 = ImageDraw.Draw(gl2)
    g2.ellipse([sc(8), sc(38), sc(118), sc(115)], fill=(95, 140, 18, 35))
    g2.ellipse([sc(84), sc(35), sc(192), sc(112)], fill=(195, 65, 95, 32))
    gl2 = gl2.filter(ImageFilter.GaussianBlur(sc(20)))
    img.paste(gl2, (0, 0), gl2)

    # ── Gold sparkles ─────────────────────────────────────────────
    def sparkle(cx, cy, r, a=215):
        lw = max(1, sc(1))
        for ang in range(0, 360, 45):
            rad = math.radians(ang)
            sr = r if ang % 90 == 0 else r * 0.48
            d.line(
                [(cx, cy), (cx + int(sr * math.cos(rad)), cy + int(sr * math.sin(rad)))],
                fill=(253, 224, 71, a), width=lw,
            )
        d.ellipse([cx - sc(2), cy - sc(2), cx + sc(2), cy + sc(2)],
                  fill=(255, 240, 120, a))

    sparkle(sc(168), sc(22), sc(12))
    sparkle(sc(22), sc(16), sc(7), 165)
    sparkle(sc(178), sc(175), sc(6), 145)
    sparkle(sc(30), sc(172), sc(5), 130)
    sparkle(sc(155), sc(162), sc(4), 115)

    # ── Circular clip mask (anti-aliased) ─────────────────────────
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, size - 1, size - 1], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(max(1, sc(1))))
    img.putalpha(mask)

    return img


def main():
    base = os.path.dirname(os.path.abspath(__file__))
    bd = os.path.join(base, "static", "icons")
    os.makedirs(bd, exist_ok=True)
    fd = os.path.join(base, "..", "flutter_app", "web", "icons")
    os.makedirs(fd, exist_ok=True)

    for sz in [192, 512]:
        ic = generate_icon(sz)
        bp = os.path.join(bd, f"icon-{sz}.png")
        ic.save(bp, "PNG", optimize=True)
        print(f"✅ Backend   → {bp}")
        fp = os.path.join(fd, f"Icon-{sz}.png")
        ic.save(fp, "PNG", optimize=True)
        print(f"✅ Flutter   → {fp}")
        mp = os.path.join(fd, f"Icon-maskable-{sz}.png")
        shutil.copy2(fp, mp)
        print(f"✅ Maskable  → {mp}")

    print("\n🎉 الأيقونات الجديدة جاهزة!")


if __name__ == "__main__":
    main()
