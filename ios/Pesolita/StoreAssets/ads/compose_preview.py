"""App Store app preview for Pesolita — iPhone 6.9" / 6.5" slot, 886 × 1920, 26 s.

  python3 make_music.py 26 music-preview.wav
  python3 compose_preview.py recordings ../raw      # recordings + still captures

Apple's rules for previews, kept on purpose:
- Only footage captured from the app (plus two still captures of the app for Insights and light
  mode). No people, hands, AI scenes or device hardware.
- Text overlays are allowed; no prices, no "download now", no Apple badge.
- 15–30 s, 30 fps, H.264, stereo AAC.
"""
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

import make_assets as A

REC = Path(sys.argv[1] if len(sys.argv) > 1 else "recordings")
STILLS = Path(sys.argv[2] if len(sys.argv) > 2 else "../raw")
W, H, FPS = 886, 1920, 30
SW = 700                              # footage width
SH = round(SW * 2868 / 1320)          # 1521
SX = (W - SW) // 2
RADIUS = 86
work = Path("build-preview")
work.mkdir(exist_ok=True)


def assets():
    bg = Image.new("RGBA", (W, H), A.INK + (255,))
    A.glow(bg, (140, 220), 460, A.GOLD, 70)
    A.glow(bg, (820, 1400), 560, A.BLUE, 80)
    A.glow(bg, (80, 1780), 380, (124, 58, 237), 45)
    bg.convert("RGB").save(work / "bg.png")

    mask = Image.new("L", (SW, SH), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, SW - 1, SH - 1), RADIUS, fill=255)
    mask.save(work / "mask.png")

    # Soft shadow and a hairline edge: depth without drawing a phone.
    pad = 120
    sh = Image.new("RGBA", (SW + pad * 2, SH + pad * 2), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle((pad, pad + 40, pad + SW, pad + SH + 40), RADIUS, fill=(0, 0, 0, 175))
    sh.filter(ImageFilter.GaussianBlur(50)).save(work / "shadow.png")
    edge = Image.new("RGBA", (SW + 4, SH + 4), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle((0, 0, SW + 3, SH + 3), RADIUS + 2, outline=(255, 255, 255, 46), width=3)
    edge.save(work / "edge.png")


def caption(name, first, second):
    img = Image.new("RGBA", (W, 300), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, (text, color) in enumerate([(first, A.WHITE), (second, A.GOLD)]):
        size = 80
        font = A.outfit(size, 850)
        while A.text_width(d, text, font, size, 850) > W - 90:
            size -= 4
            font = A.outfit(size, 850)
        w = A.text_width(d, text, font, size, 850)
        A.draw_text(d, ((W - w) / 2, 30 + i * 98), text, font, size, 850, color + (255,))
    img.save(work / f"cap-{name}.png")


def end_card():
    img = Image.open(work / "bg.png").convert("RGBA")
    icon = Image.open("../../Pesolita/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png").convert("RGBA").resize((260, 260))
    m = Image.new("L", icon.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, 259, 259), 58, fill=255)
    icon.putalpha(m)
    sh = Image.new("RGBA", (460, 460), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle((100, 130, 360, 390), 58, fill=(0, 0, 0, 160))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(36)), ((W - 460) // 2, 520))
    img.alpha_composite(icon, ((W - 260) // 2, 590))
    d = ImageDraw.Draw(img)
    for text, y, font, color in [("Pesolita", 920, A.outfit(132, 900), A.WHITE),
                                 ("Split bills. Track every peso.", 1100, A.outfit(50, 500), (200, 200, 208))]:
        w = d.textlength(text, font=font)
        d.text(((W - w) / 2, y), text, font=font, fill=color)
    img.convert("RGB").save(work / "end.png")


# name, source, kind, in-point, length, caption, motion
SCENES = [
    ("home",     REC / "home.mov",          "video", 4.20, 2.5, ("Every peso", "gets a home."), "rise"),
    ("split",    REC / "split.mov",         "video", 3.60, 4.5, ("Split any bill", "in one tap."), "still"),
    ("event",    REC / "event.mov",         "video", 3.05, 3.0, ("Trips and nights out,", "totalled for you."), "drift"),
    ("owed",     REC / "owed.mov",          "video", 2.90, 3.5, ("Know who", "still owes you."), "still"),
    ("slide",    REC / "slide.mov",         "video", 3.00, 4.5, ("Paid back?", "Slide it home."), "still"),
    ("insights", STILLS / "insights.png",   "still", 0,    3.0, ("See where", "it all went."), "drift"),
    ("light",    STILLS / "home-light.png", "still", 0,    2.5, ("Light or dark.", "Always lovely."), "drift"),
]
TOP = 372


def run(args):
    subprocess.run(["ffmpeg", "-v", "error", "-y", *args], check=True)


def scene(name, src, kind, start, dur, cap, motion):
    caption(name, *cap)
    if motion == "rise":
        y = f"{TOP}+520*pow(1-min(t/0.6\\,1)\\,3)"
    elif motion == "drift":
        y = f"{TOP}-60*t/{dur}"
    else:
        y = f"{TOP}"
    fade = "" if name == "home" else ",fade=t=in:st=0:d=0.3:alpha=1"
    cap_y = "70" if name == "home" else "70+40*pow(1-min(t/0.4\\,1)\\,3)"
    source = (["-ss", str(start), "-i", str(src)] if kind == "video"
              else ["-loop", "1", "-t", str(dur), "-i", str(src)])
    graph = (
        f"[1:v]setpts=PTS-STARTPTS,fps={FPS},tpad=stop_mode=clone:stop_duration=8,"
        f"trim=duration={dur},scale={SW}:{SH},format=rgba[v];"
        f"[2:v]format=gray[m];[v][m]alphamerge[shot];"
        f"[5:v]format=rgba{fade}[cap];"
        f"[0:v][3:v]overlay=x={SX - 120}:y='{y}-120':eval=frame[a];"
        f"[a][shot]overlay=x={SX}:y='{y}':eval=frame[b];"
        f"[b][4:v]overlay=x={SX - 2}:y='{y}-2':eval=frame[c];"
        f"[c][cap]overlay=x=0:y='{cap_y}':eval=frame,format=yuv420p[out]"
    )
    loop = lambda f: ["-loop", "1", "-t", str(dur), "-i", str(work / f)]
    run([*loop("bg.png"), *source, *loop("mask.png"), *loop("shadow.png"), *loop("edge.png"),
         *loop(f"cap-{name}.png"),
         "-filter_complex", graph, "-map", "[out]", "-t", str(dur), "-r", str(FPS),
         "-c:v", "libx264", "-profile:v", "high", "-preset", "medium", "-crf", "16",
         "-pix_fmt", "yuv420p", str(work / f"{name}.mp4")])


def end_scene(dur=2.5):
    zoom = f"scale=w='iw*(1+0.05*pow(1-min(t/0.6\\,1)\\,3))':h=-2:eval=frame,crop={W}:{H}"
    run(["-loop", "1", "-t", str(dur), "-i", str(work / "end.png"),
         "-vf", f"{zoom},fade=t=in:st=0:d=0.25,format=yuv420p", "-r", str(FPS),
         "-c:v", "libx264", "-profile:v", "high", "-preset", "medium", "-crf", "16",
         str(work / "end.mp4")])


assets()
end_card()
for s in SCENES:
    scene(*s)
    print("scene", s[0])
end_scene()
names = [s[0] for s in SCENES] + ["end"]
(work / "list.txt").write_text("".join(f"file '{n}.mp4'\n" for n in names))
run(["-f", "concat", "-safe", "0", "-i", str(work / "list.txt"), "-c", "copy", str(work / "cut.mp4")])
# Apple asks for stereo AAC at 256 kbps; the video is re-encoded once more at a fixed 30 fps.
run(["-i", str(work / "cut.mp4"), "-i", "music-preview.wav", "-map", "0:v", "-map", "1:a",
     "-c:v", "libx264", "-profile:v", "high", "-preset", "slow", "-crf", "16", "-r", "30",
     "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "256k", "-ar", "44100", "-ac", "2",
     "-shortest", "-movflags", "+faststart", "pesolita-app-preview-886x1920.mp4"])
print("pesolita-app-preview-886x1920.mp4")
