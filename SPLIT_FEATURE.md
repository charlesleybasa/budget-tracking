# Split & Events — implementation handoff

Working document for the Splitwise-style split/events feature. **If you are a coding agent
picking this up mid-flight, read this file first, then check the progress table at the bottom
for what is actually done.**

Plan artifact (research, UI mockups, rationale):
<https://claude.ai/artifact/3xXK5NpM7iq4x6gA54BGyy>

---

## The one idea

A split is **an annotation on a spend the user already logged**, not a second ledger.
"Part of this ₱1,200 was never mine."

Pesolita is a single-owner, offline wallet. Splitwise is a multi-owner, account-backed shared
ledger. Cloning the latter breaks the former's core promise and its ₱50-lifetime pricing. So:

- **People are local chips**, not accounts. Name + colour + optional GCash handle.
- **Debts run one direction only** — people owe the wallet owner. There is nothing to
  "simplify", so no simplify-debts algorithm (Splitwise's own help page tells users to ignore
  their individual balances after it runs; that confusion is designed out here).
- **Settling up moves real money.** "Migo paid me" creates a top-up transaction on a real card.
  Splitwise structurally cannot do this — there, settling is a journal entry.
- **Sharing is a rendered summary**, handed to the OS share sheet. No invites, no signup.

## The landmine — read this before touching `lib/selectors.ts`

`Transaction.amount` stays the **full** amount. The card really did lose ₱1,200 and the
balance must never lie.

But every analytic must count only the **owner's share**. Without that, Insights claims ₱1,200
of food spending when the user spent ₱400 and lent ₱800, and the safe-to-spend meter throttles
them over money that is coming back.

The helper is `myShare(tx)` in `lib/split.ts` → `tx.split?.mine ?? tx.amount` (sign-preserving).
It must be threaded through:

- `spentOnCard` · `categoryTotals` · `biggestHit` · `cardProgress` · `safeToSpend` (web)
- `WalletMetrics.swift` equivalents (iOS)
- `WidgetSnapshotPublisher.swift` — the widget must agree with the app

Mirror on the way back: a settlement top-up carries `repaysTxId` and is **excluded from income
stats**, because recovered money is not earnings.

## Rounding

₱1,000 across 3 people is ₱333.33 each and a centavo short. **The remainder always goes to the
wallet owner**, and the sheet says so out loud ("you cover the odd centavo"). Splitwise rotates
the remainder; with one ledger owner, giving yourself the rounding is simpler and impossible to
argue with. Implemented once in `splitEvenly()` — never re-derive it at a call site.

## Data model

Additive only. `lib/migrate.ts` keeps repairing rather than trusting, and the
`pesolita.wallet.v2` storage key does **not** need a bump. On iOS the same shapes go into
`WalletSnapshot` (schemaVersion 1 → 2), so Pro users get splits through the existing Supabase
snapshot sync with no backend work.

```ts
Person      { id, name, color, handle?, archived }
EventGroup  { id, name, emoji, startedAt, endedAt: number | null, memberIds[] }
SplitPart   { personId, name /* snapshot */, amount, shares?, settledAt?, settledTxId? }
Split       { mode: "even" | "shares" | "exact", mine, parts[] }

Transaction += { eventId?, split?, repaysTxId? }
```

`SplitPart.name` is a **snapshot**. Deleting a person must never rewrite what a night cost —
this follows the same philosophy as `migrate.ts` repairing rather than trusting.

## Design rules (do not quietly violate these)

| # | Rule |
|---|---|
| R1 | Splitting is one row inside the existing Spend sheet. No new screen for the common case. |
| R2 | The default is the answer: pick people → even → done. Shares/exact hide behind one toggle. |
| R3 | One direction only. Never draw a debt graph. |
| R4 | An event is a filter, not a place. **The nav stays at four destinations.** |
| R5 | Settling moves real money (a top-up on a real card). |
| R6 | Sharing is a picture/text to the OS share sheet. No accounts, no invite links. |

## Deliberately not built

