# Pesolita iOS — App Store compliance audit

**Audit date:** 1 September 2026  
**Guidelines checked:** Apple App Review Guidelines, updated 8 June 2026  
**Scope:** app target, WidgetKit extension, tests, build settings, entitlements, URL scheme,
privacy manifests, bundled assets, persistence, imports/exports, local notifications and the
previously archived Release product.

This is the pre-change record required by the remediation brief. It records the state found at
the start of this audit. Two high-risk items had already been corrected on the current branch;
they remain here because they are the strongest explanation for the rejection.

## Executive finding

The repository contains no reviewer detection, App Store/TestFlight detection, receipt or IP
inspection, account roles, remote configuration, WebView, JavaScript bridge, server-driven UI,
downloaded code, analytics, advertising, authentication, StoreKit, payment processing or network
client. The app cannot change its capabilities after review through a backend because it has no
backend or networking layer.

The most likely rejection trigger was the combination of:

1. an undocumented `--reset-wallet` launch argument compiled into the earlier Release build,
   which erased all local wallet data without a visible in-app control; and
2. 70 templates named after real financial institutions in a Finance-category app, creating the
   appearance of unlicensed affiliation and potentially fraudulent financial functionality.

Both were corrected before this audit began, but the current branch still had several material
privacy, completeness and dormant-code issues that should be fixed before resubmission.

## Findings

### A-01 — CRITICAL — undocumented destructive Release launch hook (already remediated)

- **Potential guidelines:** 2.3.1(a), 5.6, 5.6.4
- **File / area:** `Pesolita/Store/WalletStore.swift`, `load()`; historical code immediately
  following the Debug-only demo launch handling
- **Behavior found in the rejected lineage:** `--reset-wallet` was checked outside `#if DEBUG`
  and caused `WalletRepository.erase()` during launch.
- **Why Apple can interpret it as hidden:** it was an undocumented production entry point with
  destructive financial-data behavior and no corresponding visible control. Normal users and
  reviewers could not discover it through the interface.
- **Normal reviewer access:** no.
- **Fix:** keep the launch-argument read and every test/store-capture argument inside `#if DEBUG`.
  The current branch does this at `WalletStore.swift:94-126`. Release verification must also
  confirm that the binary has no `NSProcessInfo`/launch-argument reference.

### A-02 — HIGH — apparent affiliation with 70 real financial brands (already remediated)

- **Potential guidelines:** 2.3, 2.3.1(a), 5.2.1, 5.6.2
- **File / area:** `Pesolita/Generated/CardTemplates.swift`, bundled template assets and App Store
  screenshots; historical template labels and filenames
- **Behavior found in the rejected lineage:** card templates used real bank, e-wallet, membership
  and payment-brand names while the app was presented in the Finance category.
- **Why Apple can interpret it as hidden or misleading:** the app is not connected to, submitted
  by, or licensed by those institutions. Brand-like cards can make a manual tracker look like an
  authorized banking client or financial credential product.
- **Normal reviewer access:** yes, during onboarding and card editing; the concern is misleading
  representation rather than inaccessible functionality.
- **Fix:** use neutral artwork-derived names and filenames, remove dead branded presets, and use
  fictional demo data. This is already applied. The developer must still retain proof that it owns
  or has permission to distribute every image; recognizable third-party artwork must be replaced.

### A-03 — HIGH — privacy policy not accessible inside the app

- **Potential guideline:** 5.1.1(i); also 1.5 for accessible support contact
- **File / area:** `Pesolita/Screens/SettingsView.swift`, settings groups and footer
- **Current behavior:** the repository has live Privacy and Support pages, but Settings contains no
  link to either page and the app otherwise opens no external URL.
- **Why Apple can interpret it as noncompliant:** Apple explicitly requires a privacy-policy link in
  both App Store Connect and an easily accessible place inside every app.
- **Normal reviewer access:** no.
- **Recommended fix:** add a clearly labeled About & help section in Settings with native links to
  the Privacy Policy and Support pages. Keep the App Store Connect Privacy Policy URL and Support
  URL aligned with the same pages.

