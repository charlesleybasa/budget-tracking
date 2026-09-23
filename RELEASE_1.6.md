# Pesolita 1.6 — App Store Connect release guide

Last shipped: **1.5**. This release: **1.6 (build 12)**, already set in the project for both the
app and the widget.

---

## 0. Before you upload (must do)

| # | Task | Why |
|---|------|-----|
| 1 | **Deploy the website** (`/privacy`, `/support`, `/about` were updated) | The Privacy Policy still said "no account, no server, nothing collected." Pro backup made that untrue, and App Review compares the policy with the app. |
| 2 | **Test on a real iPhone** with your own Google account: fresh install → *Restore your wallet* → Continue with Google | I could not sign in to Google from here. This is the one flow that can't be checked without you. |
| 3 | Test **Combine**: make one card by hand on a clean install, then sign in with a Google account that has a backup | This is the "made a wallet by hand, then remembered Pro" case. Check that both wallets end up there. |
| 4 | Test a **sandbox purchase** of Pesolita Pro (Settings → Pesolita Pro) | The sheet was rebuilt and should show the App Store price, not a hard-coded ₱49. |
| 5 | Commit the working tree | Nothing from this session is committed yet. |

### Upload the build (Xcode)

1. Open `ios/Pesolita/Pesolita.xcodeproj`, set the scheme to **Pesolita** and the destination to **Any iOS Device (arm64)**.
2. **Product → Archive**.
3. In the Organizer: **Distribute App → App Store Connect → Upload**, and keep the defaults (automatic signing, upload symbols).
4. Wait for the "build has completed processing" email (usually 10–30 min).

---

## 1. Create the version

App Store Connect → **Apps → Pesolita → iOS App**. In the left sidebar click **＋** next to *iOS App* and enter **1.6**.

## 2. Fields to change on the 1.6 page

### What's New in This Version (paste this)

```
Your Pesolita Pro backup, done right.

• Restore your wallet on a new iPhone — tap "Restore your wallet" and continue with Google.
• Started a wallet before signing in? Pesolita now asks whether to combine both, keep your backup, or keep this iPhone's. Nothing is replaced without asking.
• Backups are safer: an empty or older wallet can never overwrite your backup, and card photos, QR codes and receipts come back when you restore.
• Restore Purchases, so Pesolita Pro follows your Apple ID to any iPhone.
• A redesigned Pesolita Pro screen that shows exactly how your backup is doing.
• Light and dark mode polished across every screen, with clearer text and buttons.
• Fixes: the card editor heading no longer hides behind the Templates/DIY switch, and more.
```

The same in Filipino, if you localize:

```
Mas ligtas na ang Pesolita Pro backup mo.

• Ibalik ang wallet mo sa bagong iPhone — i-tap ang "Restore your wallet" at mag-continue with Google.
• May nagawa ka nang wallet bago mag-sign in? Tatanungin ka na ng Pesolita kung pagsasamahin, gagamitin ang backup, o itatabi ang nasa iPhone. Walang mapapalitan nang hindi mo pinapayagan.
• Hindi na mapapatungan ng luma o walang laman na wallet ang backup mo, at babalik din ang mga larawan, QR code at resibo.
• Restore Purchases — sasama ang Pesolita Pro sa Apple ID mo sa kahit anong iPhone.
• Bagong disenyo ng Pesolita Pro screen.
• Mas maayos na light at dark mode sa bawat screen.
• Mga pag-aayos sa card editor at iba pa.
```

### Build

Under **Build**, click **＋** and choose **1.6 (12)**. It shows up once processing finishes.

For export compliance, answer **No** (the app uses only standard HTTPS). `ITSAppUsesNonExemptEncryption = false` is already in Info.plist, so this is usually skipped.

### Promotional Text (optional, changes without review)

```
Pesolita Pro: back up your wallet with Google and bring it back on any iPhone. One payment, yours forever.
```

### Screenshots

Optional. Existing ones stay valid. If you want to show Pro, capture it with the debug launch
arguments `--demo-wallet --open-pro` in the simulator.

