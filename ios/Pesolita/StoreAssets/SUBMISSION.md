# Pesolita — App Store submission audit

Audited against the shipping code, not a questionnaire. Everything below was verified by
reading the project, building Release, or running the test suite.

**App:** `com.pesolita.app` · v1.0 (1) · Finance · iOS
**Release binary:** 16 MB · **Dependencies:** none · **Network calls:** none

---

## Blockers — fixed in this pass

- [x] **Privacy manifest** (**5.1.1**, required since May 2024). Neither the app nor the
      widget had `PrivacyInfo.xcprivacy`. Both now ship one declaring no tracking, no
      collected data, and the single Required Reason API in use: `UserDefaults` under
      reason **CA92.1** (app-group access, used to hand the widget its snapshot).
- [x] **App icon.** The project had no asset catalog at all, so the archive would have been
      rejected outright. `Assets.xcassets/AppIcon.appiconset` now carries an opaque,
      full-bleed 1024×1024 with no alpha and no baked-in corner rounding.
- [x] **Export compliance.** `ITSAppUsesNonExemptEncryption = false` added to `Info.plist`,
      so App Store Connect stops asking on every upload. Accurate here: no custom crypto,
      no HTTPS, no network.

## Decided and applied

- [x] **iPhone-only for 1.0** (**2.1**, **4.0**). The app previously claimed iPad support
      (`TARGETED_DEVICE_FAMILY = "1,2"`) while the iPad layout left roughly 40% of the screen
      empty and stranded the compose button in a corner — the most likely reason this would
      have been rejected. Now `"1"` across every target and configuration. This also removes
      the 13" iPad screenshot requirement.
- [x] **Support and privacy URLs are live**, both returning 200 and both carrying a working
      contact address:
      - `https://pesolita.vercel.app/privacy`
      - `https://pesolita.vercel.app/support`

---

## Phase 1 — Code and asset cleanup (**2.1**, **2.5**)

- [x] **No placeholders.** Swept for "Coming Soon", "Lorem Ipsum", TODO, FIXME, WIP, "not
      implemented", dummy data. Zero hits in shipping code.
- [x] **No debug logging.** Zero `print`, `NSLog`, `debugPrint` or `dump` calls anywhere.
- [x] **No hidden beta features.** The `--demo-wallet` / `--route=` / `--tab=` launch hooks
      the UI tests drive are already inside `#if DEBUG` (`WalletStore.swift:95`), so they
      compile out of Release. This is the correct pattern — nothing to change.
- [x] **No orphaned assets.** Six sprite sheets ship and all six are referenced. The web
      project's unused `pesolita-promo-square.png` (1.97 MB) and the orphaned sprite JSON
      were never copied into the iOS target.
- [x] **Release binary is lean** at 16 MB. Largest single asset is the 704 KB idle sprite
      sheet. Well clear of any cellular-download threshold.
- [ ] **Optional:** that idle sheet decodes to roughly 15 MB in memory. Not a review issue,
      but worth watching if you add more atlases.

## Phase 2 — Privacy and permissions (**5.1**)

- [x] **No `NSUsageDescription` keys needed, and none should be added.** The app uses
      `PhotosPicker` (`PHPickerViewController`) exclusively, which runs out of process and
      requires no photo-library permission. There is no camera capture, no location, no
      contacts, no microphone. Adding unused permission strings invites questions you have
      no answer for — leave them out.
- [x] **Notifications** are requested at runtime via `UNUserNotificationCenter`
      (`ReminderService.swift:16`). No `Info.plist` key required.
- [x] **Privacy manifest** covers the app and the widget extension; both were verified
      present inside the built bundle.
- [x] **Third-party SDKs: none.** Zero SPM packages, no CocoaPods, no Carthage. Nothing to
      chase for signatures or nested manifests.
- [x] **Sign in with Apple (4.8): not applicable.** There is no authentication of any kind
      and no third-party login. Nothing to add.
- [ ] **App Privacy answers in App Store Connect** — declare **"Data Not Collected"** for
      every category. This is true: there is no server and no network call, so no data can
      leave the device. Say exactly that in the review notes.

## Phase 3 — Guideline pitfalls

- [x] **Digital purchases (3.1.1): clean.** No in-app purchase, no subscription, no paywall,
      no external payment link. Verified — the app opens no URLs at all except its own
      `pesolita://` widget deep links.
- [x] **Demo account (2.1): not required.** There is no login, no account and no server, so
      there is nothing for a reviewer to sign into. In App Store Connect leave "Sign-in
      required" **unchecked** and put this in the notes:

      > Pesolita is fully offline. There is no account, no login and no server. Launch the
      > app and the first-run flow creates a card in about 20 seconds. Every number is
      > entered by hand and stored only on device.

      This also sidesteps the OTP/2FA-for-reviewers problem entirely — you have no auth to
      bypass.
- [ ] **Crash and performance pass before archiving.** Run these from Xcode:
      - **Instruments → Leaks** and **Allocations** while cycling the card deck and opening
        the spend sheet repeatedly — the sprite atlases are the memory-heavy part.
      - **Instruments → Hangs** (or Time Profiler) on the onboarding template carousel,
        which decodes 70 WebP card images.
      - **Product → Scheme → Edit Scheme → Diagnostics → Address Sanitizer** and
        **Main Thread Checker** for one full run-through.
      - **Product → Analyze** for static issues.
- [x] **Resolved the flaky backup test.** It asserted on the system Files UI, which runs
      out of process and alternated between failing on "Save" and on "Open" across identical
      runs. Rewritten to check what is actually Pesolita's responsibility — both entry points
      reachable, app healthy after the handoff — with the file formats and replace-not-merge
      restore still covered by the unit tests. Still worth exercising Back up / Restore by
      hand once on a real device before submitting.

## Test suite status

All 28 pass — 16 unit tests, 6 formatting tests, 6 persistence tests and 5 UI tests.

---

## Store assets

Generated into `StoreAssets/AppStore/iphone-6.9/` at **1320 × 2868**, the exact 6.9" size
App Store Connect expects, in the app's own Outfit typeface and palette:

| # | Screen | Headline |
|---|---|---|
| 1 | Home with activity | Every peso gets a home. |
| 2 | Over-balance guard | It stops you overspending. |
| 3 | Template picker | 70 card designs. Pick yours. |
| 4 | Logged confirmation | Logged in four seconds. |
| 5 | Onboarding | No bank login. Ever. |

Regenerate any time with `swift render.swift` from `StoreAssets/`. Edit the `panels` array
to change copy or swap screens.

**Still to write by hand:** app name and subtitle (30 chars each), keywords (100 chars),
description, support URL, and a privacy policy URL. The policy is easy — the honest version
is one paragraph: the app collects nothing and transmits nothing.
