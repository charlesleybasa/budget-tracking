"""Still assets for the Pesolita split-bills video ad (9:16, 1080×1920).

Background, phone mask and bezel, one caption image per scene, and the end card — all in the
app's own palette (ink, Pesolita gold, blue) and typeface (Outfit). Run from StoreAssets/ads/.
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1080, 1920
INK = (11, 11, 13)
GOLD = (255, 202, 40)
BLUE = (29, 111, 242)
WHITE = (245, 244, 240)
FONT = "../build/Outfit.ttf"

# Phone: the capture is 1320×2868; shown 800 wide.
PHONE_W = 800
PHONE_H = round(PHONE_W * 2868 / 1320)
RADIUS = 118
BEZEL = 22


def outfit(size, weight):
    font = ImageFont.truetype(FONT, size)
    font.set_variation_by_axes([weight])
    return font


def peso_font(size, weight):
    """Outfit has no ₱; iOS falls back to SF for it in the app, so the ad does the same."""
    font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", size)
    try:
        font.set_variation_by_axes([weight])
    except Exception:
        pass
    return font


def runs(text, font, size, weight):
    """Splits text into (piece, font) runs so ₱ is drawn in SF and the rest in Outfit."""
    out, buf = [], ""
    for ch in text:
        if ch == "₱":
            if buf:
                out.append((buf, font))
                buf = ""
            out.append(("₱", peso_font(int(size * 0.94), weight)))
        else:
            buf += ch
    if buf:
        out.append((buf, font))
    return out


def text_width(d, text, font, size, weight):
    return sum(d.textlength(t, font=f) for t, f in runs(text, font, size, weight))


def draw_text(d, xy, text, font, size, weight, fill):
    x, y = xy
    for t, f in runs(text, font, size, weight):
        d.text((x, y), t, font=f, fill=fill)
        x += d.textlength(t, font=f)


def glow(img, center, radius, color, alpha):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x, y = center
    d.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color + (alpha,))
    layer = layer.filter(ImageFilter.GaussianBlur(radius * 0.45))
    img.alpha_composite(layer)


def background():
    img = Image.new("RGBA", (W, H), INK + (255,))
    glow(img, (180, 260), 520, GOLD, 70)
    glow(img, (980, 1500), 620, BLUE, 80)
    glow(img, (120, 1800), 420, (124, 58, 237), 45)
    img.convert("RGB").save("bg.png")


def phone_mask_and_bezel():
    mask = Image.new("L", (PHONE_W, PHONE_H), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, PHONE_W - 1, PHONE_H - 1), RADIUS, fill=255)
    mask.save("mask.png")
    bw, bh = PHONE_W + BEZEL * 2, PHONE_H + BEZEL * 2
    bezel = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (bw + 200, bh + 200), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((100, 140, bw + 100, bh + 140), RADIUS + BEZEL, fill=(0, 0, 0, 170))
    shadow = shadow.filter(ImageFilter.GaussianBlur(60))
    shadow.save("shadow.png")
    d = ImageDraw.Draw(bezel)
    d.rounded_rectangle((0, 0, bw - 1, bh - 1), RADIUS + BEZEL, fill=(6, 6, 7, 255))
    d.rounded_rectangle((3, 3, bw - 4, bh - 4), RADIUS + BEZEL - 3, outline=(255, 255, 255, 60), width=4)
    d.rounded_rectangle((BEZEL, BEZEL, BEZEL + PHONE_W - 1, BEZEL + PHONE_H - 1), RADIUS, fill=(0, 0, 0, 0))
    bezel.save("bezel.png")


def caption(name, first, second):
    """Two lines: white, then gold. Centred, heavy, tight."""
    img = Image.new("RGBA", (W, 420), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, (text, color) in enumerate([(first, WHITE), (second, GOLD)]):
        size = 96
        font = outfit(size, 850)
        while text_width(d, text, font, size, 850) > W - 120:
            size -= 4
            font = outfit(size, 850)
        w = text_width(d, text, font, size, 850)
        draw_text(d, ((W - w) / 2, 60 + i * 118), text, font, size, 850, color + (255,))
    img.save(f"cap-{name}.png")


def end_card():
    img = Image.open("bg.png").convert("RGBA")
    icon = Image.open("../../Pesolita/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png").convert("RGBA").resize((300, 300))
    m = Image.new("L", icon.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, 299, 299), 68, fill=255)
    icon.putalpha(m)
    sh = Image.new("RGBA", (500, 500), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle((100, 130, 400, 430), 68, fill=(0, 0, 0, 160))
    sh = sh.filter(ImageFilter.GaussianBlur(40))
    img.alpha_composite(sh, ((W - 500) // 2, 430))
    img.alpha_composite(icon, ((W - 300) // 2, 500))
    d = ImageDraw.Draw(img)

    def centred(text, y, font, color):
        w = d.textlength(text, font=font)
        d.text(((W - w) / 2, y), text, font=font, fill=color)

    centred("Pesolita", 880, outfit(150, 900), WHITE)
    centred("Split bills. Track every peso.", 1080, outfit(58, 500), (200, 200, 208))
    # A plain pill, not Apple's badge artwork — the badge has its own usage rules.
    pill_font = outfit(52, 800)
    label = "Free on the App Store"
    pw = d.textlength(label, font=pill_font) + 110
    x0 = (W - pw) / 2
    d.rounded_rectangle((x0, 1260, x0 + pw, 1392), 66, fill=GOLD)
    centred(label, 1290, pill_font, INK)
    img.convert("RGB").save("end.png")


background()
phone_mask_and_bezel()
caption("hook", "Dinner was ₱3,600.", "Who owes what?")
caption("split", "Split it in one tap.", "₱720 each. Done.")
caption("event", "Every trip,", "totalled for you.")
caption("owed", "Know who", "still owes you.")
caption("slide", "Paid back?", "Slide it home.")
end_card()
print("assets ready", PHONE_W, PHONE_H)
