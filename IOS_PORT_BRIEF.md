# Pesolita — brief for a native iOS (SwiftUI) port

Paste everything below into the iOS agent. It answers all four of its questions and corrects
one wrong assumption in its proposed architecture before that assumption costs you work.

---

## Read this first: there is no backend

Your plan lists "API Calls → URLSession with async/await" and asks what API calls and
third-party services exist. The answer is **none, and that is the entire product**.

Pesolita is a **manual, local-only** budget wallet. It never connects to a bank, has no
server, no auth, no account, no sync, no analytics, and makes **zero network requests at
runtime**. The user types every number in by hand. Its whole selling point is "every number
stays on the device."

So please **delete the networking layer from your plan**. There is nothing to call. Replacing
`localStorage` with `URLSession` would invent a backend the product deliberately does not
have. The persistence port is:

- **Web:** one `localStorage` key, `pesolita.wallet.v2`, holding a single JSON blob.
- **iOS:** the equivalent is a single JSON document written to the app container (or SwiftData
  if you prefer a real store). **Not** Keychain — nothing here is a credential.
  **Not** `UserDefaults` — a wallet with photo attachments is far too big for it (see the
  size warning under *Images*).

Everything else in your plan is sound: SwiftUI views, `@Observable` state, `NavigationStack`,
Swift Concurrency where it genuinely helps (image downscaling, file import/export).

---

## 1. What the app does

You make a **card** for each pocket of your money — a bank account, an e-wallet like GCash or
Maya, the physical cash in your wallet, a savings goal — and you log what goes in and out by
hand. Every card is a piece of generated artwork with its balance printed on it.

It is Philippines-oriented: currency is the peso (₱), and the card design presets are named
after Philippine banks.

Non-goals, stated in the repo and worth preserving: no bank connection, no server, no demo
content on a fresh install (every screen has a real empty state until the user adds data).

---

## 2. Screens

Eight screens plus four overlays.

| Screen | What it is |
|---|---|
| **Onboarding** | 4 steps: intro → name → pick a card kind → name+fund the card. No skip; the wallet is unusable without a first card. A "restore from backup" path exists on step 0 for returning users. |
| **Home** | The wallet. Two user-switchable layouts: a horizontal **deck** (swipeable carousel, one card at a time) or a vertical **stack** (list). Plus a panel with "safe to spend today", notices, and recent activity. |
| **Card detail** | One card's hero art + this-month spend ring + its transaction history grouped by day. The card **flips** to a back face showing receiving details (QR + account number). |
| **Insights** | Spend breakdown by category, with a This week / This month / All time period switch. |
| **Search** | Free-text search over history plus category / money-in / money-out filters. |
| **Card editor** | Design and edit a card: bank preset, art style, palette, texture, chip toggle, receiving details, nickname, balance, monthly limit. Also the delete path. |
| **Transfer** | Move money between two of your own cards. |
| **Settings** | Card limits, low-balance nudge, daily log reminder, hide balances, back up, restore, export CSV, start over. |

Overlays: the **transaction sheet** (spend / top-up / move, with a custom keypad), the
**edit-transaction sheet**, the **success screen**, and a **full-screen QR viewer**.

---

## 3. Data model

Port these types more or less directly. Full source is in `lib/types.ts`.

```ts
Card {
  id: string
  kind: "ATM / Debit" | "Credit card" | "Digital bank" | "Cash on hand" | "E-wallet"
      | "Membership card" | "Prepaid card" | "Savings goal" | "Emergency fund" | "Shared"
  nick: string          // display name
  last4: string
  exp: string
  bal: number           // current balance
  limit: number         // monthly spend ceiling; 0 means no limit
  art: CardArt          // see "card art" below
  frozen: boolean       // frozen cards cannot be spent from
  goal?: number         // savings cards measure progress toward this instead of `limit`
  accountNumber?: string // shown on the card back
  qr?: string           // receiving QR, stored as a data URL
}

Transaction {
  id: string
  cardId: string        // an id, NOT an array index — see "traps" below
  merchant: string
  cat: "Food" | "Transport" | "Bills" | "Groceries" | "Shopping" | "Load" | "Health" | "Fun"
  amount: number        // negative = money out, positive = money in
  at: number            // epoch ms — an instant, NOT a "days ago" offset
  note: string
  receipt?: string      // downscaled photo, data URL
}
```

Persisted blob: `{ cards, tx, dismissedNotices, activeId, userName, privacy, homeLayout,
onboarded, nudgeLowBalance, nudgeDailyLog }`.

---

## 4. Business rules that are easy to get wrong

