# Pesolita 1.7 — release guide

Last shipped: **1.6**. This release: **1.7 (build 13)**, already set in the project.

## 1. Supabase first (before submitting)

Open the Supabase dashboard for project `exapqjxrptjhvvbcnrdr` → **SQL Editor** → New query →
paste **PART 1** of [`supabase/pesolita_pro_account_and_media.sql`](supabase/pesolita_pro_account_and_media.sql)
→ **Run**.

PART 1 adds:
- `delete_my_account()`, which the new **Delete backup & account** button calls to remove the
  sign-in account.
- Storage rules so each user can only read and change their own photo folder.

If you skip PART 1, the button still deletes the backup and photos, but the Google sign-in record
stays. The app then asks the user to email you to finish.

**PART 2** makes backup photos private. Leave it until most people are on 1.7: older versions
download photos by public link and would restore wallets without their photos. When you do run
it, also change the privacy policy line about "hard-to-guess web addresses" (in
`app/privacy/page.tsx`) and redeploy the site.

## 2. Test on your iPhone

1. Settings → Pesolita Pro → Continue with Google: the sheet now shows steps (Google → Find your
   backup → Bring it to this iPhone). Tap **Cancel** on iOS's "wants to use… to sign in" prompt.
   It should go back to Welcome, not a red error screen.
2. Home with a split bill: **Out with friends** is one row. Tap it to open the list, tap again
   to close it.
3. Settings → **Delete backup & account** with a *test* Google account, after running PART 1.
   Check in Supabase that the `snapshots` row, the `media/<id>/` files and the Auth user are gone,
   and that the wallet is still on the phone.

## 3. Upload the build

In Xcode: scheme **Pesolita**, **Any iOS Device** → Product → **Archive** → Distribute App →
App Store Connect → **Upload**.

## 4. App Store Connect

In the sidebar, click **＋** next to iOS App and enter **1.7**, then fill in:

**What's New in This Version**

```
• Delete your Pesolita Pro backup and account any time from Settings.
• A clearer sign-in: see each step while your wallet comes back from your backup.
• Out with friends on Home is now a tidy single row — tap it to see who owes you.
• Backed-up photos, QR codes and receipts restore more reliably.
• Cancelling Google sign-in now simply takes you back.
```

**Build:** choose **1.7 (13)**.

**Screenshots:** under App Previews and Screenshots, delete the old ones, then drag in
`ios/Pesolita/StoreAssets/AppStore-v2/iphone-6.9/01…09.png` (6.9" slot) and
`…/iphone-6.5/01…09.png` (6.5" slot), in number order. Details and the reasoning behind each
rule are in `StoreAssets/SCREENSHOTS-V2.md`.

**App Review Information → Notes:** keep the 1.6 notes and add:

```
Account deletion: Settings → Delete backup & account (shown while signed in with Google). It removes the cloud backup, its photos and the sign-in account; the wallet on the device is kept.
```

**App Privacy:** no change. The data types are the same as 1.6.

Then click **Add for Review → Submit**.

## 5. After release

- Deploy the website, since `/privacy` and `/support` now mention the in-app deletion. Deploy
  from a clean copy of the release commit, as for 1.6. The working folder may hold unreleased
  web changes.
- A few weeks after release, run PART 2 of the SQL (private photos), then update the privacy
  line and redeploy.
