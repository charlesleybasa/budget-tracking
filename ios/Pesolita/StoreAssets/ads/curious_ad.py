"""Curiosity ads: 3 concepts × 3 hooks, Taglish, 9:16 (TikTok / Reels / Shorts).

  ./record_curious.sh <Debug Pesolita.app>      # extra app clips → recordings/
  python3 curious_ad.py                          # every variant whose clips exist
  python3 curious_ad.py A2 C2                    # just these

Each variant is a 2.5 s hook followed by its concept's body, so all three hooks of a concept
share the same body timing. Phone screens are the real app from recordings/. People shots are
AI clips from Google Vids in veo/curious/ (see CURIOSITY-BRIEF.md). A missing people shot in a
body becomes a text card; a variant whose hook needs a missing clip is skipped. Output:
curious/pesolita-<variant>-9x16.mp4. Social platforms only, never an App Store preview.
"""
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

from make_assets import GOLD, INK, WHITE, draw_text, outfit, text_width

REC = Path("recordings")
AI = Path("veo/curious")
OUT = Path("curious")
W, H, FPS = 1080, 1920, 30
PHONE_W, PHONE_H, BEZEL = 800, 1738, 22
PX = (W - PHONE_W) // 2
work = Path("build-curious")
work.mkdir(exist_ok=True)
OUT.mkdir(exist_ok=True)

# A scene: (kind, source, in-point s, length s, caption lines, motion)
# kind: "phone" (real app clip), "ai" (Vids clip; text card if missing), "text" (text card).
# Caption lines: (text, "w" white | "g" gold). No emoji: Outfit has none.
def phone(clip, start, dur, *lines, motion="still"):
    return ("phone", REC / clip, start, dur, lines, motion)


def ai(clip, start, dur, *lines):
    return ("ai", AI / clip, start, dur, lines, None)


def text(dur, *lines):
    return ("text", None, 0, dur, lines, None)


CONCEPTS = {
    "A": {
        "slug": "sahod",
        "tagline": "Bawat piso, may lugar.",
        "extra": None,
        "hooks": {
            "A1": ai("a1-payday.mp4", 1.0, 2.5, ("Day 15: sahod na!", "w"), ("Day 20: ubos na?!", "g")),
            "A2": text(2.5, ("Saan napunta", "w"), ("ang ₱25,000 mo", "g"), ("this month?", "w")),
            "A3": ai("a3-asked.mp4", 1.0, 2.5, ("POV: tinanong ka", "w"), ("kung magkano pa", "w"),
                     ("natira sa sahod mo.", "g")),
        },
        "body": [
            ai("a-day20.mp4", 1.0, 2.5, ("Hindi ka gastador.", "w"), ("Di mo lang alam", "g"),
               ("kung saan napunta.", "g")),
            phone("insights.mov", 2.7, 4.0, ("May app pala", "w"), ("na magsasabi kung saan.", "g"),
                  motion="drift"),
            phone("safe.mov", 2.9, 3.5, ("Pati kung magkano lang", "w"), ("pwede mong gastusin today.", "g"), motion="drift"),
            phone("coffee.mov", 3.6, 3.0, ("4 seconds lang", "w"), ("bawat gastos.", "g")),
        ],
    },
    "B": {
        "slug": "wallet",
        "tagline": "Bawat piso, may lugar.",
        "extra": None,
        "hooks": {
            "B1": ai("b1-wallet.mp4", 1.0, 2.5, ("Yung wallet mo", "w"), ("vs. yung wallet ko.", "g")),
            "B2": phone("swipe.mov", 6.2, 2.5, ("Hindi 'to bank app.", "w"), ("Budget app 'to.", "g")),
            "B3": phone("detail.mov", 3.0, 2.5, ("Ang budget app", "w"), ("na gusto mo talagang", "g"),
                        ("buksan.", "g")),
        },
        "body": [
            phone("swipe.mov", 2.9, 4.0, ("Lahat ng pera mo,", "w"), ("isang wallet lang.", "g")),
            phone("templates.mov", 4.3, 4.0, ("70+ card designs", "w"), ("na pang-Pinoy.", "g"), motion="drift"),
            phone("theme.mov", 3.3, 3.0, ("Light o dark.", "w"), ("Laging maganda.", "g")),
        ],
    },
    "C": {
        "slug": "utang",
        "tagline": "Bawat piso, may lugar.",
        "extra": "Tag mo yung may utang sa'yo",
        "hooks": {
            "C1": ai("c1-promise.mp4", 1.0, 2.5, ("Yung friend mong", "w"), ("“bayaran kita bukas”", "g")),
            "C2": text(2.5, ("Magkano na utang", "w"), ("ng barkada mo sa'yo?", "g"), ("(Di mo alam, 'no?)", "w")),
            "C3": ai("c3-chat.mp4", 1.0, 2.5, ("POV: ikaw lagi", "w"), ("yung nag-aabono.", "g")),
        },
        "body": [
            ai("c-later.mp4", 1.0, 2.5, ("3 weeks later...", "w"), ("nasa Boracay na siya.", "g")),
            phone("owed.mov", 2.9, 3.5, ("Alam ng Pesolita", "w"), ("kung sino'ng may utang.", "g")),
            phone("people.mov", 3.0, 3.0, ("Magkano, sino,", "w"), ("saang lakad.", "g"), motion="drift"),
            phone("slide.mov", 3.0, 3.5, ("Bayad na?", "w"), ("Slide mo lang.", "g")),
        ],
    },
}
END = 3.0
COLORS = {"w": WHITE, "g": GOLD}
ENC = ["-r", str(FPS), "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
       "-c:a", "aac", "-ar", "44100", "-ac", "2"]


