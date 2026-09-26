# Curiosity ads: Google Vids shots and voiceover (TikTok / Reels / Shorts, 9:16)

Social ads only. **Never upload these as App Store previews:** the people are AI.

`curious_ad.py` makes 9 videos: 3 ideas × 3 opening hooks. Four need no AI and are already
rendered in `curious/`: **A2, B2, B3, C2**. The other five need the people shots below.

| Idea | Hook 1 | Hook 2 | Hook 3 |
|------|--------|--------|--------|
| **A. Sahod, saan napunta?** (payday → where did it go) | A1 AI | A2 ✓ | A3 AI |
| **B. Parang totoong wallet** (the pretty wallet) | B1 AI | B2 ✓ | B3 ✓ |
| **C. Bayaran kita bukas** (the friend who owes you) | C1 AI | C2 ✓ | C3 AI |

## Make the shots in Google Vids (free)

Same as the beach ad: Vids → **Generate video** (the Omni model) → paste a prompt below → save
the 10 s clip → **File → Download → MP4**. Rename each download exactly as listed and put it in
`veo/curious/`. Then run `python3 curious_ad.py` again (or ask Claude to).

- **Portrait if Vids offers it.** If it only makes 16:9, that still works: the edit crops the
  **middle third**, so every prompt keeps one person centred and close.
- **No text or logos** in the shots. Captions go on in the edit, and a generated logo would be a trademark problem.
- **Phone screens face away.** Every real screen in these ads is actual Pesolita footage; AI would invent a fake one.
- The small ✦ mark Google adds to AI video stays. It's the AI-content label.
- The edit uses about 2.5 s from ~1 s into each clip (`in-point` in `curious_ad.py` if a different moment is better).

| File | Used in | Prompt |
|------|---------|--------|
| `a1-payday.mp4` | A1 hook: "Day 15: sahod na! / Day 20: ubos na?!" | *Photoreal, handheld phone-camera feel, vertical framing with the subject centred. A Filipino woman in her twenties in a small condo bedroom in Manila, evening, reads good news on her phone (screen facing away from camera) and does a happy little dance, grinning. Warm lamp light, natural skin tones. No text, no logos.* |
| `a-day20.mp4` | A body: "Hindi ka gastador. Di mo lang alam kung saan napunta." | *Photoreal, vertical framing, subject centred, medium close-up. The same Filipino woman in her twenties sits on the edge of her bed and opens a nearly empty wallet, then looks up at the camera, puzzled and deadpan. Cool evening light. No text, no logos.* |
| `a3-asked.mp4` | A3 hook: "POV: tinanong ka kung magkano pa natira sa sahod mo." | *Photoreal, POV shot, vertical framing, subject centred. A Filipino man in his twenties at a Manila coffee shop is asked a question off-camera, freezes mid-sip, eyes widening, then gives an awkward smile. Natural daylight. No text, no logos.* |
| `b1-wallet.mp4` | B1 hook: "Yung wallet mo / vs. yung wallet ko." | *Photoreal close-up from above, vertical framing, centred. Hands open an overstuffed brown leather wallet crammed with crumpled receipts, old cards and coins; a receipt falls out onto a café table. Warm light. No readable text, no logos, no brand names on the cards.* |
| `c1-promise.mp4` | C1 hook: "Yung friend mong 'bayaran kita bukas'" | *Photoreal, vertical framing, subject centred, medium close-up. A cheerful Filipino man in his twenties at a street-food stall at night grins and puts his hand on his chest as if making a promise, then winks at the camera. String lights behind. No text, no logos.* |
| `c-later.mp4` | C body: "3 weeks later... nasa Boracay na siya." | *Photoreal, vertical framing, subject centred. The same cheerful Filipino man on a white-sand beach at sunset, holding a coconut drink, taking a smiling selfie (phone screen facing away). Turquoise water behind. No text, no logos.* |
| `c3-chat.mp4` | C3 hook: "POV: ikaw lagi yung nag-aabono." | *Photoreal, vertical framing, subject centred, close-up. A Filipina in her twenties on a jeepney reads her phone (screen facing away), sighs and gives the camera a tired, knowing look. Daylight. No text, no logos.* |

If A and C should feature the same people as the beach ad, use the same description of the
friends in each prompt. Vids doesn't keep a character between clips, so describe them the same way.

## Voiceover (optional, one Vids take)

The ads work with the sound off: the captions tell the whole story. A voice usually adds
watch time, though. Make it like the beach ad: Vids → **AI voiceover**, voice **Kaci**, paste
one idea's script with `[long pause]` between lines, then Insert → File → Download → MP4. Save
it as `voiceover/vo-A.wav` (or B, C) with
`ffmpeg -i <download>.mp4 -vn -ac 2 -ar 44100 voiceover/vo-A.wav`, and ask Claude to place the
lines. (The Taglish spelling below reads naturally in the English voice; tweak any word that
comes out wrong.)