### A-04 — HIGH — test/demo wallet source is part of the production app target

- **Potential guidelines:** 2.1, 2.2, 2.3.1(a), 5.6
- **File / area:** `Pesolita/Models/PreviewData.swift`; `WalletStore.load()` Debug call sites
- **Current behavior:** the call sites are Debug-only, but the source file defining a fully funded
  demo wallet and showcase wallet is not compiler-guarded and belongs to the synchronized app
  target.
- **Why Apple can interpret it as hidden:** Release contains source-level dormant demo capability
  even when optimizer dead stripping makes it difficult to invoke. In a build already rejected for
  hidden functionality, relying on optimizer removal is avoidable ambiguity.
- **Normal reviewer access:** no; only UI tests/store-shot launches use it.
- **Recommended fix:** wrap the entire implementation in `#if DEBUG` so the declarations cannot be
  compiled into an App Store build. Keep UI test behavior available in Debug.

### A-05 — MEDIUM — “Low balance nudge” is a visible switch with no implementation

- **Potential guidelines:** 2.1(a), 2.3, 5.6.4
- **File / area:** `Pesolita/Screens/SettingsView.swift:37-45`;
  `Pesolita/Store/WalletStore.swift:710-715`
- **Current behavior:** the preference toggles and persists, but no production view or service reads
  `nudgeLowBalance`. Turning it on delivers no nudge.
- **Why Apple can interpret it as misleading or incomplete:** the app advertises a functioning
  behavior that does not exist. This is not a hidden feature, but it undermines confidence that the
  submitted build is final and accurately represented.
- **Normal reviewer access:** the switch is accessible; its promised result is not.
- **Recommended fix:** either remove the unfinished preference from this release or implement a
  visible, dismissible in-app low-balance notice using the already persisted dismissal IDs. The
  latter preserves the intended feature without adding background behavior.

### A-06 — MEDIUM — daily notification appears enabled before consent or scheduling

- **Potential guidelines:** 2.1(a), 4.5.4, 5.1.1(ii)
- **File / area:** `Pesolita/Models/WalletModels.swift:241,266`;
  `Pesolita/Persistence/BackupCodec.swift:69,169`;
  `Pesolita/Screens/SettingsView.swift:47-54`
- **Current behavior:** a fresh wallet and a backup missing the preference default the daily log
  reminder to `true`, although iOS permission has never been requested and no local notification is
  scheduled. A restored `true` preference also cannot grant native notification permission.
- **Why Apple can interpret it as misleading:** the visible state says the feature is on when it is
  not. Notification consent must be user initiated and the control should reflect actual behavior.
- **Normal reviewer access:** yes, but it initially reports the wrong state.
- **Recommended fix:** default to off, treat a missing backup field as off, never silently enable it
  during restore, and only set it on after authorization and scheduling succeed.

### A-07 — MEDIUM — privacy copy overstates on-device-only behavior

- **Potential guidelines:** 2.3, 5.1.1(i), 5.6
- **File / area:** `Pesolita/Screens/SettingsView.swift:84-90,110` and store metadata derived from
  the same claim
- **Current behavior:** Settings says balances are blurred “on unlock,” although there is no unlock
  event integration, and states “Your numbers never leave this device” beside controls that export
  JSON/CSV to Files, iCloud Drive, email or another app.
- **Why Apple can interpret it as misleading:** local-by-default is accurate; never leaving the
  device is not accurate once the user deliberately exports. “On unlock” describes behavior the
  code does not implement.
- **Normal reviewer access:** yes.
- **Recommended fix:** say balances are hidden across the app and widget, and say data is stored on
  device unless the user exports it.

### A-08 — MEDIUM — support/contact information is absent in the app

- **Potential guideline:** 1.5; supports 5.6.2 transparency
- **File / area:** `Pesolita/Screens/SettingsView.swift`
- **Current behavior:** a support website with a contact email exists, but users cannot discover it
  from the native app.
