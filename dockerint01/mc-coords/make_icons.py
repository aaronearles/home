"""Regenerate the PWA icons (pixel-art grass block with a map pin). Requires Pillow."""
from pathlib import Path
from PIL import Image

OUT = Path(__file__).parent / "public" / "icons"
G, g, D, d, P, p, W, _ = (
    (94, 168, 60), (70, 135, 45), (134, 96, 67), (105, 74, 50),
    (179, 136, 255), (126, 87, 194), (255, 255, 255), None,
)
ART = [  # 16x16
    "GGgGGGGgGGGgGGGG",
    "GgGGGgGGGGGGGgGG",
    "GGGGgGGPPPPGGGgG",
    "gGGGGGPPPPPPGGGG",
    "GGgGGPPPWWPPPgGG",
    "GDGGgPPWWWWPPGgD",
    "DDdDDPPWWWWPPDDD",
    "DdDDDPPPWWPPPdDD",
    "DDDdDDPPPPPPDDDD",
    "dDDDDDpPPPPpDDdD",
    "DDdDDDDpPPpDDDDD",
    "DDDDdDDDpPDDDdDD",
    "DdDDDDdDDpDDDDDD",
    "DDDdDDDDDDDdDDDd",
    "DDDDDDdDDDDDDDDD",
    "dDDdDDDDDdDDDdDD",
]
PAL = {"G": G, "g": g, "D": D, "d": d, "P": P, "p": p, "W": W}


def tile(size, pad=0):
    small = Image.new("RGBA", (16, 16))
    for y, row in enumerate(ART):
        for x, ch in enumerate(row):
            small.putpixel((x, y), PAL[ch] + (255,))
    inner = size - 2 * pad
    big = small.resize((inner, inner), Image.NEAREST)
    out = Image.new("RGBA", (size, size), (18, 18, 18, 255))
    out.paste(big, (pad, pad))
    return out


OUT.mkdir(parents=True, exist_ok=True)
tile(192).save(OUT / "icon-192.png")
tile(512).save(OUT / "icon-512.png")
tile(512, pad=64).save(OUT / "icon-maskable-512.png")
tile(180).convert("RGB").save(OUT / "apple-touch-icon.png")
