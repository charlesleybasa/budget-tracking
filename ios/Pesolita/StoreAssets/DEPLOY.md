# Shipping Pesolita to the App Store — every click

Follow top to bottom. Nothing here assumes you have done it before.

Your URLs are already live:
- Privacy policy → `https://pesolita.vercel.app/privacy`
- Support → `https://pesolita.vercel.app/support`

---

## Step 0 — Already done

Both of these are finished; nothing for you to do here.

- [x] **Support address published.** Both pages carry `charlesleyb24@gmail.com` and are live.
- [x] **iPhone-only.** `TARGETED_DEVICE_FAMILY` is now `"1"` across every target, so the
      iPad layout can no longer be held against you and you do **not** need iPad screenshots.

Start at Step 1.

---

## Step 1 — Confirm you can sign the app

You need the **Apple Developer Program** ($99/year). The project already has a team ID set
(`UZMK9VPGZ7`), which suggests you are enrolled. To be sure:

1. Open `ios/Pesolita/Pesolita.xcodeproj` in Xcode.
2. Click the blue **Pesolita** project icon in the left sidebar.
3. Select the **Pesolita** target → **Signing & Capabilities** tab.
4. **Automatically manage signing** should be ticked and **Team** should show your name.
5. Repeat for the **PesolitaWidget** target.

If Team is empty: Xcode → **Settings** → **Accounts** → **+** → sign in with your Apple ID.
If you are not enrolled yet, do that at <https://developer.apple.com/programs/> first — approval
can take a day or two.

---

## Step 2 — Set the version number

- **Version** `1.0` — what customers see.
- **Build** `1` — must increase on *every* upload, even a re-upload of the same version.

Both are on the same **General** tab of the Pesolita target. Leave them at 1.0 / 1 for your
first submission.

---

## Step 3 — Archive the app

> **There is no upload button in App Store Connect.** The empty **Build** box on the web page
> only *receives* builds — it says "Upload your builds using one of several tools" because the
> uploading happens from Xcode on your Mac. The box stays empty until you finish Step 4, then
> fills in by itself. This is the single most confusing part of the process and it trips
> up nearly everyone the first time.

1. Open `ios/Pesolita/Pesolita.xcodeproj` in Xcode.
2. At the top, next to the Pesolita scheme, click the device selector.
3. Choose **Any iOS Device (arm64)**. *Not* a simulator — Archive is disabled for simulators.
4. Menu bar → **Product** → **Archive**.
5. Wait a few minutes. The **Organizer** window opens on its own when it finishes.

If **Archive** is greyed out, you are still on a simulator. Go back to 3.3.

---

## Step 4 — Upload from the Organizer

In the Organizer window that just opened:

1. Select your archive → **Distribute App**.
2. **App Store Connect** → **Next**.
3. **Upload** → **Next**.
4. Accept the defaults on the signing screens → **Next**.
5. If a **Validate** option is offered, run it first and fix anything it reports.
6. **Upload**.

The first time you do this, Xcode may ask permission to create a **distribution certificate**
and provisioning profile. Say yes — your Mac currently only has a development certificate,
which cannot sign an App Store build.

Uploading takes a few minutes. Apple then **processes** the build for anywhere from 5 to 30
minutes. Only after that does it appear in the Build section of App Store Connect, where you
attach it in Step 10. Refresh the page; there is no notification.

---

## Step 5 — Create the app record

Go to <https://appstoreconnect.apple.com> → **My Apps** → **+** → **New App**.

| Field | What to enter |
|---|---|
| Platforms | iOS |
| Name | `Pesolita` (must be unique across the whole App Store) |
| Primary language | English (U.S.) |
| Bundle ID | `com.pesolita.app` |
| SKU | `pesolita-ios-1` (internal only, any unique string) |
| User Access | Full Access |

If the name is taken, try `Pesolita — Budget Wallet`.

---

## Step 6 — Fill in the listing

On your app's page, left sidebar → **1.0 Prepare for Submission**.

**Subtitle** (30 characters max):
> Manual wallet, zero snooping

**Promotional text** (170 max, editable without review):
> Every peso gets a home. Log spending by hand, see where it goes, and keep every number on your own phone.

**Description** — paste this:

