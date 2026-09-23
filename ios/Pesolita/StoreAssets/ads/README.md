# Pesolita video ad — "Split bills" (TikTok / Reels / Shorts)

**Output:** `pesolita-split-ad-9x16.mp4`, 1080 × 1920, 30 fps, 19 s, H.264 + AAC.

| Time | Caption | Real app footage |
|------|---------|------------------|
| 0–2.5 s | Dinner was ₱3,600. **Who owes what?** | Home, phone rises in |
| 2.5–6.5 s | Split it in one tap. **₱720 each. Done.** | ₱3,600 typed, Split with opens |
| 6.5–9 s | Every trip, **totalled for you.** | Day 1 Thailand event |
| 9–12 s | Know who **still owes you.** | Out with friends opens |
| 12–16 s | Paid back? **Slide it home.** | Paid-me slider → "Settled." |
| 16–19 s | Pesolita · Split bills. Track every peso. · **Free on the App Store** | End card |

Cuts land on the beat of the music (120 BPM).

## Ad rules this cut follows

- **Captions sit clear of platform UI.** TikTok and Reels cover the top ~200 px with tabs, the
  right edge with buttons, and the bottom ~20% with the caption. The text sits between 230 and
  470 px, and the end card's call to action at 1260–1392 px.
- **The first frame works as a thumbnail.** The hook and the phone are visible at 0 s.
- **It works with the sound off.** The whole story is in the captions.
- **The footage is honest.** Every screen is the real app with sample data, and "Free on the
  App Store" is true: the app is free, and Pro is optional.
- **No Apple badge artwork.** The call to action is a plain pill. Apple's "Download on the
  App Store" badge has its own usage rules; get it from Apple's marketing site if you want it.
- **The music is original,** synthesised by `make_music.py`, so there is nothing to license.
  Platforms may still suggest trending sounds; this track is safe to keep.

## Remake it

```
./record.sh <Debug Pesolita.app>        # raw clips → recordings/  (Debug-only demo hooks)
python3 make_assets.py                   # background, bezel, captions, end card
python3 make_music.py                    # music.wav
python3 compose.py recordings            # → pesolita-split-ad-9x16.mp4
```

Edit the captions in `make_assets.py`, and scene timing and in-points in `compose.py`
(`SCENES`). The demo hooks (`--demo-type`, `--demo-expand`, `--demo-slide`) exist only in
Debug builds.
