import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";

import { BrandWordmark } from "@/components/BrandWordmark";
import { Mascot } from "@/components/Mascot";
import { SpriteAnimation } from "@/components/SpriteAnimation";
import {
  CELEBRATE,
  FLYING_IDLE,
  IDLE_STEADY,
  NO_NO_NO,
  PEEKABOO,
  SAD,
} from "@/lib/sprites";

import styles from "./brand.module.css";

export const metadata: Metadata = {
  title: "Pesolita Brand System",
  description:
    "The Pesolita brand system: wordmark, mascot roles, palette, typography and product moments.",
};

const COLORS = [
  { name: "Peso Gold", hex: "#FFCA28", role: "Primary action, coin, optimism" },
  { name: "Pocket Ink", hex: "#0B0B0C", role: "App shell, privacy, focus" },
  { name: "Paper", hex: "#FFFFFF", role: "Sheets, fields, calm contrast" },
  { name: "Ipis Shell", hex: "#985B33", role: "Mascot body and warmth" },
  { name: "Leaf Strap", hex: "#78BC8B", role: "Growth, safe progress" },
  { name: "Signal Blue", hex: "#1D6FF2", role: "Secondary app action" },
  { name: "Cheek Coral", hex: "#E79A87", role: "Human warmth and delight" },
  { name: "Warning Red", hex: "#F0483E", role: "Blocked spend and alerts" },
];

const PERSONALITY = ["Friendly", "Manual-first", "Private", "Encouraging", "Peso-smart"];

const MASCOTS = [
  { title: "Welcome", use: "First hello and name setup", sheet: PEEKABOO, mood: "wave" as const },
  { title: "Success", use: "Spend, top-up and transfer confirmation", sheet: CELEBRATE, mood: "cheer" as const },
  { title: "Empty", use: "No balance or no activity yet", sheet: SAD, mood: "idle" as const },
  { title: "Idle", use: "Search and insight blank states", sheet: IDLE_STEADY, mood: "idle" as const },
  { title: "Guide", use: "Quiet companion in empty history", sheet: FLYING_IDLE, mood: "wave" as const },
  { title: "Refuse", use: "Amount is over what the card holds", sheet: NO_NO_NO, mood: "idle" as const },
];

const FLOW = [
  { title: "Welcome", shot: "/shots/home.webp", alt: "Pesolita wallet home screen" },
  { title: "Choose Card", shot: "/shots/templates.webp", alt: "Pesolita card template picker" },
  { title: "Log Spend", shot: "/shots/guard.webp", alt: "Pesolita spend protection screen" },
  { title: "Celebrate", shot: "/shots/logged.webp", alt: "Pesolita logged spend success screen" },
];

