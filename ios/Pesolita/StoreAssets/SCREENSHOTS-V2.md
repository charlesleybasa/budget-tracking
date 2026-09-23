# App Store screenshots v2 (Pesolita 1.7)

Nine panels, designed as one panorama so the gallery flows when swiped: ink background, gold
and blue glows, and a gold ribbon crossing every panel edge.

| # | Headline | Screen | Feature |
|---|----------|--------|---------|
| 1 | Every peso **gets a home.** | Home (dark) + small widget | Wallet, widget |
| 2 | Split the bill **in one tap.** | Log a spend, Split with open | NEW: split bills |
| 3 | Trips, **totalled for you.** | Day 1 Thailand event | NEW: events |
| 4 | Know who **still owes you.** | Home, Out with friends open | Out with friends |
| 5 | Paid back? **Slide it home.** | Paid-me slider | Settle |
| 6 | Back up **every peso.** | Pesolita Pro sheet | Pro (labelled IN-APP PURCHASE) |
| 7 | Light or dark. **Always lovely.** | Home, light and dark | Themes |
| 8 | See where **it all went.** | Insights | Insights |
| 9 | Your balance, **at a glance.** | Large + small widget | Widget |

The first three are the ones people see in search results, so they carry the new features.

## Upload

App Store Connect → Pesolita → the version's page → **App Previews and Screenshots**:

- **iPhone 6.9" Display**: drag in `AppStore-v2/iphone-6.9/01.png … 09.png` (1320 × 2868).
- **iPhone 6.5" Display**: drag in `AppStore-v2/iphone-6.5/01.png … 09.png` (1284 × 2778).

Drag them in numbered order, and delete the old ones first. The order you drop them in is the
order people see. Screenshots can be changed with any new version, and they get reviewed with
it.

## Why these won't get rejected

| Rule | How it's handled |
|------|------------------|
| 2.3.3: show the app in use | Every panel is a real screen from the app, captured from the simulator. None are mock-ups or splash art. |
| 2.3.7: accurate metadata | Every claim matches what the app does. "100% offline" is gone, since Pro backs up to the cloud. The widget line says what the widget shows. |
| 2.3.2: in-app purchases | The Pro panel's label reads **PESOLITA PRO · IN-APP PURCHASE**. |
| Prices | None shown. They differ by country, and the simulator's is a test price. The Pro button reads "Get Pesolita Pro" in captures. |
| 5.2.1: trademarks | The screenshot wallet uses Pesolita's own generated card art, with no bank-style templates, bank names, logos or brand merchants. |
| People | Friends are initials in coloured circles. No photos of real people. |
| Status bar | 9:41, full signal and battery, as Apple's own screenshots use. |
| Format | Exact sizes, PNG, no transparency. |

## Regenerate

```
cd ios/Pesolita
xcodebuild build -project Pesolita.xcodeproj -scheme Pesolita \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/pesolita-dd
cd StoreAssets
./capture.sh /tmp/pesolita-dd/Build/Products/Debug-iphonesimulator/Pesolita.app
swift render-v2.swift
```

- Copy and callouts are in the `panels` array at the top of `render-v2.swift`.
- The sample wallet is `WalletSnapshot.storeShowcase` in `Models/PreviewData.swift`, which only
  exists in Debug builds.
- The capture hooks only exist in Debug builds: `--store`, `--theme=`, `--sheet=split`,
  `--split-open`, `--route=event|people`, `--settle`, `--owed-expanded`, `--open-pro`.
- The widgets in panels 1 and 9 are cut from `raw/widget-home.png`. `capture.sh` can't
  produce it, because a widget has to be added to the Home Screen by hand. To redo it:
  1. After `capture.sh`, launch the store wallet once on the iPhone 17 Pro Max simulator.
  2. Go to the Home Screen, long-press an empty spot, then Edit → Add Widget → Pesolita.
     Add the **small** one, then the **large** one.
  3. Run `xcrun simctl io "iPhone 17 Pro Max" screenshot raw/widget-home.png`.

  If the widgets land somewhere else on the Home Screen, adjust the two crop rectangles in
  `render-v2.swift` (`smallWidget`, `largeWidget`).
