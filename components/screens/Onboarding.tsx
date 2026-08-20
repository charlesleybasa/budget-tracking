"use client";

import { useRef, type CSSProperties } from "react";

import { CardArt } from "@/components/CardArt";
import { MascotMark } from "@/components/MascotMark";
import { CARD_KINDS, PALETTES } from "@/lib/constants";
import { Mascot } from "@/components/Mascot";
import { moneyInput, peso } from "@/lib/format";
import { useWallet } from "@/lib/store";
import type { ArtStyle } from "@/lib/types";
import { useRestore } from "@/lib/useRestore";
import { useElementWidth } from "@/lib/useElementWidth";

import styles from "./Onboarding.module.css";

/**
 * The opening fan, back to front: [x-offset, rotation, style, palette].
 *
 * These are named outright rather than indexed into the editor's style gallery. Indexing
 * coupled the first thing a new user sees to the order of an unrelated list — reordering that
 * gallery silently swapped the hero card from the crisp Grid to a soft Mesh wash.
 */
const FAN: ReadonlyArray<readonly [number, number, ArtStyle, number]> = [
  [-30, -13, "blob", 4],
  [-15, -6.5, "wave", 5],
  [0, 0, "arc", 0],
  [15, 6.5, "grid", 1],
];

function FanStack() {
  return (
    <div className={styles.fan}>
      {FAN.map(([x, rot, style, paletteIndex], i) => {
        const palette = PALETTES[paletteIndex];
        return (
          <div
            key={i}
            className={styles.fanCard}
            style={
              {
                top: 52 + i * 6,
                zIndex: i,
                "--bwT": `translate(${x}px,${i * -4}px) rotate(${rot}deg)`,
                animationDelay: `${(i * 0.11 + 0.15).toFixed(2)}s`,
              } as CSSProperties
            }
          >
            <CardArt
              art={{
                style,
                c1: palette[0],
                c2: palette[1],
                tex: i % 2 ? "grain" : "none",
                layout: "standard",
              }}
              w={232}
              h={142}
              r={18}
            />
          </div>
        );
      })}
    </div>
  );
}

function KindIcon({ active }: { active: boolean }) {
  return (
    <svg
      width={15}
      height={15}
      viewBox="0 0 24 24"
      fill="none"
      stroke={active ? "#0b0b0c" : "rgba(255,255,255,.75)"}
      strokeWidth={2.2}
      strokeLinecap="round"
    >
      <rect x={2.5} y={5.5} width={19} height={13} rx={3} />
      <path d="M2.5 10h19" />
    </svg>
  );
}