These are load-bearing. Several were bug fixes; re-deriving them from the UI alone is how a
port silently breaks.

- **"Spent this month" means the current calendar month**, not the card's whole history.
- **A card cannot go negative.** Logging a spend larger than the balance is refused, and so is
  editing an existing transaction upward past it (checked against the *delta*, since the
  original amount is already in the balance). Spending *exactly* the balance is allowed.
- **Frozen cards** refuse spends.
- **Deleting a card deletes its transactions.**
- **Safe to spend today** = remaining ceiling ÷ days left in month, capped by actual balance.
- **Low-balance notices** are derived from live balances (threshold ₱1,500), never stored.
  Dismissals are remembered by id, and a dismissal expires once the card climbs back above the
  threshold, so the nudge can fire again later.
- **Category guessing:** typing a note like "jollibee" or "grab" suggests a category from a
  keyword table.
- **Balances carry their sign.** Amounts format absolute and the label owns the sign, so an
  overdrawn card must render `−₱499.25`, not `₱499.25`.

All of this lives in `lib/selectors.ts` and the reducer in `lib/store.tsx` — read those two
files before writing the Swift model layer; they are the actual spec.

---

## 5. Card art — the biggest port decision

Each card paints its own background from one of **14 generative styles** (blob, wave, arc,
mesh, grid, confetti, planes, orbit, iridescent, foil, crest, metal, initial, or the user's
own photo), driven by two colours, a texture, and a chip toggle. On the web these are drawn
with CSS gradients and inline SVG — **no image assets**. `components/CardArt.tsx`.

For SwiftUI this is a real fork in the road, and it is worth deciding deliberately:

- Most of the styles map well onto SwiftUI `Canvas`, `Shape`, and gradient fills.
- The `photo` style needs cropping, zoom/pan reframing, and a scrim.

There is also a **WCAG AA contrast tuner** (`lib/legibility.ts`) that runs before every card
renders, because the balance is printed directly onto the artwork. It measures patterns at
their luminance *extremes* rather than their average, damps pattern amplitude first, and only
adds a scrim when damping alone cannot reach 4.5:1. Photos are sampled specifically in the
bottom-left region where the balance sits. **Port this logic rather than eyeballing it** —
without it, generated art will regularly render unreadable balances.

**Bank presets** (`lib/bankPresets.ts`) are colour-and-pattern starting points named after
Philippine banks. Important legal note carried in the source: these are **palettes and
abstract patterns only — no issuer logo, wordmark, or payment-network mark is reproduced**,
because those are trademarks. Keep that constraint in the iOS port.

---

## 6. Mascot animations

The app has a mascot ("Kuya Ipis") used in onboarding, success, empty, and error states. It
ships as **PNG sprite sheets** played frame-by-frame — grid atlases in `public/`, with the
grid geometry declared in `lib/sprites.ts`:

| Sheet | Grid | Frames | fps | Used for |
|---|---|---|---|---|
| `celebrate` | 8×4 | 32 | 24 | log-spend success |
| `peekaboo` | 9×6 | 54 | 24 | onboarding |
| `sad` | 10×6 | 60 | 24 | empty card |
| `flying-idle` | 10×6 | 60 | 24 | no recent activity |
| `nonono` | 10×6 | 60 | 24 | amount over balance |
| `bee-idle-steady` | 10×3 | 30 | 30 | empty Insights / Search |

These port cleanly to iOS — reuse the same PNGs and step through frames with
`TimelineView`/`Canvas` or a frame-indexed `Image`. There is also a hand-drawn SVG mascot
(`components/Mascot.tsx`) used as an instant fallback while a sheet decodes; on iOS, with the
assets bundled locally, you probably do not need the fallback at all.

Every animation has a designated **still frame** for `prefers-reduced-motion` — honour
`accessibilityReduceMotion` the same way.

---

## 7. Images: the constraint that will bite you

Card photos, receipt photos, and receiving QRs are stored **inline as data URLs inside the
same JSON blob as the wallet**. On the web this is a real pressure point — the app downscales
every image on import (`lib/image.ts`: receipts to 1400px/q0.72, QRs to 900px/q0.88, card
photos to 1200px/q0.8) and surfaces a toast when a write fails because storage filled up.

On iOS you have far more room, and **the better design is to write images as separate files in
the app container and store only their filenames in the model.** If you do that, say so
explicitly, because it changes the backup format (see below).

---

## 8. Backup / restore / export

