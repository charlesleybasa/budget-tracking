# "Petsa de Peligro": the film and the launch plan

A movie-trailer parody about surviving the five days before payday. Mika is the heroine, and
Pesolita saves her. Social platforms only (the people are AI); the App Store preview stays
real footage.

## The files (`final/`)

| File | Use |
|------|-----|
| `pesolita-petsa-hero-h1-9x16.mp4` | Hero, 33 s. Hook: **"25 / 5 DAYS TO SAHOD."** over the storm |
| `pesolita-petsa-hero-h2-9x16.mp4` | Same film. Hook: cold open on the moth, **"POV: 5 DAYS BAGO SAHOD."** |
| `pesolita-petsa-hero-h3-9x16.mp4` | Same film. Hook: **"SAAN NAPUNTA ANG SAHOD MO?"** |
| `pesolita-petsa-cut15-9x16.mp4` | 16 s cut-down for reposts and stories |
| `cover-H1/H2/H3.png` | Cover image for each hook (frame 0) |

All are 1080×1920, 30 fps, H.264 + AAC, at −14 LUFS (TikTok / Reels loudness), with burned-in
subtitles, so they work with the sound off.

## How it was made

- **Flow (Omni Flash, portrait):** 9 shots plus 3 narrator voice takes, with Mika and Paolo set
  up as Flow characters so they stay consistent. Credits: 108 for shots + 21 for narration =
  **129 of 253**; about 124 are left for re-rolls or the next ad.
- **The app:** real recordings with demo data (`../recordings/`), on a 3D phone stage.
- **Remotion (`src/`):** kinetic type (title slams with RGB split and impact shake, ₱ amounts
  punching in, a running GASTOS total, a counting safe-to-spend figure), a film grade, grain,
  vignette, flashes, and the cracked "PETSA DE PELIGRO" title.
- **Sound, all original:** a synthesised trailer score (`audio/make_score.py`), 13 synthesised
  SFX including the **"ka-ching" sonic logo** (`audio/make_sfx.py`), the narrator, and the
  actors' own lines ("Libre ko na!").

Re-render: `npm run render -- Hero-H1 out/raw-Hero-H1.mp4`, then the `loudnorm` pass (see
the commit). Edit timings in `src/timeline.ts`, cuts in `IN`, and lines in `src/vo.ts`. The raw
Flow downloads live in `public/flow/` and `public/vo/raw/` (git-ignored, about 45 MB).

## Launch plan (organic, no ad spend)

**When.** Post in the *petsa de peligro* windows: **Oct 10–14 and Oct 25–29**, then monthly.
The "25" hook is strongest on the 25th itself. On paydays (15th / 30th), repost the cut-down
with "Sahod na? Track it before it disappears."

**Rotation (first two weeks).**
| Day | Post |
|-----|------|
| 1 (the 10th or 25th) | Hero H1 |
| 3 | Hero H2 |
| 5 | Hero H3 |
| 7 (payday) | Cut-down |
| Off days | The curiosity ads (A1–C3) from `../curious/` |

TikTok first; the same file natively to Instagram Reels, Facebook Reels and YouTube Shorts.
Turn on each platform's **AI-generated content** label.

**Captions (Taglish).**
- H1: *25 na. 5 days pa bago sahod. 😶 Saan ba talaga napunta? Pesolita shows you where every peso went, at kung magkano lang ang safe gastusin today. Libre sa App Store (iPhone).* #PetsaDePeligro #Sahod #BudgetTips #MoneyTokPH #Pesolita
- H2: *POV: 5 days bago sahod, and the wallet has a moth. 🦋 Hindi na ulit.* #PetsaDePeligro #RelatableTayo #Pesolita
- H3: *Saan napunta ang sahod mo? Kami alam namin. 👀* #PetsaDePeligro #Gastos #Ipon #Pesolita

**Engagement.** Pin a comment: *"Ano pinakamalaking leak mo this month? 👇 Milk tea? Add to cart? 'Libre ko na'?"*
Reply to the best answers with short video replies, and invite stitches: *"Show your wallet on the 25th."*

**Free reach.** DM 15–20 PH micro-creators (#MoneyTokPH, ipon, student budgeting) with the
app and the stitch idea. Share in PH budgeting and ipon Facebook groups and r/phinvest, within
each group's self-promotion rules.

**Measure what drives downloads.** In App Store Connect, create a **campaign link** per
platform and hook (`apps.apple.com/app/apple-store/id6805788143?pt=<provider>&ct=tt_h1`) and
use it in the bio and pinned comment. Check App Analytics → Sources → Campaigns after about 48 h.
On each platform, compare the 2 s and 6 s hold, completion rate and shares. Keep the hook with
the best hold and downloads per view; use the next Flow credits on a new hook in that style.
