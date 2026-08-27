import type { Metadata } from "next";
import Link from "next/link";

import styles from "../legal.module.css";

export const metadata: Metadata = {
  title: "Support — Pesolita",
  description: "Help, answers and contact for Pesolita, the manual budget wallet.",
};

// Published deliberately: App Review may email this, and the support URL has to offer a
// real way to get in touch.
const CONTACT = "charlesleyb24@gmail.com";

export default function SupportPage() {
  return (
    <main className={styles.page}>
      <div className={styles.inner}>
        <Link href="/" className={styles.brand}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/icon.png" alt="" className={styles.mark} />
          Pesolita
        </Link>

        <div className={styles.kicker}>Support</div>
        <h1 className={styles.title}>Help with Pesolita</h1>

        <p className={styles.lede}>
          Pesolita is a manual wallet. You make a card for each pocket of your money — a bank
          account, an e-wallet, the cash in your bag — and log what goes in and out yourself.
          It never connects to a bank.
        </p>

        <h2 className={styles.h2}>Getting started</h2>
        <p className={styles.body}>
          Open the app, enter your name, choose a card category and design, then set what is in
          it right now. That is the whole setup. Tap the blue button any time to log a spend.
        </p>

        <h2 className={styles.h2}>Why can&apos;t I log this spend?</h2>
        <p className={styles.body}>
          A card cannot go below zero. If the amount is more than the card holds, Pesolita
          blocks it and offers to spend exactly what is there instead, or to top the card up
          first. Frozen cards also refuse spending — unfreeze the card from its detail screen.
        </p>

        <h2 className={styles.h2}>Moving to a new phone</h2>
        <p className={styles.body}>
          Go to <strong>Settings → Back up wallet</strong> and save the file somewhere you can
          reach from the new phone. On the new device, choose <strong>Restore from backup</strong>{" "}
          during setup or from Settings. Restoring replaces the wallet on that phone rather
          than merging, so two histories can never double up.
        </p>

        <h2 className={styles.h2}>I deleted something by accident</h2>
        <p className={styles.body}>
          There is no server and no cloud copy, so nothing can be recovered unless you have a
          backup file. Backing up now and then is worth the ten seconds.
        </p>

        <h2 className={styles.h2}>Is my data private?</h2>
        <p className={styles.body}>
          Completely. Nothing is collected and nothing is transmitted. See the{" "}
          <Link href="/privacy">Privacy Policy</Link> for the details.
        </p>

        <h2 className={styles.h2}>Still stuck?</h2>
        <p className={styles.body}>
          Email <a href={`mailto:${CONTACT}`}>{CONTACT}</a> and tell us what happened, what you
          expected, and which iPhone you are using. We read everything.
        </p>

        <div className={styles.footer}>
          Pesolita — a manual budget wallet. Your numbers never leave your device.
          <br />
          <Link href="/privacy" className={styles.back}>
            Privacy Policy →
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
