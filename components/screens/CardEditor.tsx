"use client";

import { useRef, useState, type ChangeEvent, type PointerEvent as ReactPointerEvent } from "react";

import { CardArt } from "@/components/CardArt";
import { cardTheme } from "@/components/cardTheme";
import { BANK_PRESETS } from "@/lib/bankPresets";
import { CARD_STYLES, PALETTES, SCRIM_NAMES, SCRIM_ORDER, TEXTURES, TIERS } from "@/lib/constants";
import { minusIfNegative, moneyInput, peso } from "@/lib/format";
import { autoTuneScrim, measure } from "@/lib/legibility";
import { useWallet } from "@/lib/store";
import { useElementWidth } from "@/lib/useElementWidth";
import type { PhotoArt, Sample, TextMode } from "@/lib/types";

import styles from "./CardEditor.module.css";

const TEXT_MODES: ReadonlyArray<readonly [TextMode, string]> = [
  ["auto", "Auto"],
  ["light", "Light"],
  ["dark", "Dark"],
];

const MAX_PHOTO_BYTES = 10 * 1024 * 1024;

/**
 * Average the zone the balance actually sits in — bottom-left — rather than the whole frame,
 * so the tuner protects the text that is at risk instead of the picture's overall mood.
 */
function samplePhoto(img: HTMLImageElement): Sample {
  const canvas = document.createElement("canvas");
  canvas.width = 64;
  canvas.height = 40;
  const ctx = canvas.getContext("2d");
  if (!ctx) return [128, 128, 128];
  ctx.drawImage(img, 0, 0, 64, 40);
  try {
    const { data } = ctx.getImageData(0, 18, 46, 22);
    let r = 0;
    let g = 0;
    let b = 0;
    let n = 0;
    for (let i = 0; i < data.length; i += 4) {
      r += data[i];
      g += data[i + 1];
      b += data[i + 2];
      n += 1;
    }
    return n ? [r / n, g / n, b / n] : [128, 128, 128];
  } catch {
    // A tainted canvas cannot be read; fall back to a neutral mid-grey.
    return [128, 128, 128];
  }
}

