# Pesolita for iOS

This folder contains the native SwiftUI port of Pesolita. The checked-in Xcode project targets iOS 18 and is visually validated with an iPhone 17 Pro running iOS 26.5.

## Run it

1. Open `Pesolita.xcodeproj` in Xcode.
2. Select the `Pesolita` scheme and an iPhone simulator.
3. Run the app. A fresh install starts the five-step onboarding journey.

The native app now includes the complete Pesolita experience: onboarding, all 70 bundled card templates, Home deck and stack layouts, card detail and receiving views, Search, Insights, Settings, the full card editor, transaction editing, top-up, card-to-card transfers, local reminders, backup/restore, CSV export, privacy mode, and celebration/empty-state sprite animation.

Interactions use native haptics and restrained local sound cues. Motion follows the web timing while respecting Reduce Motion. On compact iPhones the original bottom navigation remains visible; regular-width iPads use a dedicated navigation rail.

## Add the Home Screen widget

1. Run Pesolita once so it can publish the current wallet.
2. Touch and hold the iPhone Home Screen, choose **Edit → Add Widget**, then search for **Pesolita**.
3. Pick Small, Medium, or Large and choose **Add Widget**.

The large widget shows the selected card artwork, balance, safe-to-spend amount, recent activity, and direct Spend and Top up actions. Its arrows browse cards without opening the app. Medium keeps the card and actions in a compact layout; Small focuses on the selected card's safe-to-spend amount. All sizes respect Pesolita's privacy setting.

The app and extension share only a compact widget snapshot through the `group.com.pesolita.app` App Group. The full wallet, receipts, and imported photos remain in the app container. When running on a physical device, make sure this App Group is registered for the selected Apple Developer team in Xcode's Signing & Capabilities screen.

## Architecture

- `WalletStore` is the main-actor observable state owner.
- `WalletRepository` stores one versioned JSON document atomically in Application Support.
- Imported photos, QR codes, and receipts are stored as separate files; `BackupCodec` converts them to and from web backup v1 data URLs.
- Outfit, card templates, and sprite atlases are bundled. The app performs no network requests.
- Daily reminders are local notifications; no account, tracking, analytics, or server is involved.

## Regenerate shared assets

From the repository root:

```sh
npm run tokens:ios
npm run templates:ios
```

The template generator validates the web manifest and writes the Swift manifest used by the app. Simulator checkpoints from the automated core journey are in `ReferenceScreenshots/Native`; complete-screen QA captures are in `ReferenceScreenshots/NativeComplete`. Matching 402×874 web captures are in `ReferenceScreenshots/Web`, and the `Comparison` plates place web on the left and native on the right.
