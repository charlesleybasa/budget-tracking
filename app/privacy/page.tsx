import type { Metadata } from "next";
import Link from "next/link";

import styles from "../legal.module.css";

export const metadata: Metadata = {
  title: "Privacy Policy — Pesolita",
  description: "Pesolita collects nothing and transmits nothing. Every number you enter stays on your device.",
};

const UPDATED = "27 August 2026";
// App Review needs a working contact route; swap this for the address you want to publish.
const CONTACT = "support@pesolita.app";

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
          Pesolita does not collect your data. There is no account, no server and no analytics.
          Every number you type stays on your own device, and nothing is sent anywhere.
        </p>

        <h2 className={styles.h2}>What we collect</h2>
        <p className={styles.body}>
          Nothing. Pesolita has no backend and makes no network requests while you use it. We
          cannot see your balances, your transactions, your card names or anything else you
          enter, because none of it ever reaches us.
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
          Deleting the app removes all of it. So does &ldquo;Start over&rdquo; in Settings.
          Because there is no server, we hold no copy and cannot restore anything for you.
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
          Pesolita contains no advertising, no analytics, no crash reporting and no third-party
          SDKs of any kind. We do not track you across apps or websites, and we do not sell or
          share data — because we have none to sell or share.
        </p>

        <h2 className={styles.h2}>This website</h2>
        <p className={styles.body}>
          The page you are reading is hosted on Vercel, which — like any web host — records
          standard server request logs including IP addresses. That applies to visiting this
          site only. It has nothing to do with the app on your phone.
        </p>

        <h2 className={styles.h2}>Children</h2>
        <p className={styles.body}>
          Pesolita is suitable for all ages and collects no personal information from anyone,
          children included.
        </p>

        <h2 className={styles.h2}>Changes</h2>
        <p className={styles.body}>
          If this policy changes, the date at the top of this page changes with it. Since the
          app collects nothing, we do not expect meaningful changes.
        </p>

        <h2 className={styles.h2}>Contact</h2>
        <p className={styles.body}>
          Questions about privacy? Email <a href={`mailto:${CONTACT}`}>{CONTACT}</a>.
        </p>

        <div className={styles.footer}>
          Pesolita — a manual budget wallet. Your numbers never leave your device.
          <br />
          <Link href="/support" className={styles.back}>
            Support &amp; help →
          </Link>
        </div>
      </div>
    </main>
  );
}
