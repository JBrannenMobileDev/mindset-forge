"""Generate marketing assets for the MindsetForge README.

Wraps raw app screenshots in device frames and composes a branded hero
banner. Run from the repo root:

    python docs/tools/generate_assets.py

Requires Pillow. Brand fonts (Space Grotesk + Inter) are downloaded if
available, otherwise the script falls back to a bold system font.
"""

from __future__ import annotations

import os
import urllib.request

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHOTS = os.path.join(ROOT, "docs", "screenshots")
FRAMED = os.path.join(SHOTS, "framed")
FONTS = os.path.join(ROOT, "docs", "tools", ".fonts")

# Brand palette (from lib/core/constants/app_colors.dart)
BG = (10, 10, 15)
BEZEL = (18, 18, 24, 255)
BEZEL_EDGE = (58, 58, 74, 255)
PRIMARY = (155, 64, 255)
SECONDARY = (0, 229, 255)
TEXT_PRIMARY = (240, 239, 248)
TEXT_SECONDARY = (139, 139, 160)

FONT_SOURCES = {
    "grotesk": "https://github.com/google/fonts/raw/main/ofl/spacegrotesk/SpaceGrotesk%5Bwght%5D.ttf",
    "inter": "https://github.com/google/fonts/raw/main/ofl/inter/Inter%5Bopsz,wght%5D.ttf",
}


def _download_fonts() -> dict[str, str]:
    os.makedirs(FONTS, exist_ok=True)
    paths = {}
    for key, url in FONT_SOURCES.items():
        dest = os.path.join(FONTS, f"{key}.ttf")
        if not os.path.exists(dest):
            try:
                urllib.request.urlretrieve(url, dest)
            except Exception as exc:  # noqa: BLE001
                print(f"  font download failed ({key}): {exc}")
                continue
        paths[key] = dest
    return paths


def _load_font(paths: dict[str, str], key: str, size: int, weight: str | None = None):
    fallbacks = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial.ttf",
    ]
    if key in paths:
        try:
            font = ImageFont.truetype(paths[key], size)
            if weight:
                try:
                    font.set_variation_by_name(weight)
                except Exception:  # noqa: BLE001
                    pass
            return font
        except Exception:  # noqa: BLE001
            pass
    for fb in fallbacks:
        if os.path.exists(fb):
            try:
                return ImageFont.truetype(fb, size)
            except Exception:  # noqa: BLE001
                continue
    return ImageFont.load_default()


def _rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255
    )
    return mask


def frame_phone(shot: Image.Image, scale: int = 2) -> Image.Image:
    """Return an RGBA device-framed phone with a soft drop shadow."""
    shot = shot.convert("RGBA")
    w, h = shot.size
    w2, h2 = w * scale, h * scale
    shot = shot.resize((w2, h2), Image.LANCZOS)

    screen_radius = int(0.085 * w2)
    shot.putalpha(_rounded_mask((w2, h2), screen_radius))

    bezel = max(2, int(0.028 * w2))
    fw, fh = w2 + bezel * 2, h2 + bezel * 2
    frame_radius = screen_radius + bezel

    frame = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    fd = ImageDraw.Draw(frame)
    fd.rounded_rectangle([0, 0, fw - 1, fh - 1], radius=frame_radius, fill=BEZEL)
    fd.rounded_rectangle(
        [0, 0, fw - 1, fh - 1], radius=frame_radius, outline=BEZEL_EDGE, width=max(1, scale)
    )
    frame.paste(shot, (bezel, bezel), shot)

    pad = bezel * 5
    canvas = Image.new("RGBA", (fw + pad * 2, fh + pad * 2), (0, 0, 0, 0))
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [pad, pad + bezel, pad + fw, pad + fh + bezel],
        radius=frame_radius,
        fill=(0, 0, 0, 170),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(bezel * 1.6))
    canvas = Image.alpha_composite(canvas, shadow)
    canvas.paste(frame, (pad, pad), frame)
    return canvas