def run(args):
    subprocess.run(["ffmpeg", "-v", "error", "-y", *args], check=True)


def fit(d, lines, size, max_w):
    """Largest size (from `size` down) at which every line fits max_w."""
    while any(text_width(d, t, outfit(size, 850), size, 850) > max_w for t, _ in lines):
        size -= 4
    return size


def caption_png(path, lines, scrim=False):
    """Top-zone caption (y 230–470 on screen, below TikTok / Reels tabs). Centred, heavy."""
    # AI footage gets a soft dark wash from the top of the frame so the text reads on any
    # shot; that image is placed at y 0 and its text starts 230 px lower.
    h, top = (900, 270) if scrim else (500, 40)
    img = Image.new("RGBA", (W, h), (0, 0, 0, 0))
    if scrim:
        wash = Image.new("L", (1, h))
        for y in range(h):
            wash.putpixel((0, y), int(180 * (1 - y / h) ** 0.9))
        img = Image.new("RGBA", (W, h), (0, 0, 0, 255))
        img.putalpha(wash.resize((W, h)))
    d = ImageDraw.Draw(img)
    three = len(lines) > 2
    size = fit(d, lines, 84 if three else 96, W - 120)
    step = round(size * 1.2)
    for i, (t, c) in enumerate(lines):
        font = outfit(size, 850)
        w = text_width(d, t, font, size, 850)
        draw_text(d, ((W - w) / 2, top + i * step), t, font, size, 850, COLORS[c] + (255,))
    img.save(path)


def text_card_png(path, lines):
    """Full-screen text on the app's dark background. Sits in the clear middle of the frame,
    left of the platform buttons on the right edge."""
    img = Image.open("bg.png").convert("RGBA")
    d = ImageDraw.Draw(img)
    size = fit(d, lines, 124, 880)
    step = round(size * 1.18)
    y0 = 860 - (len(lines) * step) // 2
    for i, (t, c) in enumerate(lines):
        font = outfit(size, 850)
        w = text_width(d, t, font, size, 850)
        draw_text(d, (60 + (880 - w) / 2, y0 + i * step), t, font, size, 850, COLORS[c] + (255,))
    img.convert("RGB").save(path)


