# Pesolita native parity QA

Reference: production web app at `https://pesolita.vercel.app/`, inspected at a 402 × 874 CSS viewport. Native captures use an iPhone 17 Pro simulator; the iOS status and home-indicator safe areas are intentionally native.

## Verified surfaces

| Surface | Result | Evidence |
| --- | --- | --- |
| Home wallet stack | Pass | `01-home-stack.png` |
| Insights empty state | Pass | `02-insights-empty.png` |
| Search empty state | Pass | `03-search-empty.png` |
| Settings and feedback preferences | Pass | `04-settings.png` |
| Card detail empty state | Pass | `05-card-detail-empty.png` |
| Card-to-card transfer | Pass | `06-transfer.png` |
| Template card editor | Pass | `07-card-editor.png` |

## Corrections made during parity review

- Replaced oversized, system-default compositions with the web app's compact black/white sectional layout, fixed 320 × 196 card geometry, Outfit typography, spacing, pills, floating navigation, and stacked-card overlap.
- Matched Home deck/stack, Card Detail, Insights, Search, Settings, Transfer, and Card Editor structures to the production web implementation.
- Corrected the idle mascot atlas from an incorrect 10 × 6 interpretation to its real 10 × 3, 30-frame grid. The full mascot now renders at 30fps in Search and Insights.
- Added native haptics and synthesized interaction cues for tap, keypad, open/close, toggles, spend, top-up, transfer, success, warning, and delete. The frequencies and envelopes follow the Android/web feedback implementation.
- Added persistent Haptics and Sound effects switches with migration-safe defaults for existing wallet documents.

## Automated verification

`xcodebuild test` on iPhone 17 Pro passed:

- 15 unit/persistence tests, including all 70 templates, spending and frozen-card rules, top-up, transfer conservation, search, card deletion, template naming, atomic persistence, web backup compatibility, feedback preference migration, and restore-to-Home behavior.
- 3 UI tests: the complete fresh-install onboarding → template → fund → Home → spend → celebration journey, reachability of every completed surface, and native Save/Open picker presentation for Backup and Restore.

Build and test result: pass.