- **Back up wallet** → one JSON file: `{ format: "pesolita.backup", version: 1, exportedAt,
  cards, tx, dismissedNotices, userName, privacy, homeLayout, nudgeLowBalance, nudgeDailyLog }`.
- **Restore** → *replaces* the wallet, never merges (merging two histories would silently
  double entries). Validated and run through the same migration path as stored data.
- **Export CSV** → transactions only, one-way.

**If you want the iOS app to interoperate with the web app's backups, keep this format
byte-compatible** — including images as inline data URLs, which conflicts with the file-based
image storage suggested above. Decide which matters more and state the choice; do not leave it
implicit.

There is also a **migration layer** (`lib/migrate.ts`) that repairs anything loaded from disk
rather than trusting it: it derives missing timestamps, remaps retired art styles, and drops
transactions pointing at a deleted card. Persisted data outlives the code that wrote it, so
port this idea even if the specific repairs differ.

---

## 9. Platform behaviour worth carrying over

- **Currency:** peso, `en-PH` formatting, thousands separators, 2dp.
- **Custom keypad**, not the system keyboard, for amount entry in the transaction sheet.
- **Navigation:** Android hardware back and browser back walk back through the app, closing
  the topmost layer first (success → sheet → screen). The iOS equivalent is correct
  `NavigationStack` paths plus interactive-dismiss on sheets, with the same layer ordering.
- **Reduced motion** is honoured throughout: entrances become fades, ambient loops stop, but
  colour/opacity feedback that *confirms an action* keeps running.
- **Hit targets:** everything clears 44pt (already the iOS standard).
- **Privacy mode** ("hide balances") masks every balance as `•••••`.
- The web app is heavily responsive (phone → tablet → desktop → foldables). For iOS this
  mostly collapses to iPhone + iPad, but the two-pane idea maps well to iPad split view.

---

## 10. Traps, from the web implementation's own notes

Two are in the source as explicit warnings and cost real debugging time:

1. **Transactions reference cards by id, not array index.** The original design comp keyed
   history by position, which silently reassigns a card's history to its neighbour the moment
   one is deleted.
2. **Transactions store an instant, not "days ago".** The comp stored an offset fixed at
   creation, so every entry would still claim to be from "Today" a week later.

(Two others — an invalid CSS `font` shorthand and CSS-Modules keyframe scoping — are web-only
and do not apply to SwiftUI.)

---

## 11. Where the code is

Repo root: **`/Users/rli/Documents/Claude/budget-tracker`** — the whole thing is the app;
there is no sub-directory to hunt for. GitHub: `charlesleybasa/budget-tracking`.

```
app/                     route shell, design tokens, keyframes
components/
  AppShell.tsx           rail + content pane grid
  Nav.tsx                one nav that is a bottom bar or a side rail
  ActivityPanel.tsx      pacing, notices, recent activity
  CardArt.tsx            the generative art engine   ← biggest port
  Mascot.tsx             hand-drawn SVG mascot (fallback)
  SpriteAnimation.tsx    sprite-sheet player
  screens/               one module per screen
  overlays/              transaction sheet, success, QR viewer
lib/
  types.ts               the data model              ← start here
  store.tsx              state, actions, persistence ← then here
  selectors.ts           all derived business logic  ← then here
  legibility.ts          WCAG contrast tuner
  bankPresets.ts         Philippine bank palettes
  migrate.ts             repairs data loaded from disk
  backup.ts / csv.ts     backup + export formats
  sprites.ts             sprite-sheet geometry
public/                  sprite sheets, brand mark, card templates
README.md                architecture, rationale, known gaps
```

**Suggested reading order:** `README.md` → `lib/types.ts` → `lib/store.tsx` →
`lib/selectors.ts` → `components/CardArt.tsx`.

---

## 12. Known gaps in the web app

Do not port these as if they work:

- The **daily log reminder** is only a stored preference — nothing schedules it. On iOS this is
  actually easy to finish properly with `UNUserNotificationCenter`, and would be a genuine
  improvement over the web version.
- There is **no recurring-bill model**, so no upcoming-bills view.

(The README's "Not built" section also lists receipt capture as unimplemented — that is
**stale**. Receipt capture works, via a file input with `capture="environment"`.)

---

## What I would like back

1. A proposed SwiftUI architecture with **no networking layer**, and an explicit decision on
   local persistence (single JSON document vs SwiftData) with the reasoning.
2. Your plan for the **card art engine** specifically — it is the highest-risk piece.
3. Whether you intend to keep **backup-file compatibility** with the web app, and what that
   forces about image storage.
4. A screen-by-screen mapping from the list in section 2 to SwiftUI views and navigation.
