"use client";

import { useRef, useState, type ChangeEvent, type PointerEvent as ReactPointerEvent } from "react";

import { CardArt } from "@/components/CardArt";
import { CardTemplatePicker } from "@/components/CardTemplatePicker";
import { cardTheme } from "@/components/cardTheme";
import {
  CARD_TEMPLATES,
  DEFAULT_CARD_TEMPLATE,
  templateForSource,
  templateToArt,
  type CardTemplate,
} from "@/lib/cardTemplates";
import { CARD_STYLES, PALETTES, SCRIM_NAMES, SCRIM_ORDER, TEXTURES, TIERS } from "@/lib/constants";
import { minusIfNegative, peso } from "@/lib/format";
import { ImageError, QR_OPTIONS, readImage } from "@/lib/image";
import { autoTuneScrim, measure } from "@/lib/legibility";
import { useWallet } from "@/lib/store";
import { useElementWidth } from "@/lib/useElementWidth";
import { useMoneyField } from "@/lib/useMoneyField";
import type { CardArt as CardArtModel, PhotoArt, Sample, TextMode } from "@/lib/types";

import styles from "./CardEditor.module.css";

const TEXT_MODES: ReadonlyArray<readonly [TextMode, string]> = [
  ["auto", "Auto"],
  ["light", "Light"],
  ["dark", "Dark"],
];

const MAX_PHOTO_BYTES = 10 * 1024 * 1024;

type EditorMode = "templates" | "diy";

const DIY_DEFAULT_ART: CardArtModel = {
  style: "blob",
  c1: "#ffca28",
  c2: "#0b0b0c",
  tex: "grain",
  layout: "standard",
  photo: null,
};