export default function BrandPage() {
  return (
    <main className={styles.page}>
      <nav className={styles.nav}>
        <Link href="/about" className={styles.brand} aria-label="Pesolita about">
          <BrandWordmark size="small" tone="onDark" />
        </Link>
        <div className={styles.navLinks}>
          <Link href="/" className={styles.navLink}>
            App
          </Link>
          <Link href="/about" className={styles.navLink}>
            About
          </Link>
        </div>
      </nav>

      <header className={styles.hero}>
        <div className={styles.heroCopy}>
          <p className={styles.kicker}>Brand system</p>
          <BrandWordmark size="large" tone="onDark" className={styles.heroWordmark} />
          <h1 className={styles.heroTitle}>Every peso gets a home.</h1>
          <p className={styles.heroBody}>
            Pesolita is friendly manual money software: private by default, Philippines-aware,
            and guided by Kuya Ipis without turning the wallet into a toy.
          </p>
        </div>
        <div className={styles.heroArt} aria-hidden="true">
          <Image
            src="/pesolita-promo-square.png"
            alt=""
            width={1254}
            height={1254}
            sizes="(max-width: 780px) 86vw, 420px"
            priority
            className={styles.promo}
          />
        </div>
      </header>

      <section className={styles.band} aria-labelledby="identity-title">
        <div className={styles.sectionHead}>
          <p className={styles.kicker}>Identity</p>
          <h2 id="identity-title" className={styles.h2}>
            A wordmark built for the wallet chrome.
          </h2>
        </div>
        <div className={styles.identityGrid}>
          <div className={styles.specimen}>
            <BrandWordmark size="large" tone="onLight" />
            <p>
              The word splits at “Peso” so the money cue is instant, then resolves into the
              softer “lita” ending. The coin dot over the i echoes the mascot speech bubble.
            </p>
          </div>
          <div className={styles.iconCard}>
            <Image src="/icon.png" alt="Pesolita app icon" width={512} height={512} className={styles.appIcon} />
            <div>
              <h3>App icon</h3>
              <p>Use the full painted icon for stores, splash states and large promotional surfaces.</p>
            </div>
          </div>
          <div className={styles.iconCard}>
            <Image src="/brand-mark.png" alt="Pesolita small brand mark" width={96} height={96} className={styles.mark} />
            <div>
              <h3>Small mark</h3>
              <p>Use the cropped mark in rails, compact headers and places where the full icon loses detail.</p>
            </div>
          </div>
        </div>
      </section>

      <section className={styles.section} aria-labelledby="palette-title">
        <div className={styles.sectionHead}>
          <p className={styles.kicker}>Palette</p>
          <h2 id="palette-title" className={styles.h2}>
            Dark wallet, bright peso.
          </h2>
        </div>
        <div className={styles.palette}>
          {COLORS.map((color) => (
            <div key={color.hex} className={styles.swatch}>
              <div className={styles.swatchColor} style={{ background: color.hex }} />
              <div className={styles.swatchText}>
                <strong>{color.name}</strong>
                <span>{color.hex}</span>
                <p>{color.role}</p>
              </div>
            </div>
          ))}
        </div>
      </section>

      <section className={styles.band} aria-labelledby="mascot-title">
        <div className={styles.sectionHead}>
          <p className={styles.kicker}>Mascot system</p>
          <h2 id="mascot-title" className={styles.h2}>
            Kuya Ipis reacts to money moments.
          </h2>
        </div>
        <div className={styles.mascotGrid}>
          {MASCOTS.map((item) => (
            <article key={item.title} className={styles.mascotCard}>
              <div className={styles.mascotStage}>
                <SpriteAnimation
                  sheet={item.sheet}
                  size={118}
                  fallback={<Mascot mood={item.mood} size={96} />}
                  loop
                />
              </div>
              <h3>{item.title}</h3>
              <p>{item.use}</p>
            </article>
          ))}
        </div>
      </section>

      <section className={styles.section} aria-labelledby="type-title">
        <div className={styles.sectionHead}>
          <p className={styles.kicker}>Typography and voice</p>
          <h2 id="type-title" className={styles.h2}>
            Round, direct, never bank-form stiff.
          </h2>
        </div>
        <div className={styles.typeGrid}>
          <div className={styles.typeSpec}>
            <div className={styles.bigAa}>Aa</div>
            <h3>Outfit</h3>
            <p>Use bold weights for money and short decisions. Use regular weights for calm explanations.</p>
            <div className={styles.alphabet}>Aa Bb Cc Dd Ee Ff Gg Hh Ii Jj Kk Ll Mm 1234567890 ₱</div>
          </div>
          <div className={styles.personality}>
            {PERSONALITY.map((trait) => (
              <span key={trait}>{trait}</span>
            ))}
          </div>
        </div>
      </section>

      <section className={styles.band} aria-labelledby="flow-title">
        <div className={styles.sectionHead}>
          <p className={styles.kicker}>Experience flow</p>
          <h2 id="flow-title" className={styles.h2}>
            The mascot shows up when emotion changes.
          </h2>
        </div>
        <div className={styles.flow}>
          {FLOW.map((item) => (
            <figure key={item.title} className={styles.flowItem}>
              <Image
                src={item.shot}
                alt={item.alt}
                width={620}
                height={1347}
                sizes="(max-width: 720px) 58vw, 190px"
                className={styles.flowShot}
              />
              <figcaption>{item.title}</figcaption>
            </figure>
          ))}
        </div>
      </section>
    </main>
  );
}
