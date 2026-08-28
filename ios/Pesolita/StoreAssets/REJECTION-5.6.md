# Rejection: Guideline 5.6 — Developer Code of Conduct

> "We've identified a pattern of unusual behavior with the app that is commonly associated
> with fraudulent activity. Specifically, the app contains features that appear to have been
> intentionally hidden during the review process."

Apple does not say which feature. I audited the shipping binary rather than guess, and found
one thing that genuinely fits the description, plus one separate risk worth knowing about.

---

## Finding 1 — fixed: an undocumented launch argument that erased all data

`--reset-wallet` sat **outside** the `#if DEBUG` guard in `WalletStore.swift`, so it shipped
in the App Store build. Launching the app with that argument wiped the entire wallet, with no
corresponding control anywhere in the interface.

That is precisely the shape of thing 5.6 describes: an undocumented, destructive entry point,
invisible to a reviewer using the app normally, in a finance app. Whether or not Apple's
scanner caught this specific one, it is indefensible to ship and had to go.

It was invisible to a casual check because `"--reset-wallet"` is 14 characters, and Swift
stores strings of 15 bytes or fewer inline in the instruction stream rather than in the
string table — so `strings` on the binary reports nothing.

**Fixed:** the argument, and the `ProcessInfo.processInfo.arguments` read itself, are now both
inside `#if DEBUG`. Verified on the Release binary:

```
nm -u Pesolita | grep -c processinfo   →   0
```

The shipping build no longer contains any reference to launch-argument reading. Everything
that remains behind that guard exists only to drive the UI tests and the store screenshots.

**Everything else audited clean:** no review-detection by date, region or IP; no remote
config; no downloaded or dynamically executed code; no networking of any kind; and the
`pesolita://` deep-link handler accepts exactly four actions and validates the card id
against cards that already exist.

---

## Finding 2 — fixed: 70 real bank names removed

The app shipped 70 card templates named after real financial institutions — BDO, BPI,
Metrobank, Landbank, Chinabank, EastWest, Maybank, GCash, Maya and more — in a
**Finance-category** app. To a reviewer that reads as claiming an association the app does
not have, which is plausibly what "commonly associated with fraudulent activity" pointed at.
It was also trademark exposure under **Guideline 5.2.1**, independent of this rejection.

All 70 are renamed after the artwork itself, derived from each template's own sampled colour:
"BDO Debit" → **Deep Blue Wave**, "GCash" → **Azure Ripple**, "Metrobank Platinum" →
**Graphite Prism**. The designs are unchanged — only the claim of association is gone. Card
ids and asset filenames were renamed too, so no institution appears anywhere in the bundle.

Also removed:

- The demo wallet's card nicknames and merchants, which put bank names into the App Store
  screenshots. Now "Main Account", "Rewards Card", "Daily Wallet", "Savings".
- `lib/bankPresets.ts`, 23 further bank names in dead code that nothing imported.
- Two visible strings: the search placeholder, and the E-wallet hint that read "GCash, Maya".

**Deliberately kept:** the category-guessing keyword table. Typing "jollibee" in a note still
suggests Food. That is invisible in the interface, it is how the feature works, and naming a
merchant you actually spent at is ordinary nominative use in any expense tracker.

All screenshots were re-captured and re-rendered against the renamed templates.

---

## What to do, in order

1. **Reply to App Review before resubmitting.** They will often name the specific feature when
   asked directly, and guessing wrong costs a full review cycle. Draft below.
2. Upload a new build (**build number must increase — set it to 2**).
3. The bank names are already handled.

### Draft reply to App Review

> Thank you for the review. We take Guideline 5.6 seriously and want to resolve this properly.
>
> We have audited the submitted build and found one issue that matches your description. A
> debug-only launch argument used by our automated UI tests (`--reset-wallet`) was
> unintentionally left outside its `#if DEBUG` compiler guard, so it was compiled into the
> shipped binary. It had no corresponding control in the interface. This was an oversight, not
> an attempt to conceal functionality, and it has been removed — the release build no longer
> reads process launch arguments at all.
>
> For completeness: Pesolita is a fully offline manual budget tracker. It makes no network
> requests, contains no third-party SDKs or analytics, has no account or login, and does not
> download or execute any code. Every figure in the app is typed in by the user and stored
> only on device. There is no server-side component, so there is no mechanism by which app
> behaviour could differ during review.
>
> If your team identified a different feature than the one above, we would be grateful if you
> could tell us which, so we can address it precisely rather than by inference.
>
> A new build with this fix is attached.