**A:** Hook A1: "Kinsenas: sahod na! Katapusan… ubos na?!" · Hook A2: "Saan napunta ang
twenty-five thousand mo this month?" · Hook A3: "Pag tinanong ka kung magkano pa natira sa
sahod mo…" · Body: "Hindi ka gastador. Hindi mo lang alam kung saan napunta. [long pause] May
app pala na magsasabi kung saan. [long pause] Pati kung magkano lang pwede mong gastusin
today. [long pause] Four seconds lang bawat gastos. [long pause] Pesolita. Libre sa App Store."

**B:** Hook B1: "Yung wallet mo… versus yung wallet ko." · Hook B2: "Hindi 'to bank app. Budget
app 'to." · Hook B3: "Ang budget app na gusto mo talagang buksan." · Body: "Lahat ng pera mo,
isang wallet lang. [long pause] Seventy-plus card designs na pang-Pinoy. [long pause] Light o
dark, laging maganda. [long pause] Pesolita. Libre sa App Store."

**C:** Hook C1: "Yung friend mong… 'bayaran kita bukas!'" · Hook C2: "Magkano na utang ng barkada
mo sa'yo? Hindi mo alam, 'no?" · Hook C3: "POV: ikaw lagi yung nag-aabono." · Body: "Three
weeks later… nasa Boracay na siya. [long pause] Alam ng Pesolita kung sino'ng may utang. [long
pause] Magkano, sino, saang lakad. [long pause] Bayad na? Slide mo lang. [long pause] Pesolita.
Libre sa App Store. Tag mo yung may utang sa'yo!"

## Storyboards

Every variant is a 2.5 s hook, then its idea's body, then a 3 s end card (Pesolita · "Bawat
piso, may lugar." · **Libre sa App Store**). Cuts land on the 120 BPM beat of an original
`make_music.py` bed. Captions sit at y 230–470, clear of the TikTok / Reels tabs and buttons.

| Idea | Body after the hook | Length |
|------|---------------------|--------|
| **A** | AI day-20 wallet shot (text card until the clip exists) → Insights "where it went" → Safe to spend today → ₱180 coffee logged, "Logged it." | 18.5 s |
| **B** | Swiping through the cards → template picker flicking through designs → dark to light | 16.5 s |
| **C** | AI Boracay shot (text card until the clip exists) → who still owes you → People with totals → Paid-me slide, "Settled." → end card with "Tag mo yung may utang sa'yo" | 18 s |

Every claim is true in the app: free on the App Store (Pro is optional); "4 seconds" is the
app's own "That took four seconds"; "70+ card designs" is 70 templates plus 13 DIY styles.
Bank-style templates appear only in passing in B's picker, never as the hook or thumbnail.

## Remake

```
./record_curious.sh <Debug Pesolita.app>   # insights, safe, coffee, swipe, detail, templates, theme, people
python3 curious_ad.py                       # every variant whose clips exist → curious/
python3 curious_ad.py A1 C3                 # just these
```

`owed.mov` and `slide.mov` come from `record.sh`. Captions, in-points and lengths are in
`CONCEPTS` in `curious_ad.py`; after changing a body scene, delete `build-curious/` (bodies are
cached there). The new Debug-only hooks are `--demo-swipe`, `--demo-templates` (with
`--route=editor`), `--demo-theme` and `--sheet=coffee`.

## Posting and testing (to find what gets downloads)

1. **Post the three hooks of one idea** on the same account over 2–3 days (same caption,
   different hook). Start with the ready ones: A2, B2/B3, C2.
2. After **~48 h**, compare **2-second / 3-second hold rate** (how many kept watching past the
   hook) and **profile or link taps**. Views alone mislead.
3. **Keep the winner, drop the rest**, and put ad money (Spark Ads / boosted Reel) only behind the winning hook.
4. Reply to comments in the first hour. On C, the "tag mo" comments are the reach.

Upload natively (not links), add the App Store link in bio / first comment, and set the
cover to frame 0 (it's the hook text).

**TikTok / Reels captions (Taglish):**

- **A (sahod):** Sahod day vs. 5 days later 😶💸 Saan ba talaga napupunta? Pesolita shows where every peso went, at kung magkano lang pwede mong gastusin today. Libre sa App Store (iPhone) 📲 #Pesolita #SahodProblems #BudgetTips #IponChallenge #MoneyTok
- **B (wallet):** Hindi 'to bank app, budget app 'to 😳 Lahat ng pera mo sa isang magandang wallet, 70+ card designs. Libre sa App Store (iPhone) 📲 #Pesolita #BudgetApp #AestheticApps #iPhoneApps #MoneyTok
- **C (utang):** Tag mo yung "bayaran kita bukas" 🙃👇 Pesolita tracks kung sino'ng may utang, magkano, at saang lakad. Bayad na? Slide mo lang ✅ Libre sa App Store (iPhone) 📲 #Pesolita #Utang #Barkada #SplitBills #MoneyTok

App Store: https://apps.apple.com/ph/app/pesolita/id6805788143
