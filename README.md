# Pesolita

A manual budget wallet. You make a card for each pocket of your money — bank, e-wallet, the
cash in your actual wallet — and type what goes in and out. Nothing connects to a bank, and
every number stays in the browser it was typed into.

This is the implementation of the `Budget Wallet.dc.html` design comp from the
[Budget Tracking App Design](https://claude.ai/design/p/27d31bd2-066b-48aa-916d-949e32ec4100)
project.

## Running it

```bash
npm install
```

```bash
npm run dev
```

Then open http://localhost:3000. Other scripts: `npm run typecheck`, `npm run lint`,
`npm run build`.

## Stack

TypeScript, Next.js 15 (App Router), React 19, CSS Modules. No state library, no UI kit, no
runtime dependencies beyond React and Next — the card artwork is generated from CSS gradients
and inline SVG rather than image assets.

## Layout

```
app/                     route shell, design tokens, keyframes
components/
  AppShell.tsx           rail + content pane grid
  Nav.tsx                one nav that is a bottom bar or a side rail
  ActivityPanel.tsx      pacing, notices and recent activity
  CardArt.tsx            the generative art engine (21 styles)
  screens/               one folder-level module per screen
  overlays/              transaction sheet and success screen
lib/
  legibility.ts          contrast tuner for photo and pattern card art
  selectors.ts           derived values (spend, pacing, grouping, insights)
  store.tsx              wallet state, actions, persistence
```

## Responsive behaviour

The app is the page — there is no device frame. It adapts by composition, not by scaling:

| Context | Layout |
|---|---|
| Phone (< 600px) | Single column, bottom tab bar |
| Large phone / small tablet (600–759px) | Wider single column |
| Tablet, unfolded foldable, laptop, desktop (≥ 760px) | Persistent left rail beside a two-pane content area |
| Desktop (≥ 1280px) | Rail gains labels; Insights and Settings split into two columns |
| Landscape / flip half-open (height ≤ 560px) | Rail instead of a bottom bar, compressed vertical rhythm |
| Book-posture foldable | Panes align to the viewport segments so nothing sits under the hinge |

Two-pane means Home shows the wallet and its activity at once; Card detail shows the card
beside its history; the Card editor pins the preview while the controls scroll.

Sizing follows the pointer rather than the screen: hover effects are gated behind
`(hover: hover) and (pointer: fine)`, and controls grow to the 44px target floor under
`(pointer: coarse)`. Card geometry is measured with a `ResizeObserver` rather than assumed,
because the artwork scales every dimension off its rendered width.

## Motion

> **Keyframes live beside their user, not in `globals.css`.** CSS Modules scopes animation
> names, so `animation: bwFan …` inside a module is rewritten to a hashed name that no global
> keyframe answers to — the animation is dropped silently, with no error. Every module that
> animates therefore declares its own `@keyframes`. Only styles set inline from JS may
> reference the global ones.


Motion is for feedback, state and continuity — this is a tool, not a showreel.

The one authored moment is opening a card: the card morphs into the detail hero through the
View Transitions API, so the same object stays the same object across the navigation. Where
the API is missing, or the user prefers reduced motion, it is a plain screen swap.

Everything else is quiet: a sliding indicator under the active destination, balances that
ease to their new figure instead of cutting, entrances that ride on mount rather than on a
flag in global state, and press feedback on every control.

Reduced motion removes movement, not meaning — spatial entrances become a fade and ambient
loops stop, while the colour and opacity changes that confirm an action keep running.

## The screens

Onboarding, Home (a horizontal card deck or a vertical wallet stack), Card detail with
history, Insights, Search, the Card editor, Transfer, Settings, plus the spend/top-up/move
sheet and the success screen.

## Card art

Each card paints its own background from one of 14 generative styles — blob, wave, arc, mesh,
grid, confetti, planes, orbit, iridescent, foil, crest, metal, initial, or your own photo.

Customisation is deliberately shallow: **Start from** seeds a bank's colours, **Style** picks
the pattern, **Colour** picks the palette, **Finish** adds texture, **Details** toggles the
chip. Style and colour are independent, so choosing a look never silently changes your colours.

### Bank presets

`lib/bankPresets.ts` holds colour-and-pattern starting points named after the banks people
actually carry, so a card is recognisable at a glance in the deck.

These are **palettes and abstract patterns only**. No issuer logo, wordmark or payment-network
mark is reproduced — those are trademarks, and cloning them would make the app undistributable.
The bank name labels the palette; everything drawn on the card comes from this project's own
art engine, and every value stays editable afterwards.

## Migrations

Persisted data outlives the code that wrote it, so anything loaded from the device is repaired
in `lib/migrate.ts` rather than trusted: missing timestamps are derived, retired art styles
are remapped to a survivor, and transactions pointing at a deleted card are dropped. A single
missing field used to surface as "Invalid Date" in the history.

Because the balance is printed straight onto that artwork, `lib/legibility.ts` tunes every
card against WCAG AA before it renders:

- **Patterns** are measured at their luminance *extremes*, not their average — a glyph crosses
  the whole amplitude, so both the darkest and brightest bands have to clear 4.5:1. The tuner
  searches amplitude first and only reaches for a scrim when damping alone cannot get there,
  so the weave survives across the whole card instead of being washed out.
- **Photos** are sampled in the bottom-left region where the balance actually sits, then given
  the lightest scrim that still passes. The editor shows the live contrast ratio and an
  auto-fix.

## Backup, restore and export

- **Back up wallet** writes one JSON file with cards, history and settings.
- **Restore from backup** replaces the wallet from that file. It is offered in Settings and
  on the first onboarding screen, because a returning user on a wiped device has no Settings
  to reach for. Restore replaces rather than merges — merging two histories would silently
  double entries the user already has.
- **Export CSV** is the spreadsheet path: transactions only, one-way.

Backups are validated and run through the same migration as stored data, so a file written by
an older build still restores cleanly.

## Data

Everything is persisted to `localStorage` under `pesolita.wallet.v2`; a failed write (private
mode, or a card photo too large to store) surfaces as a toast rather than failing silently.
There is no server and no network call anywhere in the app.

**A new install is genuinely empty.** There is no demo content: onboarding creates your first
card, and every screen has a real empty state until you put something in it. Settings has a
two-tap "Start over" that erases the wallet from the device.

## Notes on the implementation

Deliberate departures from the comp, all correctness fixes:

- **Transactions reference cards by id, not array index.** The comp keyed history by position,
  which silently reassigns a card's history to its neighbour the moment one is deleted.
  Deleting a card now takes its transactions with it.
- **Transactions store an instant, not "days ago".** The comp stored a `dayOffset` fixed at
  creation, so every entry would still claim to be from "Today" a week later. Entries carry a
  timestamp and the offset is derived.
- **"Spent this month" means this month.** The comp summed a card's whole history against a
  monthly limit. Spend is now filtered to the current calendar month, so the number agrees
  with the label and with the ring beside it.
- **Negative balances read as negative.** Amounts are formatted absolute (the sign belongs to
  the label on a transaction row), so an overdrawn card would have shown as positive. Balances
  now carry their sign: −₱499.25.

## Navigation

Hardware back on Android and the browser's back button walk back through the app rather than
leaving it: each screen away from home pushes a history entry, and popping one closes the
topmost layer. Escape does the same on a keyboard — closing the success screen, then the
sheet, then backing out of a task screen.

Entrances are CSS animations that replay when a screen mounts, rather than a motion flag in
global state. Transform-only, so a frozen animation clock (a backgrounded tab, a raster
capture) can never leave content stuck invisible.

The insight headline, the "biggest single hit" stat and the pacing copy are derived from the
actual transactions rather than hardcoded.

## Notices

The "Worth knowing" cards are derived from the wallet rather than seeded, so what you see is
always true of your actual money: a card under ₱1,500 raises a low-balance notice, dismissals
are remembered by id, and turning the nudge off in Settings silences it.

## Not built

- The daily log reminder is a stored preference; scheduling it needs notification permission
  and a service worker, neither of which is wired up.
- "Attach receipt" toasts instead of opening a camera.
- There is no recurring-bill model, so there is no upcoming-bills view.
# budget-tracking