> Pesolita is a budget wallet you fill in yourself.
>
> Make a card for each pocket of your money — a bank account, an e-wallet, a savings goal, or the cash in your bag — and log what goes in and out. No bank login. No syncing. No account. Every number stays on your phone.
>
> WHAT IT DOES
> • A card for every pocket, each one a piece of generated artwork with the balance on the front
> • Log a spend in seconds on a keypad built for money, not a form
> • It stops you overspending — try to spend more than a card holds and Pesolita blocks it, then offers to spend exactly what is there
> • See where your money actually went, by category, this week or this month
> • Search your history by merchant, note or category
> • Move money between your own pockets
> • Attach a receipt photo to any entry
> • Home screen widget for your balance and a one-tap log
> • Back up and restore your wallet as a file you control
>
> WHY MANUAL
> Typing it in takes four seconds and makes you notice. Apps that connect to your bank do the noticing for you, and ask for your bank credentials to do it. Pesolita asks for nothing.
>
> PRIVACY
> Pesolita has no server. It makes no network requests. There is no analytics, no advertising and no tracking of any kind. We could not see your money if we wanted to.

**Keywords** (100 characters total, comma-separated, no spaces after commas):
```
budget,expense,tracker,wallet,money,peso,spending,cash,finance,savings,manual,offline
```

**Support URL:** `https://pesolita.vercel.app/support`
**Marketing URL:** `https://pesolita.vercel.app`

---

## Step 7 — Screenshots

Scroll to **App Previews and Screenshots**. App Store Connect will show one or more display
slots, and each accepts only its own pixel sizes. Both are generated:

| Slot in App Store Connect | Folder to drag from | Size |
|---|---|---|
| iPhone **6.5"** Display | `StoreAssets/AppStore/iphone-6.5/` | 1284 × 2778 |
| iPhone **6.9"** Display | `StoreAssets/AppStore/iphone-6.9/` | 1320 × 2868 |

Drag all five files from the matching folder, in numbered order. If you see the red
*"The dimensions of one or more screenshots are wrong"* banner, you dragged the wrong
folder into that slot — delete them and use the size the banner asks for.

Since the app is iPhone-only, there is no iPad tab to fill in.

## Step 8 — App Privacy (this is the one people get wrong)

Left sidebar → **App Privacy** → **Get Started**.

1. "Do you or your third-party partners collect data from this app?" → **No**
2. Save. That is the whole thing.

This is truthful: the app has no server and makes no network calls. Then set:

**Privacy Policy URL:** `https://pesolita.vercel.app/privacy`

---

## Step 9 — Review information

Still on the Prepare for Submission page, scroll to **App Review Information**.

- **Sign-in required:** leave **UNCHECKED**. There is no login, so there is no demo account
  to provide and no OTP problem to solve.
- **Notes** — paste this:

> Pesolita is a fully offline manual budget wallet. There is no account, no login, no server and no network requests of any kind.
>
> To review: launch the app, complete the ~20 second first-run flow (enter a name, pick a card category and design, enter any starting amount), then tap the blue + button to log a spend.
>
> All data is entered by hand by the user and stored only on device. Nothing is transmitted. Photo attachment uses the system photo picker. The daily reminder uses local notifications only.

- **Contact information:** your name, phone and the email from step 0a.

---

## Step 10 — Attach the build and submit

1. Scroll to the **Build** section → **+** or **Add Build**.
2. Pick the build you uploaded. If it is not there yet, wait — processing takes up to 30 minutes.
3. **Age Rating** → answer all questions "None" / "No" → it will come out **4+**.
4. **Content Rights** → you own or have rights to all content → Yes.
5. **Pricing and Availability** (left sidebar) → **Free**, all territories.
6. **Export Compliance** — if asked, "Does your app use encryption?" → **No**. Already
   declared in `Info.plist`, so it may not even ask.
7. Top right → **Add for Review** → **Submit to App Review**.

---

## What happens next

- **Waiting for Review** → usually 24–48 hours.
- **In Review** → a few hours.
- **Approved** → it goes live, or waits if you chose manual release.

**If you get rejected, do not panic.** Read the message in **Resolution Center**, fix it,
upload a new build with the build number bumped, and reply in the same thread. Most first
submissions get one round of notes.

The rejections most likely to hit this app, in order:
1. Something small in the metadata — fixable in minutes, no new build needed.
2. A screenshot that does not match what the app actually does.

The two big ones — iPad layout (**2.1** / **4.0**) and a dead support address — are already
handled.

---

## Before you submit, run these once by hand

- [ ] Complete first-run setup on a real iPhone.
- [ ] Log a spend, edit it, delete it.
- [ ] Try to spend more than a card holds — confirm it blocks you.
- [ ] Back up the wallet, "Start over", then restore it.
- [ ] Add the widget to your home screen and tap both buttons.
- [ ] Turn on the daily reminder and confirm iOS asks for notification permission.
