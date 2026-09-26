"""Curiosity ads: 3 concepts × 3 hooks, Taglish, 9:16 (TikTok / Reels / Shorts).

  ./record_curious.sh <Debug Pesolita.app>      # extra app clips → recordings/
  python3 curious_ad.py                          # all nine variants
  python3 curious_ad.py A2 C2                    # just these

Each variant is a hook followed by its concept's body. Phone screens are the real app from
recordings/. The people are Google Vids (Omni) clips in veo/curious/, speaking their own
Taglish lines; the narrator is one Vids voiceover take (voice Kaci) in
voiceover/vo-curious.wav, cut per line by VO below. Each scene carries its own sound (the
actor, or its voiceover line) and the music ducks under it. Output:
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
VO_FILE = Path("voiceover/vo-curious.wav")
W, H, FPS = 1080, 1920, 30
PHONE_W, PHONE_H, BEZEL = 800, 1738, 22
PX = (W - PHONE_W) // 2
work = Path("build-curious")
work.mkdir(exist_ok=True)
OUT.mkdir(exist_ok=True)

# Narrator lines in vo-curious.wav: (start, end) in seconds, from a word-timed transcript.
VO = [
    (0.25, 2.66),    # 0  Where did your twenty-five thousand go this month?
    (3.30, 6.90),    # 1  You're not gastador. You just don't know where it went.
    (7.50, 11.04),   # 2  Buti na lang, there's an app that shows you exactly where.
    (11.26, 13.66),  # 3  Plus how much you can safely spend today.
    (14.12, 16.86),  # 4  Four seconds lang to log every gastos.
    (17.14, 19.48),  # 5  Pesolita. Free on the App Store.
    (19.78, 22.24),  # 6  This isn't a bank app. It's a budget app.
    (22.48, 24.96),  # 7  The budget app you'll actually want to open.
    (25.20, 30.36),  # 8  All your money, in one wallet. And you see what's safe to spend on every card.
    (31.00, 33.54),  # 9  Seventy-plus card designs, pang-Pinoy.
    (33.88, 36.64),  # 10 Light or dark, always maganda.
    (36.90, 40.24),  # 11 How much does your barkada owe you? You don't know, 'no?
    (41.30, 44.14),  # 12 Three weeks later... nasa Boracay na siya. (unused: the actor says it)
    (45.08, 48.00),  # 13 Pesolita remembers who owes you, and how much.
    (48.66, 50.64),  # 14 Paid back? Just slide.
    (50.78, 52.82),  # 15 And it tracks your own spending too.
    (53.72, 55.34),  # 16 Tag mo na yung may utang sa'yo!
]


# A scene is a dict. kind: "phone" (real app clip), "ai" (Vids clip), "text" (text card),
# "end" (end card). Caption lines: (text, "w" white | "g" gold); no emoji, Outfit has none.
# vo: narrator line index; talk: keep the actor's own voice at full level.
def phone(clip, start, dur, *lines, vo=None, motion="still"):
    return dict(kind="phone", src=REC / clip, start=start, dur=dur, lines=lines, vo=vo, motion=motion)


def ai(clip, start, dur, *lines, vo=None, talk=False):
    return dict(kind="ai", src=AI / clip, start=start, dur=dur, lines=lines, vo=vo, talk=talk)


def text(dur, *lines, vo=None):
    return dict(kind="text", dur=dur, lines=lines, vo=vo)


CONCEPTS = {
    "A": {
        "slug": "sahod",
        "tagline": "Bawat piso, may lugar.",
        "extra": None,
        "end_vo": 5,
        "hooks": {
            "A1": ai("a1-payday.mp4", 1.6, 3.4, ("Day 15:", "w"), ("Sahod na!", "g"), talk=True),
            "A2": text(2.9, ("Saan napunta", "w"), ("ang ₱25,000 mo", "g"), ("this month?", "w"), vo=0),
            "A3": ai("a3-asked.mp4", 3.8, 3.2, ("POV: tinanong ka", "w"), ("kung magkano pa natira", "w"),
                     ("sa sahod mo.", "g"), talk=True),
        },
        "body": [
            ai("a-day20.mp4", 2.4, 3.8, ("You're not gastador.", "w"), ("Di mo lang alam", "g"),
               ("kung saan napunta.", "g"), vo=1),
            phone("insights.mov", 2.7, 3.8, ("May app pala", "w"), ("na nagpapakita kung saan.", "g"),
                  vo=2, motion="drift"),
            phone("safe.mov", 2.9, 2.8, ("Pati kung magkano lang", "w"), ("ang safe gastusin today.", "g"),
                  vo=3, motion="drift"),
            phone("coffee.mov", 3.6, 3.2, ("4 seconds lang", "w"), ("bawat gastos.", "g"), vo=4),
            ai("a-outro.mp4", 3.9, 4.1, ("Ngayon, alam ko na", "w"), ("kung saan napupunta.", "g"), talk=True),
        ],
    },
    "B": {
        "slug": "wallet",
        "tagline": "Bawat piso, may lugar.",
        "extra": None,
        "end_vo": 5,
        "hooks": {
            "B1": ai("b1-wallet.mp4", 4.9, 3.3, ("Yung wallet mo", "w"), ("vs. yung wallet ko.", "g"), talk=True),
            "B2": phone("swipe.mov", 6.2, 2.8, ("Hindi 'to bank app.", "w"), ("Budget app 'to.", "g"), vo=6),
            "B3": phone("detail.mov", 3.0, 2.8, ("Ang budget app", "w"), ("na gusto mo talagang", "g"),
                        ("buksan.", "g"), vo=7),
        },
        "body": [
            phone("swipe.mov", 2.9, 5.5, ("Lahat ng pera mo, isang wallet.", "w"),
                  ("Kita mo agad ang safe gastusin.", "g"), vo=8),
            phone("templates.mov", 4.3, 3.0, ("70+ card designs", "w"), ("na pang-Pinoy.", "g"), vo=9,
                  motion="drift"),
            phone("theme.mov", 3.3, 3.1, ("Light o dark.", "w"), ("Laging maganda.", "g"), vo=10),
            ai("b-outro.mp4", 4.3, 3.0, ("“Uy, ang ganda niyan!”", "g"), talk=True),
        ],
    },
    "C": {
        "slug": "utang",
        "tagline": "Split bills. Track every peso.",
        "extra": "Tag mo yung may utang sa'yo",
        "end_vo": 16,
        "hooks": {
            "C1": ai("c1-promise.mp4", 2.0, 3.2, ("Yung friend mong", "w"), ("“bayaran kita bukas”", "g"),
                     talk=True),
            "C2": text(3.6, ("Magkano na utang", "w"), ("ng barkada mo sa'yo?", "g"), ("(Di mo alam, 'no?)", "w"),
                       vo=11),
            "C3": ai("c3-chat.mp4", 4.3, 2.9, ("POV: ikaw lagi", "w"), ("yung nag-aabono.", "g"), talk=True),
        },
        "body": [
            ai("c-later.mp4", 1.0, 2.8, ("3 weeks later...", "w"), ("nasa Boracay na siya.", "g"), talk=True),
            phone("owed.mov", 2.9, 3.3, ("Alam ng Pesolita", "w"), ("kung sino'ng may utang.", "g"), vo=13),
            phone("slide.mov", 3.0, 3.4, ("Bayad na?", "w"), ("Slide mo lang.", "g"), vo=14),
            ai("c-outro.mp4", 3.1, 2.3, ("Bayad na!", "g"), talk=True),
            phone("insights.mov", 2.7, 2.8, ("Pati sarili mong gastos,", "w"), ("tracked.", "g"), vo=15,
                  motion="drift"),
        ],
    },
}
END = 3.0
COLORS = {"w": WHITE, "g": GOLD}
VENC = ["-r", str(FPS), "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-an"]


def run(args):
    subprocess.run(["ffmpeg", "-v", "error", "-y", *args], check=True)


def fit(d, lines, size, max_w):
    """Largest size (from `size` down) at which every line fits max_w."""
    while any(text_width(d, t, outfit(size, 850), size, 850) > max_w for t, _ in lines):
        size -= 4
    return size


def caption_png(path, lines, scrim=False):
    """Top-zone caption (text from y 270, below TikTok / Reels tabs). Centred, heavy.
    AI footage gets a soft dark wash from the top of the frame so the text reads on any shot."""
    h, top = (900, 270) if scrim else (500, 40)
    img = Image.new("RGBA", (W, h), (0, 0, 0, 0))
    if scrim:
        wash = Image.new("L", (1, h))
        for y in range(h):
            wash.putpixel((0, y), int(180 * (1 - y / h) ** 0.9))
        img = Image.new("RGBA", (W, h), (0, 0, 0, 255))
        img.putalpha(wash.resize((W, h)))
    d = ImageDraw.Draw(img)
    size = fit(d, lines, 84 if len(lines) > 2 else 96, W - 120)
    step = round(size * 1.2)
    for i, (t, c) in enumerate(lines):
        font = outfit(size, 850)
        w = text_width(d, t, font, size, 850)
        draw_text(d, ((W - w) / 2, top + i * step), t, font, size, 850, COLORS[c] + (255,))
    img.save(path)


def text_card_png(path, lines):
    """Full-screen text on the app's dark background, in the clear middle of the frame, left
    of the platform buttons on the right edge."""
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


def phone_video(out, s, cap, first):
    dur, top = s["dur"], (660 if len(s["lines"]) > 2 else 600)
    y = f"{top}-120*t/{dur}" if s["motion"] == "drift" else f"{top}"
    cf, cy = cap_filter(first)
    graph = (
        f"[1:v]setpts=PTS-STARTPTS,fps={FPS},tpad=stop_mode=clone:stop_duration=8,"
        f"trim=duration={dur},scale={PHONE_W}:{PHONE_H},format=rgba[v];"
        f"[2:v]format=gray,scale={PHONE_W}:{PHONE_H}[m];[v][m]alphamerge[phone];"
        f"[5:v]{cf}[cap];"
        f"[0:v][4:v]overlay=x={PX - BEZEL - 100}:y='{y}-{BEZEL}-100':eval=frame[a];"
        f"[a][3:v]overlay=x={PX - BEZEL}:y='{y}-{BEZEL}':eval=frame[b];"
        f"[b][phone]overlay=x={PX}:y='{y}':eval=frame[c];"
        f"[c][cap]overlay=x=0:y='{cy}':eval=frame,format=yuv420p[out]"
    )
    run(["-loop", "1", "-t", str(dur), "-i", "bg.png", "-ss", str(s["start"]), "-i", str(s["src"]),
         "-loop", "1", "-t", str(dur), "-i", "mask.png", "-loop", "1", "-t", str(dur), "-i", "bezel.png",
         "-loop", "1", "-t", str(dur), "-i", "shadow.png", "-loop", "1", "-t", str(dur), "-i", str(cap),
         "-filter_complex", graph, "-map", "[out]", "-t", str(dur), *VENC, str(out)])


def ai_video(out, s, cap, first):
    # Vids renders 9:16 at 720p: scale up to fill 1080×1920.
    cf, cy = cap_filter(first)
    graph = (
        f"[0:v]setpts=PTS-STARTPTS,fps={FPS},scale={W}:{H}:force_original_aspect_ratio=increase,"
        f"crop={W}:{H},tpad=stop_mode=clone:stop_duration=4,trim=duration={s['dur']}[v];"
        f"[1:v]{cf}[cap];[v][cap]overlay=x=0:y='{cy}-230':eval=frame,format=yuv420p[out]"
    )
    run(["-ss", str(s["start"]), "-i", str(s["src"]), "-loop", "1", "-t", str(s["dur"]), "-i", str(cap),
         "-filter_complex", graph, "-map", "[out]", "-t", str(s["dur"]), *VENC, str(out)])


def still_video(out, png, dur, settle=True):
    # A gentle settle-in: starts 5% larger and eases to rest. None on a first frame, so the
    # thumbnail is crisp.
    vf = (f"scale=w='iw*(1+0.05*pow(1-min(t/0.6\\,1)\\,3))':h=-2:eval=frame,crop={W}:{H},format=yuv420p"
          if settle else "format=yuv420p")
    run(["-loop", "1", "-t", str(dur), "-i", str(png), "-vf", vf, "-t", str(dur), *VENC, str(out)])


def scene_audio(out, s):
    """The scene's own sound: the actor (full level when they talk, low ambience otherwise)
    and/or its narrator line, 0.15 s after the cut. Padded to the exact sample count so the
    scenes join without drift."""
    n = round(s["dur"] * 44100)
    fit_len = f"aformat=sample_rates=44100:channel_layouts=stereo"
    pad = f"apad=whole_len={n},atrim=end_sample={n}"
    inputs, parts = [], []
    if s["kind"] == "ai":
        inputs += ["-ss", str(s["start"]), "-i", str(s["src"])]
        parts.append(f"[{len(parts)}:a]{fit_len},volume={1.0 if s.get('talk') else 0.3},{pad}")
    if s.get("vo") is not None:
        a, b = VO[s["vo"]]
        inputs += ["-ss", str(a), "-to", str(b), "-i", str(VO_FILE)]
        parts.append(f"[{len(parts)}:a]{fit_len},volume=1.5,adelay=150:all=1,{pad}")
    if not parts:
        inputs += ["-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo"]
        parts.append(f"[0:a]{fit_len},atrim=end_sample={n}")
    labels = "".join(f"[p{i}]" for i in range(len(parts)))
    graph = ";".join(f"{p}[p{i}]" for i, p in enumerate(parts))
    # amix with a single input truncates it, so one sound goes straight through.
    mix = f"amix=inputs={len(parts)}:normalize=0:duration=longest," if len(parts) > 1 else ""
    graph += f";{labels}{mix}{pad}[a]"
    run([*inputs, "-filter_complex", graph, "-map", "[a]", str(out)])


def render_scene(key, s, first):
    """Renders a scene's picture (<key>-v.mp4) and sound (<key>.wav) separately. They're joined
    per variant as picture and uncompressed sound, so no per-scene audio padding builds up
    into lip-sync drift."""
    video, audio = work / f"{key}-v.mp4", work / f"{key}.wav"
    if s["kind"] == "text":
        png = work / f"{key}.png"
        text_card_png(png, s["lines"])
        still_video(video, png, s["dur"], settle=not first)
    elif s["kind"] == "end":
        still_video(video, s["png"], s["dur"])
    else:
        cap = work / f"{key}-cap.png"
        caption_png(cap, s["lines"], scrim=s["kind"] == "ai")
        (ai_video if s["kind"] == "ai" else phone_video)(video, s, cap, first)
    scene_audio(audio, s)
    return key


def music(length):
    path = work / f"music-{length:g}.wav"
    if not path.exists():
        subprocess.run([sys.executable, "make_music.py", f"{length:g}", str(path)], check=True,
                       stdout=subprocess.DEVNULL)
    return path


def render_variant(vid):
    concept = CONCEPTS[vid[0]]
    hook = concept["hooks"][vid]
    keys = [render_scene(f"{vid}-hook", hook, True)]
    # The body and end card are shared by the concept's three hooks, so they're rendered once.
    for i, scene in enumerate(concept["body"]):
        key = f"{vid[0]}-body{i}"
        keys.append(key if (work / f"{key}.wav").exists() else render_scene(key, scene, False))
    key = f"{vid[0]}-end"
    if not (work / f"{key}.wav").exists():
        png = work / f"{key}.png"
        end_png(png, concept["tagline"], concept["extra"])
        render_scene(key, dict(kind="end", png=png, dur=END, vo=concept["end_vo"]), False)
    keys.append(key)

    length = round(hook["dur"] + sum(s["dur"] for s in concept["body"]) + END, 2)
    for ext, name in (("-v.mp4", "video"), (".wav", "audio")):
        (work / f"{vid}-{name}.txt").write_text("".join(f"file '{k}{ext}'\n" for k in keys))
    run(["-f", "concat", "-safe", "0", "-i", str(work / f"{vid}-video.txt"), "-c", "copy", str(work / f"{vid}-cut.mp4")])
    run(["-f", "concat", "-safe", "0", "-i", str(work / f"{vid}-audio.txt"), "-c", "copy", str(work / f"{vid}-cut.wav")])
    out = OUT / f"pesolita-{vid}-{concept['slug']}-9x16.mp4"
    # Music under everything, ducking whenever someone speaks.
    run([
        "-i", str(work / f"{vid}-cut.mp4"), "-i", str(work / f"{vid}-cut.wav"), "-i", str(music(length)),
        "-filter_complex",
        "[1:a]asplit[voice][key];[2:a]volume=0.8[mus];"
        "[mus][key]sidechaincompress=threshold=0.02:ratio=8:attack=15:release=300[bed];"
        f"[bed][voice]amix=inputs=2:duration=longest:normalize=0,alimiter=limit=0.89:level=0,"
        f"afade=t=out:st={length - 0.6}:d=0.6[a]",
        "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
        "-t", str(length), "-movflags", "+faststart", str(out),
    ])
    print(out, f"{length:g}s")
    return out


if __name__ == "__main__":
    # Scenes are cached in build-curious/; delete it after changing a caption, clip or line.
    wanted = sys.argv[1:] or [v for c in CONCEPTS.values() for v in c["hooks"]]
    for vid in wanted:
        render_variant(vid)