export function Onboarding() {
  const { state, actions } = useWallet();
  const { obStep } = state;
  const restore = useRestore();

  const previewRef = useRef<HTMLDivElement>(null);
  const previewWrapWidth = useElementWidth(previewRef);
  const previewW = Math.min(268, Math.max(220, (previewWrapWidth ?? 320) - 8));
  const previewH = Math.round(previewW * (164 / 268));

  const next = () => actions.patch({ obStep: Math.min(3, obStep + 1) });
  const skip = () => {
    actions.patch({ onboarded: true });
    actions.go("home");
  };

  const firstName = state.userName.trim().split(" ")[0];

  return (
    <section
      className={`${styles.screen} bwEnterUp`}
      aria-label="Onboarding"
    >
      <input {...restore.inputProps} />

      <div style={{ height: "var(--screen-top)", flex: "none" }} />

      <div className={styles.topBar}>
        <div className={styles.brand}>
          <div className={styles.brandMark}>
            <MascotMark />
          </div>
          <div className={styles.brandName}>Pesolita</div>
        </div>
        <button type="button" className={styles.skip} onClick={skip}>
          Skip
        </button>
      </div>

      {obStep === 0 ? (
        <div className={styles.step}>
          <div className={styles.fanArea}>
            <FanStack />
          </div>
          <div className={styles.intro}>
            <h1 className={styles.introHead}>
              Every peso
              <br />
              gets a home.
            </h1>
            <p className={styles.introBody}>
              Make a card for each pocket of your money — bank, e-wallet, the cash in your actual wallet. You type it in,
              nothing snoops your bank.
            </p>
            <button type="button" className={styles.cta} onClick={next}>
              Let&apos;s make your first card
              <svg width={17} height={17} viewBox="0 0 24 24" fill="none" stroke="#0b0b0c" strokeWidth={2.6} strokeLinecap="round">
                <path d="M5 12h13M12 6l6 6-6 6" />
              </svg>
            </button>

            {/* A returning user on a wiped device has no Settings to reach for. */}
            <button type="button" className={styles.restoreLink} onClick={restore.open}>
              Been here before? Restore a backup
            </button>
          </div>
        </div>
      ) : null}

      {obStep === 1 ? (
        <div key={obStep} className={`${styles.step} ${styles.stepPadded} bwEnterSide`}>
          <Mascot mood="wave" size={104} className={styles.mascot} />
          <h1 className={styles.head}>
            First — what
            <br />
            should I call you?
          </h1>
          <p className={styles.sub}>Just a first name is fine. It stays on this phone with everything else.</p>

          <div className={styles.nameField}>
            <label className={styles.darkFieldLabel} htmlFor="ob-name">
              Your name
            </label>
            <input
              id="ob-name"
              className={styles.nameInput}
              value={state.userName}
              onChange={(e) => actions.patch({ userName: e.target.value })}
              placeholder="Your name"
              autoComplete="given-name"
              onKeyDown={(e) => {
                if (e.key === "Enter" && state.userName.trim()) next();
              }}
            />
          </div>

          <div className={styles.greeting}>{firstName ? `Hi, ${firstName}.` : "Nice to meet you."}</div>
          <div className={styles.spacer} />
          <button
            type="button"
            className={styles.continueBtn}
            onClick={next}
            style={{ background: state.userName.trim() ? "#ffca28" : "rgba(255,255,255,.16)" }}
          >
            Continue
          </button>
        </div>
      ) : null}

      {obStep === 2 ? (
        <div key={obStep} className={`${styles.step} ${styles.stepPadded} bwEnterSide`}>
          <h1 className={styles.head}>
            What kind of
            <br />
            pocket is it?
          </h1>
          <p className={styles.sub}>You can add the rest later. No judgement if it&apos;s all cash.</p>

          <div className={styles.kindGrid}>
            {CARD_KINDS.map(([label, hint]) => {
              const active = state.obKind === label;
              return (
                <button
                  key={label}
                  type="button"
                  className={styles.kind}
                  onClick={() =>
                    actions.patch({ obKind: label, obName: label === "Cash on hand" ? "Cash on Hand" : "" })
                  }
                  style={{
                    background: active ? "rgba(255,202,40,.14)" : "#141418",
                    borderColor: active ? "#ffca28" : "transparent",
                  }}
                  aria-pressed={active}
                >
                  <div className={styles.kindDot} style={{ background: active ? "#ffca28" : "rgba(255,255,255,.1)" }}>
                    <KindIcon active={active} />
                  </div>
                  <div className={styles.kindLabel}>{label}</div>
                  <div className={styles.kindHint}>{hint}</div>
                </button>
              );
            })}
          </div>

          <div className={styles.spacer} />
          <button
            type="button"
            className={styles.continueBtn}
            onClick={next}
            style={{ background: state.obKind ? "#ffca28" : "rgba(255,255,255,.16)" }}
          >
            Continue
          </button>
        </div>
      ) : null}

      {obStep === 3 ? (
        <div key={obStep} className={`${styles.step} ${styles.stepPaddedTight} bwEnterSide`}>
          <h1 className={styles.headTight}>Name it, fund it.</h1>

          <div className={styles.previewWrap} ref={previewRef}>
            <div className={styles.preview} style={{ width: previewW, height: previewH }}>
              <CardArt
                art={{ ...state.obArt, glyph: (state.obName || "?").charAt(0).toUpperCase() }}
                w={previewW}
                h={previewH}
                r={20}
              />
              <div className={styles.previewInner}>
                <div className={styles.previewKind}>{state.obKind ?? "Your card"}</div>
                <div>
                  <div className={styles.previewAmount}>
                    <span className={styles.previewPeso}>₱</span>
                    <span className={styles.previewValue}>{peso(parseFloat(state.obBal) || 0)}</span>
                  </div>
                  <div className={styles.previewNick}>{state.obName || "Untitled card"}</div>
                </div>
              </div>
            </div>
          </div>

          <div className={styles.fields}>
            <div className={styles.nameField} style={{ marginTop: 0, borderRadius: 16, padding: "12px 15px" }}>
              <label className={styles.darkFieldLabel} htmlFor="ob-nick">
                Nickname
              </label>
              <input
                id="ob-nick"
                className={styles.nameInput}
                style={{ font: "600 17px/1.2 inherit", letterSpacing: 0, marginTop: 5 }}
                value={state.obName}
                onChange={(e) => actions.patch({ obName: e.target.value })}
                placeholder="Give it a name"
              />
            </div>

            <div className={styles.nameField} style={{ marginTop: 0, borderRadius: 16, padding: "12px 15px" }}>
              <label className={styles.darkFieldLabel} htmlFor="ob-bal">
                What&apos;s in it right now
              </label>
              <div className={styles.amountRow}>
                <span className={styles.amountPeso}>₱</span>
                <input
                  id="ob-bal"
                  className={styles.amountInput}
                  inputMode="decimal"
                  value={state.obBal}
                  onChange={(e) => actions.patch({ obBal: moneyInput(e.target.value) })}
                  placeholder="0.00"
                  onKeyDown={(e) => {
                    if (e.key === "Enter") actions.finishOnboarding();
                  }}
                />
              </div>
            </div>
          </div>

          <div className={styles.spacer} />
          <button
            type="button"
            className={styles.continueBtn}
            style={{ background: "#ffca28" }}
            onClick={actions.finishOnboarding}
          >
            Create card
          </button>
          <p className={styles.footnote}>You can redesign the card any time.</p>
        </div>
      ) : null}

      <div className={styles.dots}>
        {[0, 1, 2, 3].map((i) => (
          <div
            key={i}
            className={styles.dot}
            style={{
              width: i === obStep ? 22 : 4,
              background: i === obStep ? "#ffca28" : "rgba(255,255,255,.22)",
            }}
          />
        ))}
      </div>
    </section>
  );
}
