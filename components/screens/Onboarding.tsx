"use client";

import { useEffect, useRef, type CSSProperties } from "react";
import { flushSync } from "react-dom";

import { CardArt } from "@/components/CardArt";
import { CardTemplatePicker } from "@/components/CardTemplatePicker";
import { MascotMark } from "@/components/MascotMark";
import { Mascot } from "@/components/Mascot";
import { SpriteAnimation, preloadSprite } from "@/components/SpriteAnimation";
import { cardTheme } from "@/components/cardTheme";
import {
  CARD_TEMPLATES,
  templateForSource,
  templateToArt,
  type CardTemplate,
  type TemplateGroup,
} from "@/lib/cardTemplates";
import { CARD_KINDS, PALETTES } from "@/lib/constants";
import { peso } from "@/lib/format";
import { PEEKABOO } from "@/lib/sprites";
import { useWallet } from "@/lib/store";
import { useElementWidth } from "@/lib/useElementWidth";
import { useMoneyField } from "@/lib/useMoneyField";
import { useRestore } from "@/lib/useRestore";
import type { ArtStyle, CardArt as CardArtModel, CardKind } from "@/lib/types";

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

const CASH_ART: CardArtModel = {
  style: "blob",
  c1: "#ffca28",
  c2: "#0b0b0c",
  tex: "grain",
  layout: "standard",
  chip: false,
  photo: null,
};

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

  // Step 0 is a full screen of reading before the sprite appears on step 1, which is exactly
  // the window to spend on fetching its atlas.
  useEffect(() => {
    preloadSprite(PEEKABOO);
  }, []);

  const previewRef = useRef<HTMLDivElement>(null);
  const previewWrapWidth = useElementWidth(previewRef);
  const previewW = Math.min(268, Math.max(220, (previewWrapWidth ?? 320) - 8));
  const previewH = Math.round(previewW * (164 / 268));

  const next = () => actions.patch({ obStep: Math.min(4, obStep + 1) });

  const balField = useMoneyField(state.obBal, (raw) => actions.patch({ obBal: raw }));

  const selectedKind = CARD_KINDS.find(([kind]) => kind === state.obKind);
  const selectedKindLabel = selectedKind?.[1] ?? state.obKind ?? "Your card";
  const selectedCategory = selectedKind?.[3] ?? null;
  const activeTemplate = templateForSource(state.obArt.photo?.src);
  const previewTheme = cardTheme(state.obArt);

  const openFunding = (patch: { obKind?: CardKind; obName?: string; obArt?: CardArtModel } = {}) => {
    // Keep the focus in the category/template tap's user-gesture call stack so iOS raises
    // the amount keyboard as soon as the funding step appears.
    flushSync(() => actions.patch({ ...patch, obStep: 4 }));
    balField.ref.current?.focus();
  };

  const selectKind = (kind: CardKind, category: TemplateGroup | null) => {
    if (category === null) {
      openFunding({ obKind: kind, obName: "Cash on Hand", obArt: { ...CASH_ART } });
      return;
    }

    const firstTemplate = CARD_TEMPLATES.find((template) => template.category === category);
    if (!firstTemplate) return;
    actions.patch({
      obKind: kind,
      obName: firstTemplate.name,
      obArt: templateToArt(firstTemplate, state.obArt),
      obStep: 3,
    });
  };

  const selectTemplate = (template: CardTemplate) => {
    actions.patch({
      obName: template.name,
      obArt: templateToArt(template, state.obArt),
    });
  };

  const firstName = state.userName.trim().split(" ")[0];

  return (
    <section
      className={`${styles.screen} bwEnterUp`}
      aria-label="Onboarding"
    >
      <input {...restore.inputProps} />

      <div style={{ height: "var(--screen-top)", flex: "none" }} />

      {/* No escape hatch here on purpose: the wallet is unusable without a first card, so
          onboarding runs to the end. Restoring a backup on step 0 is the one way past it,
          and that is a returning user rather than a skip. */}
      <div className={styles.topBar}>
        <div className={styles.brand}>
          <div className={styles.brandMark}>
            <MascotMark />
          </div>
          <div className={styles.brandName}>Pesolita</div>
        </div>
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
          <SpriteAnimation
            sheet={PEEKABOO}
            size={150}
            className={styles.mascot}
            fallback={<Mascot mood="wave" size={104} />}
            loop={false}
            replayDelayMs={3000}
          />
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
        <div key={obStep} className={`${styles.step} ${styles.stepPadded} ${styles.kindStep} bwEnterSide`}>
          <h1 className={styles.head}>
            What kind of
            <br />
            pocket is it?
          </h1>
          <p className={styles.sub}>You can add the rest later. No judgement if it&apos;s all cash.</p>

          <div className={styles.kindGrid}>
            {CARD_KINDS.map(([kind, label, hint, category]) => (
              <button
                key={kind}
                type="button"
                className={styles.kind}
                onClick={() => selectKind(kind, category)}
                style={{ background: "#141418", borderColor: "transparent" }}
              >
                <div className={styles.kindDot} style={{ background: "rgba(255,255,255,.1)" }}>
                  <KindIcon active={false} />
                </div>
                <div className={styles.kindLabel}>{label}</div>
                <div className={styles.kindHint}>{hint}</div>
              </button>
            ))}
          </div>

          <div className={styles.spacer} />
        </div>
      ) : null}

      {obStep === 3 && selectedCategory ? (
        <div key={obStep} className={`${styles.step} ${styles.stepPaddedTight} ${styles.templateStep} bwEnterSide`}>
          <div className={styles.stepHeadRow}>
            <div>
              <h1 className={styles.headTight}>Choose your card.</h1>
              <p className={styles.sub}>Pick a look from this category. You can fine-tune it later.</p>
            </div>
            <button type="button" className={styles.changeLink} onClick={() => actions.patch({ obStep: 2 })}>
              Change category
            </button>
          </div>

          <div className={styles.templatePanel}>
            <CardTemplatePicker
              activeTemplateId={activeTemplate?.id ?? null}
              className={styles.onboardingPicker}
              fixedCategory={selectedCategory}
              onSelect={selectTemplate}
            />
          </div>

          <div className={styles.spacer} />
          <button
            type="button"
            className={styles.continueBtn}
            style={{ background: "#ffca28" }}
            onClick={() => openFunding()}
          >
            Use this template
          </button>
        </div>
      ) : null}

      {obStep === 4 || (obStep === 3 && !selectedCategory) ? (
        <div key={obStep} className={`${styles.step} ${styles.stepPaddedTight} bwEnterSide`}>
          <div className={styles.stepHeadRow}>
            <h1 className={styles.headTight}>Name it, fund it.</h1>
            <button
              type="button"
              className={styles.changeLink}
              onClick={() => actions.patch({ obStep: selectedCategory ? 3 : 2 })}
            >
              {selectedCategory ? "Change template" : "Change category"}
            </button>
          </div>

          <div className={styles.previewWrap} ref={previewRef}>
            <div className={styles.preview} style={{ width: previewW, height: previewH }}>
              <CardArt
                art={{ ...state.obArt, glyph: (state.obName || "?").charAt(0).toUpperCase() }}
                w={previewW}
                h={previewH}
                r={20}
              />
              <div className={styles.previewInner}>
                <div className={styles.previewKind} style={{ color: previewTheme.fgDim }}>
                  {selectedKindLabel}
                </div>
                <div>
                  <div className={styles.previewAmount} style={{ color: previewTheme.fg }}>
                    <span className={styles.previewPeso}>₱</span>
                    <span className={styles.previewValue}>{peso(parseFloat(state.obBal) || 0)}</span>
                  </div>
                  <div className={styles.previewNick} style={{ color: previewTheme.fg }}>
                    {state.obName || "Untitled card"}
                  </div>
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
                  ref={balField.ref}
                  className={styles.amountInput}
                  inputMode="decimal"
                  value={balField.display}
                  onChange={balField.onChange}
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
        {[0, 1, 2, 3, 4].map((i) => (
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
