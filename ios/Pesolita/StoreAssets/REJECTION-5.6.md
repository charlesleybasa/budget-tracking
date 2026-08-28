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

## Finding 2 — not fixed, needs your decision: 70 real bank names

The app ships 70 card templates named after real financial institutions — **BDO, BPI,
Metrobank, Landbank, Chinabank, EastWest, Maybank, AUB, DBP, CTBC, GCash, Maya** and more —
with artwork in each institution's brand colours.

This is a **Finance-category app**. From a reviewer's perspective, an app that displays dozens
of real bank cards can read as impersonating those banks or as a phishing surface, which is
plausibly what "commonly associated with fraudulent activity" refers to. It is also a
trademark exposure under **Guideline 5.2.1** independent of this rejection.

Three ways to resolve it:

1. **Rename the templates, keep the artwork.** "BDO Debit" → "Navy Wave", "GCash" → "Blue
   Ripple". The designs are abstract patterns and survive intact; only the claim of
   association goes. Users can still name their own card whatever they like, because it is
   their card. This is the lowest-risk option that keeps the feature.
2. **Ship generative art only** and drop the 70 bundled templates.
3. **Keep them and argue it.** You would be arguing that naming 70 banks in a finance app is
   nominative fair use. Possible, but it is the position most likely to cost you further
   review cycles.

I recommend option 1.

---

## What to do, in order

1. **Reply to App Review before resubmitting.** They will often name the specific feature when
   asked directly, and guessing wrong costs a full review cycle. Draft below.
2. Upload a new build (**build number must increase — set it to 2**).
3. Decide on the bank names.

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