def end_png(path, tagline, extra):
    img = Image.open("bg.png").convert("RGBA")
    icon = Image.open("../../Pesolita/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png").convert("RGBA").resize((300, 300))
    m = Image.new("L", icon.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, 299, 299), 68, fill=255)
    icon.putalpha(m)
    img.alpha_composite(icon, ((W - 300) // 2, 500))
    d = ImageDraw.Draw(img)

    def centred(t, y, font, color):
        d.text(((W - d.textlength(t, font=font)) / 2, y), t, font=font, fill=color)

    centred("Pesolita", 880, outfit(150, 900), WHITE)
    centred(tagline, 1080, outfit(58, 500), (200, 200, 208))
    # A plain pill, not Apple's badge artwork: the badge has its own usage rules.
    pill_font = outfit(52, 800)
    label = "Libre sa App Store"
    pw = d.textlength(label, font=pill_font) + 110
    x0 = (W - pw) / 2
    d.rounded_rectangle((x0, 1260, x0 + pw, 1392), 66, fill=GOLD)
    centred(label, 1290, pill_font, INK)
    if extra:
        centred(extra, 1430, outfit(50, 700), WHITE)
    img.convert("RGB").save(path)


# Captions rise in over 0.4 s with a fade, except on a variant's first frame: that frame is
# the thumbnail and the scroll-stopper, so its caption is already there.
def cap_filter(first):
    if first:
        return "format=rgba", "230"
    return ("format=rgba,fade=t=in:st=0.1:d=0.3:alpha=1",
            "230+50*pow(1-min(max(t-0.1\\,0)/0.4\\,1)\\,3)")


def silence(dur):
    return f"anullsrc=r=44100:cl=stereo,atrim=duration={dur}[a]"


def phone_scene(out, src, start, dur, cap, motion, first, three):
    top = 660 if three else 600
    y = f"{top}-120*t/{dur}" if motion == "drift" else f"{top}"
    cf, cy = cap_filter(first)
    graph = (
        f"[1:v]setpts=PTS-STARTPTS,fps={FPS},tpad=stop_mode=clone:stop_duration=8,"
        f"trim=duration={dur},scale={PHONE_W}:{PHONE_H},format=rgba[v];"
        f"[2:v]format=gray,scale={PHONE_W}:{PHONE_H}[m];[v][m]alphamerge[phone];"
        f"[5:v]{cf}[cap];"
        f"[0:v][4:v]overlay=x={PX - BEZEL - 100}:y='{y}-{BEZEL}-100':eval=frame[a];"
        f"[a][3:v]overlay=x={PX - BEZEL}:y='{y}-{BEZEL}':eval=frame[b];"
        f"[b][phone]overlay=x={PX}:y='{y}':eval=frame[c];"
        f"[c][cap]overlay=x=0:y='{cy}':eval=frame,format=yuv420p[out];" + silence(dur)
    )
    run([
        "-loop", "1", "-t", str(dur), "-i", "bg.png",
        "-ss", str(start), "-i", str(src),
        "-loop", "1", "-t", str(dur), "-i", "mask.png",
        "-loop", "1", "-t", str(dur), "-i", "bezel.png",
        "-loop", "1", "-t", str(dur), "-i", "shadow.png",
        "-loop", "1", "-t", str(dur), "-i", str(cap),
        "-filter_complex", graph, "-map", "[out]", "-map", "[a]", "-t", str(dur), *ENC, str(out),
    ])


def ai_scene(out, src, start, dur, cap, first):
    # Vids renders 16:9: fill 9:16 from the centre (the brief keeps the subject centred).
    # The clip's own ambience stays, mixed low under the music later.
    cf, cy = cap_filter(first)
    graph = (
        f"[0:v]setpts=PTS-STARTPTS,fps={FPS},scale=-2:{H},crop={W}:{H},"
        f"tpad=stop_mode=clone:stop_duration=4,trim=duration={dur}[v];"
        f"[1:v]{cf}[cap];[v][cap]overlay=x=0:y='{cy}-230':eval=frame,format=yuv420p[out]"
    )
    has_audio = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "a", "-show_entries", "stream=index", "-of", "csv=p=0", str(src)],
        capture_output=True, text=True).stdout.strip()
    graph += (f";[0:a]asetpts=PTS-STARTPTS,apad,atrim=duration={dur},volume=0.35[a]" if has_audio
              else ";" + silence(dur))
    run(["-ss", str(start), "-i", str(src), "-loop", "1", "-t", str(dur), "-i", str(cap),
         "-filter_complex", graph, "-map", "[out]", "-map", "[a]", "-t", str(dur), *ENC, str(out)])


