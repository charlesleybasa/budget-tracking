import type { Metadata } from "next";
import Link from "next/link";

import styles from "./about.module.css";

export const metadata: Metadata = {
  title: "Pesolita — the budget wallet you fill in yourself",
  description:
    "A pocket for every card, wallet and stash of cash. No bank login, no syncing, no account — every number stays on your phone.",
  openGraph: {
    title: "Pesolita — the budget wallet you fill in yourself",
    description: "No bank login. No account. Every number stays on your phone.",
    images: ["/icon.png"],
  },
};

/** Real card artwork from the app, doubled so the marquee can loop seamlessly. */
const CARDS = [
  "banks/bpi-debit",
  "e-wallets/gcash-ewallet",
  "credit-cards/bpi-platinum-rewards-credit",
  "digital-banks/go-tyme-digital-bank",
  "banks/bdo-debit",
  "e-wallets/grab-pay-ewallet",
  "banks/chinabank-debit",
  "prepaid/beep-prepaid",
];

const FEATURES = [
  {
    shot: "/shots/guard.webp",
    title: "It stops you overspending.",
    body: "Try to spend more than a card actually holds and Pesolita refuses, tells you exactly how short you are, then offers to spend what is really there. Most budget apps let the number go negative and leave you to notice.",
    alt: "Logging a spend larger than the card balance, showing the block",
  },
  {
    shot: "/shots/templates.webp",
    title: "Seventy cards. Yours looks like yours.",
    body: "Pick the bank, e-wallet, credit or prepaid design that matches the card in your pocket, or let the app generate artwork from a palette. Every balance is checked for contrast against its own background, so the number is always readable.",
    alt: "Choosing a card design during setup",
  },
  {
    shot: "/shots/logged.webp",
    title: "Four seconds, then back to your life.",
    body: "A keypad built for money instead of a form. Type the amount, pick a category — or let it guess from your note — and you are done. Attach a receipt if it matters.",
    alt: "Confirmation after logging a spend",
  },
];

export default function AboutPage() {
  return (
    <main className={styles.page}>
      <nav className={styles.nav}>
        <Link href="/about" className={styles.brand}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/icon.png" alt="" className={styles.mark} />
          Pesolita
        </Link>
        <div className={styles.navLinks}>
          <Link href="/privacy" className={styles.navLink}>
            Privacy
          </Link>
          <Link href="/support" className={styles.navLink}>
            Support
          </Link>
          <Link href="/" className={`${styles.navLink} ${styles.navCta}`}>
            Open the app
          </Link>
        </div>
      </nav>

      <header className={styles.hero}>
        <div className={styles.heroGlow} aria-hidden="true" />
        <div className={styles.heroInner}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/icon.png" alt="" className={styles.mascot} />
          <h1 className={styles.h1}>
            Every peso gets a <span className={styles.accentWord}>home</span>.
          </h1>
          <p className={styles.heroBody}>
            Pesolita is a budget wallet you fill in yourself. A pocket for each card, e-wallet
            and stash of cash — and a running total you can actually trust, because you put
            every number there.
          </p>
          <div className={styles.ctaRow}>
            <Link href="/" className={styles.ctaPrimary}>
              Try it in your browser →
            </Link>
            <Link href="/support" className={styles.ctaGhost}>
              How it works
            </Link>
          </div>
          <p className={styles.ctaNote}>Coming to the App Store for iPhone.</p>
        </div>

        <div className={styles.rail} aria-hidden="true">
          <div className={styles.railTrack}>
            {[...CARDS, ...CARDS].map((card, index) => (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                key={`${card}-${index}`}
                src={`/card-templates/${card}.webp`}
                alt=""
                className={styles.railCard}
                loading="lazy"
              />
            ))}
          </div>
        </div>
      </header>

      <section className={styles.section}>
        <div className={styles.sectionInner}>
          <h2 className={styles.h2}>Typing it in is the point.</h2>
          <p className={styles.sectionBody}>
            Apps that plug into your bank do the noticing for you — and ask for your banking
            credentials to do it. Pesolita asks for nothing, because it connects to nothing.
            Four seconds of typing is what makes a spend register as a decision instead of a
            line item you scroll past at the end of the month.
          </p>
          <p className={styles.sectionBody}>
            It also means the app works for money no bank can see: the cash in your bag, the
            envelope for rent, the jar you are slowly filling.
          </p>

          {FEATURES.map((feature, index) => (
            <div
              key={feature.title}
              className={`${styles.feature} ${index % 2 === 1 ? styles.featureFlip : ""}`}
            >
              <div className={styles.featureCopy}>
                <h3 className={styles.h3}>{feature.title}</h3>
                <p>{feature.body}</p>
              </div>
              <div className={styles.shotWrap}>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={feature.shot} alt={feature.alt} className={styles.shot} loading="lazy" />
              </div>
            </div>
          ))}
        </div>
      </section>

      <section className={styles.band}>
        <div className={styles.bandInner}>
          <h2 className={styles.bandH2}>We could not read your money if we wanted to.</h2>
          <p className={styles.bandBody}>
            Pesolita has no server. It makes no network requests, ships no analytics and
            contains no third-party code at all. Everything you type is stored on your own
            device, and there is no copy of it anywhere else.
          </p>
          <div className={styles.bandList}>
            <span className={styles.bandChip}>No account</span>
            <span className={styles.bandChip}>No bank login</span>
            <span className={styles.bandChip}>No analytics</span>
            <span className={styles.bandChip}>No ads</span>
            <span className={styles.bandChip}>No tracking</span>
            <span className={styles.bandChip}>Works offline</span>
          </div>
        </div>
      </section>

      <section className={styles.section}>
        <div className={styles.sectionInner}>
          <h2 className={styles.h2}>Start with one card.</h2>
          <p className={styles.sectionBody}>
            Setup takes about twenty seconds: your name, the kind of pocket, a design, and what
            is in it right now. Add the rest whenever you feel like it — or never.
          </p>
          <div className={styles.ctaRow} style={{ justifyContent: "flex-start" }}>
            <Link href="/" className={styles.ctaPrimary}>
              Open Pesolita →
            </Link>
          </div>
        </div>
      </section>

      <footer className={styles.footer}>
        <div className={styles.footerInner}>
          <div className={styles.footerNote}>
            Pesolita — a manual budget wallet. Your numbers never leave your device.
          </div>
          <div className={styles.footerLinks}>
            <Link href="/privacy" className={styles.navLink}>
              Privacy Policy
            </Link>
            <Link href="/support" className={styles.navLink}>
              Support
            </Link>
            <Link href="/" className={styles.navLink}>
              Open the app
            </Link>
          </div>
        </div>
      </footer>
    </main>
  );
}
