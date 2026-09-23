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

---

# App Store preview — `pesolita-app-preview-886x1920.mp4`

886 × 1920, 30 fps, H.264 High, stereo AAC 256 kbps, 26 s. Upload it to the **iPhone 6.9"
Display** preview slot. Apple scales it for smaller displays.

| Time | Caption | Footage |
|------|---------|---------|
| 0–2.5 s | Every peso **gets a home.** | Home |
| 2.5–7 s | Split any bill **in one tap.** | ₱3,600 typed, split five ways |
| 7–10 s | Trips and nights out, **totalled for you.** | Day 1 Thailand |
| 10–13.5 s | Know who **still owes you.** | Out with friends opens |
| 13.5–18 s | Paid back? **Slide it home.** | Paid-me slide → Settled |
| 18–21 s | See where **it all went.** | Insights |
| 21–23.5 s | Light or dark. **Always lovely.** | Home in light mode |
| 23.5–26 s | Pesolita · Split bills. Track every peso. | End card (no price, no call to action) |

**Why it passes review:**
- It uses app footage only, with no people, hands, AI scenes or phone hardware.
- It shows no prices and no "download" wording.
- It is 15–30 s long.

**Poster frame:** in App Store Connect, set it to ~5 s (the split, ₱720 each). That's what
shows before the preview plays.

**Upload:** App Store Connect → the version → App Previews and Screenshots → iPhone 6.9"
Display → drag the .mp4 into the preview spot (first position). Previews are reviewed with the
version, so add it to 1.8 rather than the 1.7 already in review.

```
python3 make_music.py 26 music-preview.wav
python3 compose_preview.py recordings ../raw
```

For the AI lifestyle ad, see `HIGGSFIELD-BRIEF.md`. That one is for social platforms only.
