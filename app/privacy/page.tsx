import type { Metadata } from "next";
import Link from "next/link";

import styles from "../legal.module.css";

export const metadata: Metadata = {
  title: "Privacy Policy — Pesolita",
  description: "Pesolita keeps your wallet on your device. Only if you turn on Pesolita Pro backup is a copy stored in the cloud, under your Google sign-in.",
};

const UPDATED = "25 September 2026";
// Published deliberately: App Review may email this, and the support URL has to offer a
// real way to get in touch.
const CONTACT = "charlesleyb24@gmail.com";

export default function PrivacyPage() {
  return (
    <main className={styles.page}>
      <div className={styles.inner}>
        <Link href="/" className={styles.brand}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/icon.png" alt="" className={styles.mark} />
          Pesolita
        </Link>

        <div className={styles.kicker}>Legal</div>
        <h1 className={styles.title}>Privacy Policy</h1>
        <p className={styles.updated}>Last updated {UPDATED}</p>

        <p className={styles.lede}>
          Pesolita keeps your wallet on your own device. There are no ads and no analytics. The
          only time anything leaves your phone is if you buy Pesolita Pro and choose to back up
          with Google — and then only so you can get your wallet back.
        </p>

        <h2 className={styles.h2}>What we collect</h2>
        <p className={styles.body}>
          Without Pesolita Pro backup, nothing. The app works fully offline and sends nothing
          while you use it. The web version of Pesolita never sends your wallet anywhere.
        </p>

        <h2 className={styles.h2}>Pesolita Pro cloud backup (iPhone, optional)</h2>
        <p className={styles.body}>
          If you buy Pesolita Pro and sign in with Google to turn on backup, we store the
          following so you can restore your wallet on this or another iPhone:
        </p>
        <ul className={styles.list}>
          <li>Your Google account&apos;s email address and an account ID.</li>
          <li>
            A copy of your wallet: cards, balances, transactions, notes, the names you add for
            splitting bills, events and your settings.
          </li>
          <li>Card artwork, receiving QR codes and receipt photos you attached.</li>
        </ul>
        <p className={styles.body}>
          This is used only to back up and restore your wallet. It is never used for
          advertising, never sold and never shared. It is stored with our database and storage
          provider, Supabase, and sign-in is handled by Google. Photos, QR codes and receipts
          are kept in a private folder that only your own sign-in can open.
        </p>
        <p className={styles.body}>
          Signing out stops backup; your wallet stays on your phone and the backup stays in the
          cloud. To delete your backup, its photos and your account, open Pesolita and go to
          Settings → Delete backup &amp; account (Pesolita 1.7 or later). You can also email us from
          the Google address you signed in with and we will delete them within 30 days.
        </p>
        <p className={styles.body}>
          Purchases are handled entirely by Apple. We never see your payment details.
        </p>

        <h2 className={styles.h2}>What stays on your device</h2>
        <p className={styles.body}>
          Everything you create lives in Pesolita&apos;s own private storage on your phone:
        </p>
        <ul className={styles.list}>
          <li>Your cards, balances, spending limits and transaction history.</li>
          <li>Your name, if you enter one during setup.</li>
          <li>Any receipt photos, card artwork or receiving QR codes you attach.</li>
          <li>Your settings, such as hiding balances or turning on reminders.</li>
        </ul>
        <p className={styles.body}>
          Deleting the app removes all of it from your phone. So does &ldquo;Start over&rdquo; in
          Settings. Unless you use Pesolita Pro backup, we hold no copy and cannot restore
          anything for you.
        </p>

        <h2 className={styles.h2}>Photos</h2>
        <p className={styles.body}>
          When you attach a receipt or card image, iOS shows its own photo picker and hands
          Pesolita only the single image you choose. The app never gains access to your photo
          library, and the image is stored on your device alongside the rest of your wallet.
        </p>

        <h2 className={styles.h2}>Notifications</h2>
        <p className={styles.body}>
          If you switch on the daily reminder, the notification is scheduled locally by iOS on
          your device. No push service is involved and no notification passes through us.
        </p>

        <h2 className={styles.h2}>Backups you create</h2>
        <p className={styles.body}>
          You can export a backup file or a CSV. Those files are created by you, and they go
          wherever you send them — Files, iCloud Drive, email, another app. Once a file leaves
          Pesolita it is covered by that destination&apos;s privacy policy, not this one.
        </p>

        <h2 className={styles.h2}>Third parties and tracking</h2>
        <p className={styles.body}>
          Pesolita contains no advertising, no analytics and no crash reporting. The only third
          parties involved are the ones Pesolita Pro backup needs — Google for sign-in and
          Supabase for storage — and only if you turn it on. We do not track you across apps or
          websites, and we do not sell or share your data.
        </p>

        <h2 className={styles.h2}>This website</h2>
        <p className={styles.body}>
          The page you are reading is hosted on Vercel, which — like any web host — records
          standard server request logs including IP addresses. That applies to visiting this
          site only. It has nothing to do with the app on your phone.
        </p>

        <h2 className={styles.h2}>Children</h2>
        <p className={styles.body}>
          Pesolita is suitable for all ages. Without Pesolita Pro backup it collects no personal
          information from anyone, children included.
        </p>

        <h2 className={styles.h2}>Changes</h2>
        <p className={styles.body}>
          If this policy changes, the date at the top of this page changes with it.
        </p>

        <h2 className={styles.h2}>Contact</h2>
        <p className={styles.body}>
          Questions about privacy? Email <a href={`mailto:${CONTACT}`}>{CONTACT}</a>.
        </p>

        <div className={styles.footer}>
          Pesolita — a manual budget wallet. Your numbers stay on your device unless you back them up.
          <br />
          <Link href="/support" className={styles.back}>
            Support &amp; help →
          </Link>
          <br />
          <Link href="/about" className={styles.back}>
            About Pesolita →
          </Link>
        </div>
      </div>
    </main>
  );
}