def still_scene(out, png, dur):
    # A gentle settle-in: starts 5% larger and eases to rest.
    zoom = f"scale=w='iw*(1+0.05*pow(1-min(t/0.6\\,1)\\,3))':h=-2:eval=frame,crop={W}:{H}"
    run(["-loop", "1", "-t", str(dur), "-i", str(png), "-f", "lavfi", "-t", str(dur), "-i", "anullsrc=r=44100:cl=stereo",
         "-vf", f"{zoom},format=yuv420p", "-t", str(dur), *ENC, str(out)])


def render_scene(key, scene, first):
    kind, src, start, dur, lines, motion = scene
    out = work / f"{key}.mp4"
    if kind == "ai" and not src.exists():
        kind = "text"
    if kind == "text":
        png = work / f"{key}.png"
        text_card_png(png, lines)
        # On a text card the words are the picture: no zoom on a first frame, so the
        # thumbnail is crisp.
        if first:
            run(["-loop", "1", "-t", str(dur), "-i", str(png), "-f", "lavfi", "-t", str(dur),
                 "-i", "anullsrc=r=44100:cl=stereo", "-vf", "format=yuv420p", "-t", str(dur), *ENC, str(out)])
        else:
            still_scene(out, png, dur)
        return out
    cap = work / f"{key}-cap.png"
    caption_png(cap, lines, scrim=kind == "ai")
    if kind == "ai":
        ai_scene(out, src, start, dur, cap, first)
    else:
        phone_scene(out, src, start, dur, cap, motion, first, len(lines) > 2)
    return out


def music(length):
    path = work / f"music-{length:g}.wav"
    if not path.exists():
        subprocess.run([sys.executable, "make_music.py", f"{length:g}", str(path)], check=True)
    return path


def render_variant(vid):
    concept = CONCEPTS[vid[0]]
    hook = concept["hooks"][vid]
    if hook[0] == "ai" and not hook[1].exists():
        print(f"skip {vid}: needs {hook[1]} (see CURIOSITY-BRIEF.md)")
        return None
    parts = [render_scene(f"{vid}-hook", hook, True)]
    # The body is shared by the concept's three hooks, so it's rendered once.
    for i, scene in enumerate(concept["body"]):
        key = f"{vid[0]}-body{i}"
        parts.append(work / f"{key}.mp4" if (work / f"{key}.mp4").exists() else render_scene(key, scene, False))
    end = work / f"{vid[0]}-end.mp4"
    if not end.exists():
        png = work / f"{vid[0]}-end.png"
        end_png(png, concept["tagline"], concept["extra"])
        still_scene(end, png, END)
    parts.append(end)

    length = hook[3] + sum(s[3] for s in concept["body"]) + END
    (work / f"{vid}.txt").write_text("".join(f"file '{p.name}'\n" for p in parts))
    cut = work / f"{vid}-cut.mp4"
    run(["-f", "concat", "-safe", "0", "-i", str(work / f"{vid}.txt"), "-c", "copy", str(cut)])
    out = OUT / f"pesolita-{vid}-{concept['slug']}-9x16.mp4"
    run([
        "-i", str(cut), "-i", str(music(length)),
        "-filter_complex",
        f"[0:a][1:a]amix=inputs=2:duration=first:normalize=0,alimiter=limit=0.89:level=0,"
        f"afade=t=out:st={length - 0.6}:d=0.6[a]",
        "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
        "-movflags", "+faststart", str(out),
    ])
    print(out)
    return out


if __name__ == "__main__":
    # Body scenes are cached in build-curious/; clear it after changing a caption or clip.
    wanted = sys.argv[1:] or [v for c in CONCEPTS.values() for v in c["hooks"]]
    for vid in wanted:
        render_variant(vid)