### Description / Keywords

Take out any line that says the app is "100% offline", has "no account", or "never sends data".
You could add:

```
PESOLITA PRO (optional, one-time purchase)
Back up your wallet with Google and restore it on any iPhone — cards, transactions, card photos, QR codes and receipts.
```

Keywords to consider adding: `backup,restore,sync`.

### App Review Information → Notes (paste this)

```
Pesolita works fully offline without an account. Pesolita Pro (non-consumable, com.pesolita.pro) adds optional cloud backup.

To review Pro:
1. Settings → "Upgrade to Pesolita Pro" → buy with a sandbox account (or use Restore Purchases).
2. The same sheet then shows "Turn on your backup" → Continue with Google (any Google account).
3. To test restore: delete the app, reinstall, tap "Been here before? Restore your wallet" on the first screen, and sign in with the same Google account.

Google sign-in is used only for the optional backup; it is never required to use the app. Card templates are visual styles only and are not connected to any bank ("Visual style only. Not connected to your bank." is shown in the picker).
```

Sign-in required: **No**. The core app needs no login.

### Version Release

Choose **Manually release this version** so you control the day, or *Automatically*.

## 3. App Privacy (App-level page, not the version page)

Left sidebar → **App Privacy → Edit**. This is required: it has to match the updated privacy
manifest (`PrivacyInfo.xcprivacy`) and policy.

Data collected: **Yes**. Tick these:

| Data type | Linked to user | Tracking | Purpose |
|-----------|---------------|----------|---------|
| Contact Info → **Email Address** | Yes | No | App Functionality |
| Identifiers → **User ID** | Yes | No | App Functionality |
| Financial Info → **Other Financial Info** | Yes | No | App Functionality |
| User Content → **Photos or Videos** | Yes | No | App Functionality |
| User Content → **Other User Content** | Yes | No | App Functionality |

Leave everything else unticked: no analytics, no ads, no tracking. Then **Publish**.

The Privacy Policy URL stays the same. Just make sure the updated page is deployed first.

## 4. In-App Purchase

No changes, as long as `com.pesolita.pro` is already **Approved**. If it's still *Ready to Submit*,
attach it to this version under **In-App Purchases and Subscriptions** on the version page.

## 5. Submit

**Add for Review → Submit to App Review.**

---

## Review risks worth knowing

- **Account deletion (Guideline 5.1.1(v)).** Signing in with Google creates an account in
  Supabase. Apple requires apps that create accounts to let users *start* deleting them inside
  the app. 1.5 passed without it, but a reviewer can raise it at any time. For now the policy
  says "email us to delete". The proper fix is a **Delete backup & account** button in
  Settings: it would delete the `snapshots` row and the `media/<user id>/` files, then remove
  the account through a Supabase database function.
- **Sign in with Apple (Guideline 4.8).** Apple asks for a privacy-focused login option when an
  app uses a third-party login. Google here is only for optional backup, which usually passes,
  and it did in 1.5. If a reviewer raises it, the fix is adding Sign in with Apple next to
  Google. Supabase supports it.
- **Public photo links.** Backed-up photos are stored in a *public* Supabase bucket at
  hard-to-guess addresses. The policy now says this honestly. Making the bucket private with
  signed URLs would be better.

## What changed in code for 1.6

- Version is now **1.6 (12)**. Info.plist now reads the version from the project settings, so
  the two can't drift apart again (it used to hard-code an old number).
- `PrivacyInfo.xcprivacy` now declares the Pro backup data. It used to say nothing was
  collected.
- Sync safety: nothing uploads before the app has read the cloud copy. An empty wallet can't
  overwrite a backup, and "Start over" keeps the cloud copy.
- The restore flow opens from onboarding. It did nothing before, because the sheet wasn't
  attached while onboarding was showing.
- The Pro sheet was redesigned. It sizes itself to its content and follows light and dark mode.
- Light/dark colour roles, card-editor heading fix, and 50/50 tests passing.
- Website: privacy, support and about pages updated for Pro backup.