export function CardEditor() {
  const { state, actions } = useWallet();
  const fileRef = useRef<HTMLInputElement>(null);
  const dragRef = useRef<{ x: number; y: number; px: number; py: number } | null>(null);
  const wrapRef = useRef<HTMLDivElement>(null);
  const wrapWidth = useElementWidth(wrapRef);
  // Money fields keep their own text so a half-typed "100." survives the keystroke.
  const [balText, setBalText] = useState<string | null>(null);
  const [limitText, setLimitText] = useState<string | null>(null);

  const ed = state.ed;
  if (!ed) return null;

  const previewW = Math.min(320, Math.max(240, (wrapWidth ?? 360) - 40));
  const previewH = Math.round(previewW * (196 / 320));

  const art = ed.art;
  const theme = cardTheme(art);
  const photo = art.photo ?? null;
  const hasPhoto = art.style === "photo" && !!photo?.src;
  const metrics = photo?.src ? measure(photo) : null;

  const onFile = (e: ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    if (!file.type.startsWith("image/")) {
      actions.toast("That's not an image.");
      return;
    }
    if (file.size > MAX_PHOTO_BYTES) {
      actions.toast("Under 10MB please — that one is huge.");
      return;
    }

    const reader = new FileReader();
    reader.onload = () => {
      const src = String(reader.result);
      const img = new Image();
      img.onload = () => {
        if (img.naturalWidth < 400) actions.toast("A bit low-res — 840px or wider looks best.");
        const sample = samplePhoto(img);
        const next: PhotoArt = {
          src,
          zoom: 1,
          px: 0,
          py: 0,
          scrim: "soft",
          blur: false,
          textMode: "auto",
          sample,
        };
        next.scrim = autoTuneScrim(next);
        actions.attachPhoto(next);
        actions.toast(`Scrim set to ${SCRIM_NAMES[next.scrim].toLowerCase()} so the balance stays readable.`);
      };
      img.src = src;
    };
    reader.readAsDataURL(file);
  };

  const onPointerDown = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (!photo?.src) return;
    dragRef.current = { x: e.clientX, y: e.clientY, px: photo.px, py: photo.py };
  };

  const onPointerMove = (e: ReactPointerEvent<HTMLDivElement>) => {
    const start = dragRef.current;
    if (!start || !photo?.src) return;
    const limit = Math.max(0, (photo.zoom - 1) * 50) + 8;
    actions.editPhoto({
      px: Math.max(-limit, Math.min(limit, start.px + (e.clientX - start.x) / 3.2)),
      py: Math.max(-limit, Math.min(limit, start.py + (e.clientY - start.y) / 2)),
    });
  };

  const endDrag = () => {
    dragRef.current = null;
  };

  const activeStyle = (isActive: boolean) => ({
    background: isActive ? "#0b0b0c" : "#f5f4f0",
    color: isActive ? "#fff" : "#0b0b0c",
  });

  return (
    <section
      className={`${styles.screen} bwEnterUp`}
      aria-label={state.edNew ? "New card" : "Redesign card"}
    >
      <div className={styles.topInset} />

      <div className={styles.nav}>
        <button type="button" className={styles.roundBtn} onClick={() => actions.go("home")} aria-label="Close editor">
          <svg width={16} height={16} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={2.6} strokeLinecap="round">
            <path d="M18 6L6 18M6 6l12 12" />
          </svg>
        </button>
        <div className={styles.navTitle}>{state.edNew ? "New card" : "Redesign card"}</div>
        <button type="button" className={styles.roundBtn} onClick={actions.randomizeArt} aria-label="Randomise the art">
          <svg width={16} height={16} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={2.2} strokeLinecap="round">
            <path d="M20 5h-5M20 5l-3-3M20 5l-3 3M4 19h5M4 19l3-3M4 19l3 3M4 5l16 14" />
          </svg>
        </button>
      </div>

      <div className={styles.previewWrap} ref={wrapRef}>
        <div
          className={`${styles.preview} ${hasPhoto ? styles.previewDraggable : ""}`}
          style={{ width: previewW, height: previewH, background: art.c1 }}
          onPointerDown={onPointerDown}
          onPointerMove={onPointerMove}
          onPointerUp={endDrag}
          onPointerLeave={endDrag}
        >
          <CardArt art={{ ...art, glyph: (ed.nick || "?").trim().charAt(0).toUpperCase() }} w={previewW} h={previewH} />
          <div className={styles.previewInner}>
            <div className={styles.previewKind} style={{ color: theme.fgDim }}>
              {ed.kind}
            </div>
            <div>
              <div className={styles.previewBalance} style={{ color: theme.fg }}>
                <span className={styles.previewPeso}>{minusIfNegative(ed.bal)}₱</span>
                <span className={styles.previewValue}>{peso(ed.bal || 0)}</span>
              </div>
              <div className={styles.previewNick} style={{ color: theme.fg }}>
                {ed.nick || "Untitled card"}
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className={styles.sheet}>
        <div className={styles.scroll}>
          {/* ── start from the bank you actually carry ── */}
          <div className={styles.labelRow}>
            <div className={styles.label} style={{ whiteSpace: "nowrap" }}>
              Start from
            </div>
            <div className={styles.labelHint}>Colours only — edit anything after</div>
          </div>
          <div className={styles.bankRow}>
            {BANK_PRESETS.map((preset) => (
              <button
                key={preset.name}
                type="button"
                className={styles.bankChip}
                onClick={() => {
                  actions.editArt({ c1: preset.c1, c2: preset.c2, style: preset.style, chip: preset.chip, photo: null });
                  if (!ed.nick.trim()) actions.editCard({ nick: preset.name });
                }}
              >
                <span className={styles.bankSwatch} aria-hidden="true">
                  <span style={{ background: preset.c1 }} />
                  <span style={{ background: preset.c2 }} />
                </span>
                {preset.name}
              </button>
            ))}
          </div>

          {/* ── style: pattern only, so picking a look never changes the colours ── */}
          <div className={styles.spaced} />
          <div className={styles.label}>Style</div>
          <div className={styles.grid3}>
            {CARD_STYLES.map(([style, name]) => (
              <button
                key={style}
                type="button"
                className={styles.tile}
                aria-pressed={art.style === style}
                style={{ borderColor: art.style === style ? "#0b0b0c" : "transparent" }}
                onClick={() => {
                  actions.editArt({ style });
                  if (style === "photo" && !photo?.src) {
                    window.setTimeout(() => fileRef.current?.click(), 120);
                  }
                }}
              >
                <div className={styles.thumbSmall} style={{ background: art.c1 }}>
                  <CardArt art={{ ...art, style, chip: false }} w={100} h={52} r={0} />
                </div>
                <div className={styles.tileCaption}>{name}</div>
              </button>
            ))}
          </div>

          <input ref={fileRef} type="file" accept="image/*" onChange={onFile} style={{ display: "none" }} />

          {/* ── photo panel ── */}
          {art.style === "photo" ? (
            <div className={styles.photoPanel}>
              <div className={styles.photoHead}>
                <div className={styles.photoTitle}>Your photo</div>
                <div
                  className={styles.ratio}
                  style={{
                    background: !metrics ? "#f5f4f0" : metrics.ratio >= 4.5 ? "#e7f6ee" : "#fdeceb",
                    color: !metrics ? "#8a8a8f" : metrics.ratio >= 4.5 ? "#0b8f6a" : "#c62f26",
                  }}
                >
                  {metrics ? `${metrics.ratio.toFixed(1)}:1` : "—"} <span className={styles.ratioAa}>AA</span>
                </div>
              </div>

              <p className={styles.photoCopy}>
                {!metrics
                  ? "Upload a photo and I check the balance against it."
                  : metrics.ratio >= 4.5
                    ? "Balance is readable over this photo. Ship it."
                    : "The balance gets lost here. Add scrim, blur it, or pick a calmer photo."}
              </p>

              <div className={styles.photoActions}>
                <button type="button" className={styles.uploadBtn} onClick={() => fileRef.current?.click()}>
                  <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={2.2} strokeLinecap="round">
                    <path d="M12 16V4M7 9l5-5 5 5M4 20h16" />
                  </svg>
                  {hasPhoto ? "Replace photo" : "Upload a photo"}
                </button>

                {hasPhoto ? (
                  <>
                    <button
                      type="button"
                      className={styles.autoFix}
                      onClick={() => {
                        if (!photo) return;
                        actions.editPhoto({ scrim: autoTuneScrim(photo) });
                        actions.toast("Tuned to the lightest scrim that still passes.");
                      }}
                    >
                      Auto-fix
                    </button>
                    <button
                      type="button"
                      className={styles.dropPhoto}
                      onClick={() => actions.editArt({ photo: null })}
                      aria-label="Remove photo"
                    >
                      <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="#c62f26" strokeWidth={2.2} strokeLinecap="round">
                        <path d="M4 7h16M9 7V5h6v2M6 7l1 13h10l1-13" />
                      </svg>
                    </button>
                  </>
                ) : null}
              </div>

              {hasPhoto && photo ? (
                <div className={styles.photoControls}>
                  <div className={styles.controlHead}>
                    <div className={styles.controlLabel}>Zoom · drag the card to reframe</div>
                    <button
                      type="button"
                      className={styles.recentre}
                      onClick={() => actions.editPhoto({ px: 0, py: 0, zoom: 1 })}
                    >
                      Recentre
                    </button>
                  </div>
                  <input
                    className={styles.zoom}
                    type="range"
                    min={1}
                    max={2.6}
                    step={0.02}
                    value={photo.zoom}
                    onChange={(e) => actions.editPhoto({ zoom: parseFloat(e.target.value) })}
                    aria-label="Photo zoom"
                  />

                  <div className={styles.controlLabel} style={{ marginTop: 10 }}>
                    Scrim behind the numbers
                  </div>
                  <div className={styles.segRow}>
                    {SCRIM_ORDER.map((key) => (
                      <button
                        key={key}
                        type="button"
                        className={styles.seg}
                        style={activeStyle(photo.scrim === key)}
                        onClick={() => actions.editPhoto({ scrim: key })}
                      >
                        {SCRIM_NAMES[key]}
                      </button>
                    ))}
                  </div>

                  <div className={styles.splitRow}>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div className={styles.controlLabel}>Text</div>
                      <div className={styles.segRow}>
                        {TEXT_MODES.map(([key, name]) => (
                          <button
                            key={key}
                            type="button"
                            className={styles.seg}
                            style={activeStyle(photo.textMode === key)}
                            onClick={() => actions.editPhoto({ textMode: key })}
                          >
                            {name}
                          </button>
                        ))}
                      </div>
                    </div>

                    <div style={{ flex: "none", width: 96 }}>
                      <div className={styles.controlLabel}>Soften</div>
                      <button
                        type="button"
                        className={styles.seg}
                        style={{ ...activeStyle(photo.blur), marginTop: 8, width: "100%" }}
                        onClick={() => actions.editPhoto({ blur: !photo.blur })}
                        aria-pressed={photo.blur}
                      >
                        Blur
                      </button>
                    </div>
                  </div>
                </div>
              ) : null}

              <p className={styles.photoNote}>
                840px or wider, under 10MB. Photos with a calm bottom-left corner work best — that&apos;s where your
                balance lives. Don&apos;t upload a picture that already has text in it.
              </p>
            </div>
          ) : null}

          {/* ── palette ── */}
          <div className={`${styles.label} ${styles.spaced}`}>Colour</div>
          <div className={styles.swatches}>
            {PALETTES.map(([c1, c2]) => (
              <button
                key={`${c1}${c2}`}
                type="button"
                className={styles.swatch}
                style={{ borderColor: art.c1 === c1 && art.c2 === c2 ? "#0b0b0c" : "transparent" }}
                onClick={() => actions.editArt({ c1, c2 })}
                aria-label={`Palette ${c1} and ${c2}`}
              >
                <span className={styles.swatchHalf} style={{ background: c1 }} />
                <span className={styles.swatchHalf} style={{ background: c2 }} />
              </button>
            ))}
          </div>

          {/* ── texture ── */}
          <div className={`${styles.label} ${styles.spaced}`}>Finish</div>
          <div className={styles.optionRow}>
            {TEXTURES.map((tex) => (
              <button
                key={tex}
                type="button"
                className={styles.option}
                style={activeStyle(art.tex === tex)}
                onClick={() => actions.editArt({ tex })}
              >
                {tex === "none" ? "Flat" : tex.charAt(0).toUpperCase() + tex.slice(1)}
              </button>
            ))}
          </div>

          {/* ── details ── */}
          <div className={`${styles.label} ${styles.spaced}`}>Details</div>

          <button
            type="button"
            className={styles.chipToggle}
            style={activeStyle(!!art.chip)}
            onClick={() => actions.editArt({ chip: !art.chip })}
            aria-pressed={!!art.chip}
          >
            <svg
              width={16}
              height={16}
              viewBox="0 0 24 24"
              fill="none"
              stroke={art.chip ? "#fff" : "#0b0b0c"}
              strokeWidth={2.1}
              strokeLinecap="round"
            >
              <rect x={4} y={7} width={10} height={8} rx={2} />
              <path d="M4 11h10M17 8.5a5 5 0 010 7M20 6a8 8 0 010 12" />
            </svg>
            {art.chip ? "Chip and tap mark shown" : "Show chip and tap mark"}
          </button>

          {art.style === "metal" ? (
            <div className={styles.pillRow}>
              {TIERS.map((tier) => (
                <button
                  key={tier}
                  type="button"
                  className={styles.pill}
                  style={activeStyle(art.tier === tier)}
                  onClick={() => actions.editArt({ tier: art.tier === tier ? null : tier })}
                  aria-pressed={art.tier === tier}
                >
                  {tier.charAt(0) + tier.slice(1).toLowerCase()}
                </button>
              ))}
            </div>
          ) : null}

          {/* ── fields ── */}
          <div className={styles.fields}>
            <div className={styles.field}>
              <label className={styles.fieldLabel} htmlFor="ed-nick">
                Nickname
              </label>
              <input
                id="ed-nick"
                className={styles.fieldInput}
                value={ed.nick}
                onChange={(e) => actions.editCard({ nick: e.target.value })}
                placeholder="Give it a name"
              />
            </div>

            <div className={styles.fieldPair}>
              <div className={styles.field}>
                <label className={styles.fieldLabel} htmlFor="ed-bal">
                  Balance
                </label>
                <input
                  id="ed-bal"
                  className={styles.fieldInput}
                  inputMode="decimal"
                  value={balText ?? String(ed.bal)}
                  onChange={(e) => {
                    const text = moneyInput(e.target.value);
                    setBalText(text);
                    actions.editCard({ bal: parseFloat(text) || 0 });
                  }}
                  onBlur={() => setBalText(null)}
                />
              </div>

              <div className={styles.field}>
                <label className={styles.fieldLabel} htmlFor="ed-limit">
                  Monthly limit
                </label>
                <input
                  id="ed-limit"
                  className={styles.fieldInput}
                  inputMode="decimal"
                  value={limitText ?? String(ed.limit)}
                  onChange={(e) => {
                    const text = moneyInput(e.target.value);
                    setLimitText(text);
                    actions.editCard({ limit: parseFloat(text) || 0 });
                  }}
                  onBlur={() => setLimitText(null)}
                />
              </div>
            </div>
          </div>

          <button type="button" className={styles.save} onClick={actions.saveCard}>
            {state.edNew ? "Add to my deck" : "Save changes"}
          </button>

          {/* Deleting the last card is allowed — the wallet has a real empty state, and a
              mistyped first card should not be permanent. */}
          {state.edNew ? null : (
            <button type="button" className={styles.delete} onClick={actions.deleteCard}>
              Delete this card
            </button>
          )}
        </div>
      </div>
    </section>
  );
}