function copyArt(art: CardArtModel): CardArtModel {
  return { ...art, photo: art.photo ? { ...art.photo, sample: [...art.photo.sample] } : null };
}

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
  const qrRef = useRef<HTMLInputElement>(null);
  const wrapWidth = useElementWidth(wrapRef);
  // Money fields keep their own text so a half-typed "100." survives the keystroke.
  const [balText, setBalText] = useState<string | null>(null);
  const [limitText, setLimitText] = useState<string | null>(null);

  const ed = state.ed;

  // A genuine 0 renders as an untouched, empty field rather than a literal "0" the user
  // would have to delete before typing — same reasoning as the onboarding amount field.
  // `ed?.bal ? ... : ""` rather than `?? ""` on purpose: 0 is falsy, and 0 is exactly the
  // value that should read as empty here.
  const balField = useMoneyField(balText ?? (ed?.bal ? String(ed.bal) : ""), (text) => {
    setBalText(text);
    actions.editCard({ bal: parseFloat(text) || 0 });
  });
  const limitField = useMoneyField(limitText ?? (ed?.limit ? String(ed.limit) : ""), (text) => {
    setLimitText(text);
    actions.editCard({ limit: parseFloat(text) || 0 });
  });

  const initialTemplate = templateForSource(ed?.art.photo?.src);
  const [mode, setMode] = useState<EditorMode>(() => (initialTemplate ? "templates" : "diy"));
  const [templateDraft, setTemplateDraft] = useState<CardArtModel>(() =>
    copyArt(initialTemplate && ed ? ed.art : templateToArt(DEFAULT_CARD_TEMPLATE, ed?.art)),
  );
  const [diyDraft, setDiyDraft] = useState<CardArtModel>(() =>
    copyArt(initialTemplate ? DIY_DEFAULT_ART : (ed?.art ?? DIY_DEFAULT_ART)),
  );

  if (!ed) return null;

  const previewW = Math.min(320, Math.max(240, (wrapWidth ?? 360) - 40));
  const previewH = Math.round(previewW * (196 / 320));

  const art = ed.art;
  const theme = cardTheme(art);
  const photo = art.photo ?? null;
  const hasPhoto = art.style === "photo" && !!photo?.src;
  const metrics = photo?.src ? measure(photo) : null;
  const activeTemplate = templateForSource(photo?.src);

  const selectTemplate = (template: CardTemplate) => {
    const next = templateToArt(template, art);
    setTemplateDraft(copyArt(next));
    actions.editArt(next);
    actions.editCard({ nick: template.name });
  };

  const switchMode = (nextMode: EditorMode) => {
    if (nextMode === mode) return;
    if (mode === "templates") setTemplateDraft(copyArt(art));
    else setDiyDraft(copyArt(art));

    const nextArt = nextMode === "templates" ? templateDraft : diyDraft;
    actions.editArt(copyArt(nextArt));
    if (nextMode === "templates") {
      const restoredTemplate = templateForSource(nextArt.photo?.src);
      if (restoredTemplate) actions.editCard({ nick: restoredTemplate.name });
    }
    setMode(nextMode);
  };

  const randomize = () => {
    if (mode === "diy") {
      actions.randomizeArt();
      return;
    }
    const currentIndex = activeTemplate ? CARD_TEMPLATES.findIndex(({ id }) => id === activeTemplate.id) : -1;
    const offset = 1 + Math.floor(Math.random() * Math.max(1, CARD_TEMPLATES.length - 1));
    selectTemplate(CARD_TEMPLATES[(Math.max(0, currentIndex) + offset) % CARD_TEMPLATES.length]);
  };

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

  const onQrFile = (e: ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    readImage(file, QR_OPTIONS)
      .then((qr) => {
        actions.editCard({ qr });
        actions.toast("QR added to the back of this card.");
      })
      .catch((err: unknown) => {
        actions.toast(err instanceof ImageError ? err.message : "Could not read that image.");
      });
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
        <button type="button" className={styles.roundBtn} onClick={randomize} aria-label="Try another design">
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
          <div className={styles.modeSwitch} role="group" aria-label="Card design source">
            <button
              type="button"
              className={styles.modeButton}
              aria-pressed={mode === "templates"}
              onClick={() => switchMode("templates")}
            >
              Templates
              <span>70 ready-made looks</span>
            </button>
            <button
              type="button"
              className={styles.modeButton}
              aria-pressed={mode === "diy"}
              onClick={() => switchMode("diy")}
            >
              DIY
              <span>Build your own</span>
            </button>
          </div>

          {mode === "templates" ? (
            <section className={styles.designSection} aria-labelledby="template-heading">
              <div className={styles.sectionHead}>
                <div>
                  <div id="template-heading" className={styles.sectionTitle}>Choose a background</div>
                  <div className={styles.sectionCopy}>Browse by category, then tune the crop and readability.</div>
                </div>
                <div className={styles.sectionBadge}>3D preview</div>
              </div>
              <CardTemplatePicker activeTemplateId={activeTemplate?.id ?? null} onSelect={selectTemplate} />
            </section>
          ) : (
            <section className={styles.designSection} aria-labelledby="artwork-heading">
              <div className={styles.sectionHead}>
                <div>
                  <div id="artwork-heading" className={styles.sectionTitle}>Artwork</div>
                  <div className={styles.sectionCopy}>Pick a generated pattern or start with your own photo.</div>
                </div>
              </div>
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
                      if (style === "photo" && !photo?.src) window.setTimeout(() => fileRef.current?.click(), 120);
                    }}
                  >
                    <div className={styles.thumbSmall} style={{ background: art.c1 }}>
                      <CardArt art={{ ...art, style, chip: false }} w={100} h={52} r={0} />
                    </div>
                    <div className={styles.tileCaption}>{name}</div>
                  </button>
                ))}
              </div>
            </section>
          )}

          <input ref={fileRef} type="file" accept="image/*" onChange={onFile} style={{ display: "none" }} />

          {art.style === "photo" ? (
            <section className={styles.photoPanel} aria-label={mode === "templates" ? "Adjust template" : "Photo controls"}>
              <div className={styles.photoHead}>
                <div className={styles.photoTitle}>{mode === "templates" ? "Adjust template" : "Your photo"}</div>
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
                    ? "The balance is clear against this artwork."
                    : "The balance gets lost here. Increase the overlay or soften the image."}
              </p>

              <div className={styles.photoActions}>
                {mode === "diy" ? (
                  <button type="button" className={styles.uploadBtn} onClick={() => fileRef.current?.click()}>
                    <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={2.2} strokeLinecap="round">
                      <path d="M12 16V4M7 9l5-5 5 5M4 20h16" />
                    </svg>
                    {hasPhoto ? "Replace photo" : "Upload a photo"}
                  </button>
                ) : null}

                {hasPhoto ? (
                  <>
                    <button
                      type="button"
                      className={`${styles.autoFix} ${mode === "templates" ? styles.autoFixWide : ""}`}
                      onClick={() => {
                        if (!photo) return;
                        actions.editPhoto({ scrim: autoTuneScrim(photo) });
                        actions.toast("Tuned to the lightest overlay that still passes.");
                      }}
                    >
                      Auto-fix contrast
                    </button>
                    {mode === "diy" ? (
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
                    ) : null}
                  </>
                ) : null}
              </div>

              {hasPhoto && photo ? (
                <div className={styles.photoControls}>
                  <div className={styles.controlHead}>
                    <div className={styles.controlLabel}>Zoom · drag the card above to reframe</div>
                    <button
                      type="button"
                      className={styles.recentre}
                      onClick={() =>
                        actions.editPhoto({
                          px: activeTemplate?.focal[0] ?? 0,
                          py: activeTemplate?.focal[1] ?? 0,
                          zoom: 1,
                        })
                      }
                    >
                      Reset crop
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
                    aria-label="Image zoom"
                  />

                  <div className={styles.controlLabel} style={{ marginTop: 10 }}>
                    Readability overlay
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
                {mode === "templates"
                  ? "The background stays intact. Switch to DIY if you want to replace the artwork."
                  : "840px or wider, under 10MB. A calm bottom-left corner keeps the balance easy to read."}
              </p>
            </section>
          ) : null}

          {mode === "diy" ? (
            <section className={styles.designSection} aria-labelledby="finish-heading">
              <div className={styles.sectionHead}>
                <div>
                  <div id="finish-heading" className={styles.sectionTitle}>Colors &amp; finish</div>
                  <div className={styles.sectionCopy}>Set the palette, then add as much texture as you want.</div>
                </div>
              </div>
              <div className={styles.label}>Colour</div>
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

              <div className={`${styles.label} ${styles.spacedCompact}`}>Finish</div>
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
            </section>
          ) : null}

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

          {/* ── how people pay you: this is what the back of the card shows ── */}
          <div className={`${styles.labelRow} ${styles.spaced}`}>
            <div className={styles.label} style={{ whiteSpace: "nowrap" }}>
              Receiving details
            </div>
            <div className={styles.labelHint}>Shown on the back of the card</div>
          </div>

          <input ref={qrRef} type="file" accept="image/*" onChange={onQrFile} style={{ display: "none" }} />

          <div className={styles.receiving}>
            <div className={styles.field}>
              <label className={styles.fieldLabel} htmlFor="ed-account">
                Account number
              </label>
              <input
                id="ed-account"
                className={styles.fieldInput}
                value={ed.accountNumber ?? ""}
                onChange={(e) => actions.editCard({ accountNumber: e.target.value })}
                placeholder="e.g. 0917 123 4567"
                inputMode="numeric"
                autoComplete="off"
              />
            </div>

            <div className={styles.qrRow}>
              {ed.qr ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img className={styles.qrThumb} src={ed.qr} alt="Your receiving QR" />
              ) : (
                <div className={styles.qrEmpty} aria-hidden="true">
                  <svg width={20} height={20} viewBox="0 0 24 24" fill="none" stroke="#a9a9ae" strokeWidth={2}>
                    <rect x={3} y={3} width={7} height={7} rx={1.5} />
                    <rect x={14} y={3} width={7} height={7} rx={1.5} />
                    <rect x={3} y={14} width={7} height={7} rx={1.5} />
                    <path d="M14 14h3v3h-3zM19 19h2M19 14h2v2" strokeLinecap="round" />
                  </svg>
                </div>
              )}

              <div className={styles.qrMeta}>
                <div className={styles.qrTitle}>{ed.qr ? "QR attached" : "Receiving QR"}</div>
                <div className={styles.qrSub}>
                  {ed.qr ? "Flip the card to show it" : "Add the QR people scan to pay you"}
                </div>
              </div>

              <button type="button" className={styles.qrBtn} onClick={() => qrRef.current?.click()}>
                {ed.qr ? "Replace" : "Add"}
              </button>

              {ed.qr ? (
                <button
                  type="button"
                  className={styles.qrRemove}
                  onClick={() => actions.editCard({ qr: undefined })}
                  aria-label="Remove QR"
                >
                  <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="#c62f26" strokeWidth={2.2} strokeLinecap="round">
                    <path d="M18 6L6 18M6 6l12 12" />
                  </svg>
                </button>
              ) : null}
            </div>
          </div>

          {/* ── fields ── */}
          <div className={`${styles.labelRow} ${styles.spaced}`}>
            <div className={styles.label}>Card information</div>
            <div className={styles.labelHint}>Shown in your wallet</div>
          </div>
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
                  ref={balField.ref}
                  className={styles.fieldInput}
                  inputMode="decimal"
                  value={balField.display}
                  onChange={balField.onChange}
                  onBlur={() => setBalText(null)}
                  placeholder="0.00"
                />
              </div>

              <div className={styles.field}>
                <label className={styles.fieldLabel} htmlFor="ed-limit">
                  Monthly limit
                </label>
                <input
                  id="ed-limit"
                  ref={limitField.ref}
                  className={styles.fieldInput}
                  inputMode="decimal"
                  value={limitField.display}
                  onChange={limitField.onChange}
                  onBlur={() => setLimitText(null)}
                  placeholder="No limit set"
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
            <button
              type="button"
              className={styles.delete}
              onClick={() => actions.patch({ cardDeleteOpen: true })}
            >
              Delete this card
            </button>
          )}
        </div>
      </div>
    </section>
  );
}