Debt simplification · friend accounts in phases 1–4 · a fifth nav tab · multi-currency ·
"someone else paid for me" (no money left the user's card, so a wallet has nothing to log) ·
a fourth sheet mode (split is a property of a spend, not a kind of transaction).

---

## Verification

```bash
npm run typecheck
npm run build
```

Behaviour that types will not catch, test by hand:

1. Log a ₱1,200 three-way split → card drops by ₱1,200, **Insights reports ₱400**.
2. Settle one person → card rises by ₱400, and the month's **income figure does not**.
3. Delete that person → the event's history still reads correctly (name snapshot).
4. Load a pre-split wallet → every figure unchanged (migration).

iOS: build for the simulator and confirm the widget snapshot matches the app's own spend figure
once shares are in play.

---

## Progress

Update this table as work lands. `—` = not started, `WIP` = in progress, `done` = built and
typechecked.

| Phase | Scope | Status |
|---|---|---|
| 1 | Split a spend + get paid back (web) | **done** — typechecked, built, verified in browser |
| 2 | Events (web) | **done** — event detail, Insights entry, search filter |
| 3 | Share to group chat (web) | **done** — canvas card + share sheet, backup v2, CSV columns |
| 4 | iOS port | **done** — builds clean, verified in the simulator |
| 5 | Live shared events (Supabase) | **dropped** — user confirmed on 2026-09-16 |

### Verified by hand (all passing as of 2026-09-16)

1. ₱1,200 three-way split → card drops ₱1,200, Insights reports ₱400. **Confirmed**: safe-to-spend
   read ₱633 (share-aware) where the full-bill maths would give ₱353; category bars showed
   Bills ₱1,580 not ₱4,740, Food ₱1,085 not ₱2,285.
2. Settle → one settlement top-up covering 3 spends, GCash 8,420 → 10,640, category totals
   unchanged. All three parts share a `settledTxId`, so undo reverses as a unit.
3. Delete a person → `people` empty, split part keeps its `Rain` name snapshot, balance unmoved.
4. Pre-split wallet loads → safe-to-spend ₱635.67, identical to the shipping build's figure.

### iOS verification (2026-09-16, iPhone 17 Pro simulator)

Built clean and driven with seeded data. Owed strip, event detail, People and the split block
inside the spend sheet all render, and the figures match the web exactly (event total ₱6,420,
your share ₱2,220, still out ₱4,200). Settling from the event screen moved the real card
balance. The running event auto-selects itself on the spend sheet and pre-selects its members.

Three layout defects were found by looking at the screenshots and fixed:

1. Header stat figures wrapped mid-number ("₱6,420.0" / "0") — now `lineLimit(1)` +
   `minimumScaleFactor`.
2. The translucent nav bar muddied the dark hero — now `toolbarBackground(Tokens.ink)`.
3. People rows overflowed with amount + "Remind" + "Paid me" — the reminder is now an icon
   button, matching the owed strip.

**Known gap:** `mcp__Claude_Code_iOS_Simulator__control` refuses to attach, reporting Xcode is
not selected even though `xcode-select -p` is correct. Screens were captured with
`xcrun simctl io … screenshot` and navigated via `pesolita://` deep links instead, so no
tap-driven interaction testing was possible on iOS. Re-test taps once that tool works.

### Follow-up round (2026-09-16)

**Slide-to-confirm settling.** `scripts/build-cute-eyes-slider.mjs` and its 4×2 atlas already
existed, built for exactly this ("Map a slider value to `Math.round(value * 7)`"). The 4096px
source was downscaled to `public/settle-slider.png` and
`ios/.../Resources/Sprites/settle-slider.png` (2048×1024, 3 MB → 303 KB). "Paid me" now opens
`SettleSlider` / `SettleSliderView`: the character scrubs frames 0→7 as the thumb travels and a
glow behind it warms up, committing past 90%. A tap is the wrong gesture for money arriving in a
real card. Keyboard, VoiceOver and a plain "Or tap here to confirm" button are all first-class,
not fallbacks.

**Download link in shared summaries.** `APP_STORE_URL` in `lib/constants.ts` and
`EventMetrics.appStoreURL` on iOS. It is in the share text, and on the rendered PNG footer —
the picture travels further than the text does.

**Collapse UX for "Split with".** Three explicit states now: *Just me* → *collapsed summary*
(avatars + "Split 3 ways" + "₱400 yours · ₱800 back") → *expanded*. The header row is the
toggle, with a chevron and the user's share pinned to it. Two defects fixed along the way:

- The `—` under each unselected face was an amount placeholder that read as a tappable control.
  It is blank now, with the slot height reserved so faces do not shift.
- **iOS `clearSplitDraft()` also nil'd `sheetEventID`**, so "Actually, it was just me" silently
  untagged the spend's event. Split into `clearSplitPeople()` (people only) and
  `clearSplitDraft()` (full reset, for opening/finishing a sheet). Web was already correct.

**Also fixed:** the owed strip was only wired into the deck layout on iOS, so anyone using the
wallet-stack layout never saw it.

### Note for whoever adds an income statistic

Neither platform currently shows one, so `incomeOf`/`isRepayment` were removed rather than
shipped as dead code. The data is still there: a settlement top-up carries `repaysTxId`.
**Exclude those rows from any income figure** — recovered money is cash flow, not earnings.

### Phase 1 — files

| File | Change |
|---|---|
| `lib/types.ts` | new types; `Transaction` gains 3 optional fields |
| `lib/split.ts` | **new** — split math, `myShare`, owed selectors |
| `lib/migrate.ts` | `migratePeople`, `migrateEvents`, repair splits |
| `lib/selectors.ts` | thread `myShare` through every spend analytic |
| `lib/store.tsx` | people state, split draft, settle action |
| `components/overlays/SplitBlock.tsx` | **new** — the split row in the sheet |
| `components/overlays/TxSheet.tsx` | mount `SplitBlock` |
| `components/ActivityPanel.tsx` | owed-to-you strip |

### Phase 2 — files

`components/screens/EventDetail.tsx` (new) · `components/screens/EventsScreen.tsx` (new) ·
`Insights.tsx` · `SearchScreen.tsx` · `lib/store.tsx` · `lib/types.ts` (`Screen` union).

### Phase 3 — files

`lib/shareCard.ts` (new) · `lib/backup.ts` · `lib/csv.ts`.

### Phase 4 — files

`Models/WalletModels.swift` · `Models/WalletMetrics.swift` · `Store/WalletStore.swift` ·
`Screens/SpendSheetView.swift` · `Screens/EventDetailView.swift` (new) ·
`Components/SplitBlockView.swift` (new) · `Services/WidgetSnapshotPublisher.swift`.

### Phase 5 — notes

Supabase shared events. The existing `SupabaseManager` stores **one JSON snapshot row per
user** — it is not relational, so shared events need their own tables and RLS. This trades away
the offline promise the store listing is built on; it was scoped as evidence-gated in the plan
and the user asked for it anyway. Keep it behind the existing Pro entitlement and make sure a
non-Pro, offline user loses nothing.

---

## iOS colour roles (light/dark) — use these, not the legacy names

`DesignSystem/Tokens.swift` names colours by **role**. `ThemeContrastTests` holds every pairing to
WCAG in both modes, so a new colour that fails contrast fails the build.

| Role | Use for |
|---|---|
| `bgBase` | the page |
| `fill` / `fillRaised` / `fillStrong` | chips, fields, tiles → selected pills → pressed/disabled, tracks |
| `surfaceOverlay` | anything floating (tab bar, banners) |
| `textPrimary` / `textSecondary` / `textCaption` | copy — all ≥ 4.5:1 on every surface |
| `textTertiary` / `textDisabled` | placeholders, faint icons (≥ 3:1) / unavailable |
| `onAccent` | anything **on** yellow `accent` — always ink |
| `onBrand` | anything **on** blue / green / red fills — always white |
| `link` · `accentText` · `positive` · `negative` · `violetText` | brand colours used as **words** |
| `redTint` · `greenTint` · `blueTint` · `accentTint` · `violetTint` | washes behind icons/rows |
| `hairline` / `hairlineStrong` | separators and strokes |
| `Tokens.on(hex:)` | initials on a person's avatar colour (picked by contrast) |
| `Tokens.glyph(hex:)` | a category colour drawn as an icon on a tint |
| `.pesolitaElevation(_:in:)` | depth: shadow in light, top highlight in dark |

`background`, `text`, `paper`, `dark1…3`, `sand1…4`, `line1…4`, `muted1…5` still compile as
aliases mapped by intent. Never put `textPrimary` on a fixed brand fill — use the on-roles.

## Pesolita Pro backup — how sync decides

`Store/CloudSync.swift` holds the rules as pure functions (tested in `SyncGuardTests`);
`Store/SupabaseManager.swift` (`SyncManager`) does the I/O. **Nothing uploads until this device has
read the cloud and agreed with it.** Uploads only happen in `SyncPhase.live`.

After sign-in, launch or returning to the foreground, `CloudSync.decide` returns:

| This phone | Cloud | Decision |
|---|---|---|
| empty | backup | `restore` → "Found your wallet" |
| has data | backup it never agreed with | `twoWallets` → Combine / Use backup / Keep this iPhone |
| unchanged since last agreement | newer (other device) | `adoptCloud` — taken quietly, toast |
| has data | none | `uploadLocal` (Pro) |
| empty | none | `nothingYet` |
| identical content, or a legacy row (no `savedAt`) fully contained locally | — | `inStep` / `uploadLocal` |

Every upload re-reads the cloud first and is refused if the wallet is empty but the backup isn't,
or if another device wrote since (`cloudMovedOn` → back to a decision). The orphaned-media sweep
is skipped when a push drops more than half the cards or entries. "Start over" signs out before
erasing, so the backup survives. Restoring is free; ongoing backup requires Pro.

`WalletMerge` (tested in `WalletMergeTests`) unions by id, so Combine never doubles an entry;
`MergePreview.sameNamedCards` warns about the same real card typed in twice.
UI: `Screens/RestoreFlowView.swift` (one sheet for every entry point), the Settings status row,
and `BackupAttentionBanner` on Home for decisions found in the background.

## Pesolita 1.7 additions

- **Delete backup & account** (`SyncManager.deleteAccount`, Settings row while signed in): removes
  `media/<USER-ID>/` files via the Storage API, deletes the `snapshots` row, then calls the
  `delete_my_account()` RPC to remove the auth user. Without the RPC installed it returns
  `.dataDeletedAccountRemains`. SQL: `supabase/pesolita_pro_account_and_media.sql`.
- **Photo downloads use the user's sign-in** (`downloadMedia`, `CloudSync.mediaPath(fromLink:)`)
  so the `media` bucket can be made private (SQL PART 2) without breaking 1.7+.
  Media folders are the UPPERCASE uuid; storage policies lowercase them.
- **Restore sheet** sizes to each state and shows a 3-step tracker while waiting; cancelling
  Google's prompt returns to Welcome instead of showing `WebAuthenticationSession error 1`.
- **Out with friends** (`OwedStripView`) is one collapsible row; open state is
  `@AppStorage("home.owedExpanded")`.
- Debug launch args: `--open-pro`, `--open-restore`, `--with-friends` (with `--demo-wallet`).