- **Why Apple can interpret it as a trust issue:** a finance-category app should make it obvious who
  supports it and how to get help, especially following a Developer Code of Conduct rejection.
- **Normal reviewer access:** no.
- **Recommended fix:** expose the Support page next to Privacy Policy in Settings.

### A-09 — LOW — stale financial-brand identifier remains in Widget preview data

- **Potential guidelines:** 5.2.1, 5.6.2
- **File / area:** `PesolitaWidget/PesolitaWidget.swift:25,525,531` and
  `PesolitaWidget/WidgetModels.swift` placeholder IDs
- **Current behavior:** neutral visible labels are used, but internal placeholder IDs still contain
  `preview-bdo` after the brand-removal pass.
- **Why Apple can interpret it as suspicious:** it is not user-visible, but it contradicts the claim
  that financial institution identifiers were removed from the shipping bundle and may be found by
  automated binary inspection.
- **Normal reviewer access:** no; it is an internal placeholder ID.
- **Recommended fix:** rename the stable preview ID to a neutral identifier everywhere.

### A-10 — LOW — production deep links require review-note documentation

- **Potential guidelines:** 2.3.1(a), 2.5.16
- **File / area:** `Pesolita/Store/WalletStore.swift:153-181`; `PesolitaWidget/WidgetModels.swift`;
  `PesolitaWidget/PesolitaWidget.swift`
- **Current behavior:** `pesolita://spend`, `topup`, `card` and `add-card` are used by the WidgetKit
  extension. Card IDs are validated against local cards. Each destination also has a clearly visible
  native entry point in Home/Card Detail. Unknown actions do nothing.
- **Why Apple can interpret it as hidden:** undocumented URL schemes can be used to conceal screens,
  even though this implementation does not do that.
- **Normal reviewer access:** yes, through Home, Card Detail, the plus button and the widget.
- **Recommended fix:** keep the strict allow-list and validation; explain in App Review Notes that
  these four routes only power the bundled widget and map to visible actions. Do not add a secret
  deep-link menu.

## Clean areas / non-applicable rules

- **Review differentiation:** no reviewer account, device, date, locale, country, IP, VPN, receipt,
  sandbox, TestFlight or App Store environment checks.
- **Remote behavior:** no network layer, remote config, push-driven route, WebView, JavaScript,
  dynamic executable code, server account or environment file.
- **Authentication:** no accounts, roles or login. Demo credentials and Sign in with Apple are not
  applicable. App Store Connect should leave “Sign-in required” unchecked.
- **Commerce:** no StoreKit, subscription, paywall, external purchase link, real-money transfer,
  bank connection or payment processing. The app only edits user-entered local ledger numbers.
- **UGC:** no publishing, messaging, social feed or content shared between users; Guideline 1.2
  moderation controls are not applicable.
- **Tracking/data collection:** no analytics, ads, ATT, third-party SDK or developer-accessible data
  transmission. Apple’s definition of “collect” is not met by private on-device storage. User-created
  exports remain under the user’s control.
- **Permissions:** images use the out-of-process `PhotosPicker`; no whole-library, camera,
  microphone, contacts or location permission is requested. Daily reminders request notification
  permission only after the user enables them.
- **Privacy manifests:** app and widget declare no tracking/collection and declare app-group
  `UserDefaults` with required-reason code `CA92.1`.
- **Extensions:** the WidgetKit extension is directly related to the core wallet and its interactive
  routes map to visible app actions.
- **Build config:** Debug alone defines `DEBUG`; bundle IDs, Team ID, app group, signing and build
  number are consistent between app and widget.

## Required verification after remediation

1. Build and test Debug.
2. Build and test Release with testability disabled as shipped.
3. Inspect the Release app and widget bundles for privacy manifests and entitlements.
4. Confirm the Release executable has no launch-argument/`ProcessInfo` reference and no demo data.
5. Re-run repository searches for reviewer detection, remote flags, secret routes and debug hooks.
6. Exercise onboarding, every tab, every card action, widget links, backup/restore, CSV export,
   invalid import, notifications denied/allowed, low-balance notice, privacy links and Start Over.

