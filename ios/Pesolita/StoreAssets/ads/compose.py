"""Assembles the 9:16 Pesolita split-bills ad from the simulator recordings.

  python3 make_assets.py && python3 make_music.py && python3 compose.py <recordings dir>

Each scene: background → soft shadow → bezel → the real app recording (rounded) → caption that
rises in. Cuts land on the beat of music.wav (120 BPM). Output: pesolita-split-ad-9x16.mp4.
"""
import subprocess
import sys
from pathlib import Path

REC = Path(sys.argv[1] if len(sys.argv) > 1 else "recordings")
W, H, FPS = 1080, 1920, 30
PHONE_W, PHONE_H, BEZEL = 800, 1738, 22
PX = (W - PHONE_W) // 2
work = Path("build")
work.mkdir(exist_ok=True)

# name, clip, in-point (s), length (s), caption, phone top, motion
SCENES = [
    ("hook",  "home.mov",  4.20, 2.5, "cap-hook.png",  640, "slide-in"),
    ("split", "split.mov", 3.60, 4.0, "cap-split.png", 600, "still"),
    ("event", "event.mov", 3.05, 2.5, "cap-event.png", 640, "drift"),
    ("owed",  "owed.mov",  2.90, 3.0, "cap-owed.png",  640, "still"),
    ("slide", "slide.mov", 3.00, 4.0, "cap-slide.png", 560, "still"),
]


def run(args):
    subprocess.run(["ffmpeg", "-v", "error", "-y", *args], check=True)


def scene(name, clip, start, dur, cap, top, motion):
    # Phone top as a function of time: rises in on the hook, drifts up on the event screen.
    if motion == "slide-in":
        y = f"{top}+620*pow(1-min(t/0.6\\,1)\\,3)"
    elif motion == "drift":
        y = f"{top}-140*t/{dur}"
    else:
        y = f"{top}"
    # Below TikTok / Reels top tabs (~200 px). The hook's caption is there from frame one:
    # the first frame is the thumbnail and the scroll-stopper.
    cap_y = "230" if motion == "slide-in" else "230+50*pow(1-min(t/0.4\\,1)\\,3)"
    cap_fade = "" if motion == "slide-in" else ",fade=t=in:st=0:d=0.35:alpha=1"
    graph = (
        f"[1:v]setpts=PTS-STARTPTS,fps={FPS},tpad=stop_mode=clone:stop_duration=8,"
        f"trim=duration={dur},scale={PHONE_W}:{PHONE_H},format=rgba[v];"
        f"[2:v]format=gray,scale={PHONE_W}:{PHONE_H}[m];"
        f"[v][m]alphamerge[phone];"
        f"[5:v]format=rgba{cap_fade}[cap];"
        f"[0:v][4:v]overlay=x={PX - BEZEL - 100}:y='{y}-{BEZEL}-100':eval=frame[a];"
        f"[a][3:v]overlay=x={PX - BEZEL}:y='{y}-{BEZEL}':eval=frame[b];"
        f"[b][phone]overlay=x={PX}:y='{y}':eval=frame[c];"
        f"[c][cap]overlay=x=0:y='{cap_y}':eval=frame,format=yuv420p[out]"
    )
    run([
        "-loop", "1", "-t", str(dur), "-i", "bg.png",
        "-ss", str(start), "-i", str(REC / clip),
        "-loop", "1", "-t", str(dur), "-i", "mask.png",
        "-loop", "1", "-t", str(dur), "-i", "bezel.png",
        "-loop", "1", "-t", str(dur), "-i", "shadow.png",
        "-loop", "1", "-t", str(dur), "-i", cap,
        "-filter_complex", graph, "-map", "[out]",
        "-t", str(dur), "-r", str(FPS), "-c:v", "libx264", "-preset", "medium", "-crf", "18",
        "-pix_fmt", "yuv420p", str(work / f"{name}.mp4"),
    ])


def end_card(dur=3.0):
    # A gentle settle-in: starts 6% larger and eases to rest.
    zoom = f"scale=w='iw*(1+0.06*pow(1-min(t/0.6\\,1)\\,3))':h=-2:eval=frame,crop={W}:{H}"
    run([
        "-loop", "1", "-t", str(dur), "-i", "end.png",
        "-vf", f"{zoom},fade=t=in:st=0:d=0.25,format=yuv420p",
        "-r", str(FPS), "-c:v", "libx264", "-preset", "medium", "-crf", "18",
        str(work / "end.mp4"),
    ])


for s in SCENES:
    scene(*s)
    print("scene", s[0])
end_card()
print("scene end")

names = [s[0] for s in SCENES] + ["end"]
(work / "list.txt").write_text("".join(f"file '{n}.mp4'\n" for n in names))
run(["-f", "concat", "-safe", "0", "-i", str(work / "list.txt"), "-c", "copy", str(work / "cut.mp4")])
run([
    "-i", str(work / "cut.mp4"), "-i", "music.wav",
    "-map", "0:v", "-map", "1:a", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
    "-shortest", "-movflags", "+faststart", "pesolita-split-ad-9x16.mp4",
])
print("pesolita-split-ad-9x16.mp4")
