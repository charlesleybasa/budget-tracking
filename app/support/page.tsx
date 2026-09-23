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
        <p className={styles.body}>
          With <strong>Pesolita Pro</strong> on iPhone, it is simpler: on the new phone tap{" "}
          <strong>Been here before? Restore your wallet</strong> and continue with the same
          Google account. If you already started a wallet on that phone, Pesolita asks whether
          to combine the two, keep your backup, or keep the phone&apos;s — nothing is replaced
          without asking.
        </p>

        <h2 className={styles.h2}>Deleting your Pesolita Pro backup</h2>
        <p className={styles.body}>
          In Pesolita, go to <strong>Settings → Delete backup &amp; account</strong> (version 1.7
          or later). It removes your cloud backup, its photos and your sign-in straight away. Or
          email us from the Google address you signed in with and we will do it within 30 days.
          Either way, the wallet on your phone is not affected, and Pesolita Pro stays with your
          Apple ID.
        </p>

        <h2 className={styles.h2}>I deleted something by accident</h2>
        <p className={styles.body}>
          Without Pesolita Pro backup there is no cloud copy, so nothing can be recovered
          unless you have a backup file. Backing up now and then is worth the ten seconds.
        </p>

        <h2 className={styles.h2}>Is my data private?</h2>
        <p className={styles.body}>
          Yes. Without Pesolita Pro backup nothing is collected or transmitted. With it, your
          wallet is stored only so you can restore it — no ads, no tracking. See the{" "}
          <Link href="/privacy">Privacy Policy</Link> for the details.
        </p>

        <h2 className={styles.h2}>Still stuck?</h2>
        <p className={styles.body}>
          Email <a href={`mailto:${CONTACT}`}>{CONTACT}</a> and tell us what happened, what you
          expected, and which iPhone you are using. We read everything.
        </p>

        <div className={styles.footer}>
          Pesolita — a manual budget wallet. Your numbers stay on your device unless you back them up.
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