def build_frames() -> None:
    os.makedirs(FRAMED, exist_ok=True)
    for name in sorted(os.listdir(SHOTS)):
        if not name.endswith(".png"):
            continue
        src = os.path.join(SHOTS, name)
        out = os.path.join(FRAMED, name)
        frame_phone(Image.open(src)).save(out)
        print(f"  framed {name}")


def _vertical_glow(size: tuple[int, int]) -> Image.Image:
    """Dark background with a radial purple glow behind the phones."""
    w, h = size
    bg = Image.new("RGB", size, BG)
    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy = int(w * 0.68), int(h * 0.42)
    rr = int(h * 0.62)
    gd.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(*PRIMARY, 70))
    cx2, cy2 = int(w * 0.9), int(h * 0.85)
    rr2 = int(h * 0.4)
    gd.ellipse([cx2 - rr2, cy2 - rr2, cx2 + rr2, cy2 + rr2], fill=(*SECONDARY, 28))
    glow = glow.filter(ImageFilter.GaussianBlur(int(h * 0.12)))
    return Image.alpha_composite(bg.convert("RGBA"), glow)


def _text_with_tracking(draw, xy, text, font, fill, tracking):
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=font, fill=fill)
        bbox = draw.textbbox((0, 0), ch, font=font)
        x += (bbox[2] - bbox[0]) + tracking


def build_hero(paths: dict[str, str]) -> None:
    S = 2
    W, H = 1600 * S, 760 * S
    canvas = _vertical_glow((W, H))

    # Phone cluster on the right half.
    specs = [
        ("coach-chat.png", 0.78, -0.02),
        ("alignment-score.png", 0.78, 0.02),
        ("dashboard.png", 0.92, 0.0),
    ]
    frames = []
    for name, rel_h, _ in specs:
        ph = frame_phone(Image.open(os.path.join(SHOTS, name)), scale=2)
        target_h = int(H * rel_h)
        ratio = target_h / ph.height
        frames.append(ph.resize((int(ph.width * ratio), target_h), Image.LANCZOS))

    cx = int(W * 0.70)
    cy = H // 2
    spread = int(frames[2].width * 0.62)
    # back-left, back-right, then center on top
    positions = [
        (cx - spread - frames[0].width // 2, cy - frames[0].height // 2 + int(H * 0.04)),
        (cx + spread - frames[1].width // 2, cy - frames[1].height // 2 + int(H * 0.04)),
        (cx - frames[2].width // 2, cy - frames[2].height // 2),
    ]
    order = [0, 1, 2]
    for i in order:
        canvas.alpha_composite(frames[i], positions[i])

    draw = ImageDraw.Draw(canvas)
    pad = int(W * 0.055)
    kicker_font = _load_font(paths, "inter", 26 * S, "Medium")
    title_font = _load_font(paths, "grotesk", 104 * S, "Bold")
    tag_font = _load_font(paths, "inter", 34 * S, "Regular")

    ty = int(H * 0.30)
    _text_with_tracking(
        draw, (pad, ty), "AI-POWERED MINDSET COACHING", kicker_font, PRIMARY, 4 * S
    )

    ty += int(60 * S)
    draw.text((pad, ty), "Mindset", font=title_font, fill=TEXT_PRIMARY)
    mw = draw.textbbox((pad, ty), "Mindset", font=title_font)[2]
    draw.text((mw, ty), "Forge", font=title_font, fill=PRIMARY)

    ty += int(150 * S)
    draw.text(
        (pad, ty),
        "Rewire your mindset.\nForge your future.",
        font=tag_font,
        fill=TEXT_SECONDARY,
        spacing=int(12 * S),
    )

    out = canvas.convert("RGB").resize((1600, 760), Image.LANCZOS)
    out.save(os.path.join(ROOT, "docs", "hero.png"), quality=95)
    print("  hero -> docs/hero.png")


def main() -> None:
    print("Downloading brand fonts...")
    paths = _download_fonts()
    print("Building device frames...")
    build_frames()
    print("Building hero banner...")
    build_hero(paths)
    print("Done.")


if __name__ == "__main__":
    main()
