# Higgsfield lifestyle ad — "The bill arrives" (TikTok / Reels, 9:16, ~18 s)

A social ad only — **never upload this as an App Store preview.** Apple's previews must be
real app footage (guideline 2.3.4); that version is `pesolita-app-preview-886x1920.mp4`.

The idea: a relatable moment (the bill lands, everyone freezes), solved by the real app. The
AI shots carry the people and the feeling. Every phone screen is **real Pesolita footage** from
`recordings/`. AI video can't show the app's actual screens and would invent a fake one.

## Storyboard

| # | Time | Shot | Source |
|---|------|------|--------|
| 1 | 0–4 s | Barkada at a beach seafood dinner in Thailand, laughing; the waiter sets down the bill and the table goes quiet. Caption: **"The bill arrives."** | AI (Higgsfield) |
| 2 | 4–6.5 s | Close-up: one friend grins and pulls out their phone (screen facing away). Caption: **"Relax. I got this."** | AI (Higgsfield) |
| 3 | 6.5–10.5 s | ₱3,600 typed and split five ways, ₱720 each. Caption: **"Split in one tap."** | Real (`split.mov`) |
| 4 | 10.5–13 s | Friends laughing, clinking glasses, one showing a thumbs-up. Caption: **"Everyone knows their share."** | AI (Higgsfield) |
| 5 | 13–16 s | Paid-me slide, then "Settled." Caption: **"Paid back? Slide it home."** | Real (`slide.mov`) |
| 6 | 16–18 s | End card: Pesolita · Split bills. Track every peso. · Free on the App Store | `end.png` |

## Prompts (Kling v3.0, 9:16, 5 s, std, sound off)

1. *Vertical 9:16, photoreal, handheld phone-camera feel. Five Filipino friends in their
   twenties laughing around a seafood dinner table at a beach restaurant in Thailand at dusk,
   string lights, grilled prawns and mango shakes. A waiter places a small bill folder in the
   middle of the table; the laughter fades and they glance at each other, amused and awkward.
   Warm golden light, natural skin tones, no text, no logos.*
2. *Vertical 9:16, photoreal close-up at the same beach dinner at dusk. A Filipino woman in her
   twenties smiles confidently and lifts her phone, screen facing away from camera, shallow
   depth of field, string lights bokeh behind her. No readable screen, no text, no logos.*
3. *Vertical 9:16, photoreal. The same five friends at the beach dinner table at night,
   laughing and clinking glasses of mango shake; one gives a thumbs-up to the camera. Warm
   string lights, joyful, natural. No text, no logos.*

**No text or logos in the AI shots:** captions are added in the edit, and a generated "logo"
would be a trademark problem.

## Cost (checked 23 Sep 2026)

| Model | Per 5 s clip | 3 clips |
|-------|--------------|---------|
| Kling v3.0 std, sound off | 7.5 credits | **22.5 credits** |
| Seedance 2.5, 720p | 35 credits | 105 credits |

The balance was 6 credits (free plan), which isn't enough for one clip. Top up at
higgsfield.ai, then ask Claude to "generate the Higgsfield shots". The three clips are then
cut together with the real footage, the captions and `make_music.py`, like
`pesolita-split-ad-9x16.mp4`.
