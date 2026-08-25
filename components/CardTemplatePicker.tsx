"use client";

import Image from "next/image";
import { useRef, useState, type CSSProperties, type KeyboardEvent, type PointerEvent } from "react";

import {
  CARD_TEMPLATES,
  TEMPLATE_CATEGORIES,
  type CardTemplate,
  type TemplateCategory,
  type TemplateGroup,
} from "@/lib/cardTemplates";

import styles from "./CardTemplatePicker.module.css";

type CardTransform = CSSProperties & {
  "--card-x": string;
  "--card-x-wide": string;
  "--card-y": string;
  "--card-z": string;
  "--card-z-wide": string;
  "--card-turn": string;
  "--card-turn-wide": string;
  "--card-roll": string;
  "--card-scale": number;
  "--drag-x": string;
};

interface CardTemplatePickerProps {
  activeTemplateId: string | null;
  className?: string;
  fixedCategory?: TemplateGroup;
  onSelect: (template: CardTemplate) => void;
}

const categoryCounts = new Map(
  TEMPLATE_CATEGORIES.map(({ id }) => [
    id,
    id === "all" ? CARD_TEMPLATES.length : CARD_TEMPLATES.filter((template) => template.category === id).length,
  ]),
);

function templatesFor(category: TemplateCategory): readonly CardTemplate[] {
  return category === "all" ? CARD_TEMPLATES : CARD_TEMPLATES.filter((template) => template.category === category);
}

function categoryLabel(category: CardTemplate["category"]): string {
  return TEMPLATE_CATEGORIES.find(({ id }) => id === category)?.label ?? category;
}

export function CardTemplatePicker({ activeTemplateId, className, fixedCategory, onSelect }: CardTemplatePickerProps) {
  const activeTemplate = CARD_TEMPLATES.find(({ id }) => id === activeTemplateId) ?? null;
  const initialCategory = fixedCategory ?? activeTemplate?.category ?? "all";
  const [category, setCategory] = useState<TemplateCategory>(initialCategory);
  const initialTemplates = templatesFor(initialCategory);
  const [focusedIndex, setFocusedIndex] = useState(() =>
    Math.max(0, initialTemplates.findIndex(({ id }) => id === activeTemplateId)),
  );
  const [dragX, setDragX] = useState(0);
  const gesture = useRef<{ pointerId: number; startX: number; currentX: number; moved: boolean } | null>(null);
  const suppressClick = useRef(false);

  const visibleCategory = fixedCategory ?? category;
  const visibleTemplates = templatesFor(visibleCategory);
  const safeIndex = Math.min(focusedIndex, Math.max(0, visibleTemplates.length - 1));
  const focusedTemplate = visibleTemplates[safeIndex];

  const focusAt = (index: number, source = visibleTemplates) => {
    if (!source.length) return;
    const nextIndex = Math.max(0, Math.min(source.length - 1, index));
    setFocusedIndex(nextIndex);
    setDragX(0);
    onSelect(source[nextIndex]);
  };

  const chooseCategory = (nextCategory: TemplateCategory) => {
    const nextTemplates = templatesFor(nextCategory);
    const selectedIndex = nextTemplates.findIndex(({ id }) => id === activeTemplateId);
    const nextIndex = selectedIndex >= 0 ? selectedIndex : 0;
    setCategory(nextCategory);
    focusAt(nextIndex, nextTemplates);
  };

  const onPointerDown = (event: PointerEvent<HTMLDivElement>) => {
    event.currentTarget.setPointerCapture(event.pointerId);
    gesture.current = {
      pointerId: event.pointerId,
      startX: event.clientX,
      currentX: event.clientX,
      moved: false,
    };
  };

  const onPointerMove = (event: PointerEvent<HTMLDivElement>) => {
    const current = gesture.current;
    if (!current || current.pointerId !== event.pointerId) return;
    current.currentX = event.clientX;
    const delta = event.clientX - current.startX;
    if (Math.abs(delta) > 5) current.moved = true;
    setDragX(Math.max(-88, Math.min(88, delta)));
  };

  const finishGesture = (event: PointerEvent<HTMLDivElement>) => {
    const current = gesture.current;
    if (!current || current.pointerId !== event.pointerId) return;
    const delta = current.currentX - current.startX;
    suppressClick.current = current.moved;
    gesture.current = null;
    if (Math.abs(delta) >= 42) focusAt(safeIndex + (delta < 0 ? 1 : -1));
    else setDragX(0);
    window.requestAnimationFrame(() => {
      suppressClick.current = false;
    });
  };

  const onKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    if (event.key === "ArrowLeft") {
      event.preventDefault();
      focusAt(safeIndex - 1);
    } else if (event.key === "ArrowRight") {
      event.preventDefault();
      focusAt(safeIndex + 1);
    } else if (event.key === "Home") {
      event.preventDefault();
      focusAt(0);
    } else if (event.key === "End") {
      event.preventDefault();
      focusAt(visibleTemplates.length - 1);
    }
  };

  return (
    <section className={`${styles.picker} ${className ?? ""}`} aria-label="Card background templates">
      {fixedCategory ? null : (
        <div className={styles.categoryBar} aria-label="Template categories">
          {TEMPLATE_CATEGORIES.map(({ id, label }) => (
            <button
              key={id}
              type="button"
              className={styles.categoryChip}
              aria-pressed={category === id}
              onClick={() => chooseCategory(id)}
            >
              <span>{label}</span>
              <span className={styles.categoryCount}>{categoryCounts.get(id)}</span>
            </button>
          ))}
        </div>
      )}

      <div
        className={`${styles.stage} ${dragX ? styles.dragging : ""}`}
        role="group"
        aria-roledescription="carousel"
        aria-label={`${visibleCategory === "all" ? "All" : categoryLabel(visibleCategory as CardTemplate["category"])} templates`}
        tabIndex={0}
        onKeyDown={onKeyDown}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={finishGesture}
        onPointerCancel={finishGesture}
      >
        <div className={styles.ambient} aria-hidden="true" />
        {visibleTemplates.map((template, index) => {
          const slot = index - safeIndex;
          if (Math.abs(slot) > 2) return null;
          const distance = Math.abs(slot);
          const transform: CardTransform = {
            "--card-x": `${slot * 60}%`,
            "--card-x-wide": `${slot * 72}%`,
            "--card-y": `${distance * 9}px`,
            "--card-z": `${distance * -54}px`,
            "--card-z-wide": `${distance * -86}px`,
            "--card-turn": `${slot * -11}deg`,
            "--card-turn-wide": `${slot * -18}deg`,
            "--card-roll": `${slot * 1.8}deg`,
            "--card-scale": 1 - distance * 0.08,
            "--drag-x": `${dragX}px`,
            zIndex: 10 - distance,
            opacity: distance === 2 ? 0.58 : 1,
          };

          return (
            <button
              key={template.id}
              type="button"
              className={styles.templateCard}
              style={transform}
              aria-label={`Choose ${template.name}`}
              aria-pressed={template.id === activeTemplateId}
              onClick={() => {
                if (!suppressClick.current) focusAt(index);
              }}
            >
              <Image
                src={template.src}
                alt=""
                fill
                sizes="(max-width: 619px) 72vw, (max-width: 1000px) 42vw, 320px"
                loading={distance <= 1 ? "eager" : "lazy"}
              />
              <span className={styles.cardSheen} aria-hidden="true" />
              {template.id === activeTemplateId ? (
                <span className={styles.selectedMark} aria-label="Selected">
                  <svg width={13} height={13} viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round">
                    <path d="m3 8 3.2 3.2L13 4.8" />
                  </svg>
                </span>
              ) : null}
            </button>
          );
        })}
      </div>

      {focusedTemplate ? (
        <div className={styles.templateMeta} aria-live="polite">
          <div>
            <div className={styles.templateName}>{focusedTemplate.name}</div>
            <div className={styles.templateCategory}>{categoryLabel(focusedTemplate.category)}</div>
          </div>
          <div className={styles.position}>
            {safeIndex + 1} <span>/ {visibleTemplates.length}</span>
          </div>
        </div>
      ) : null}

      <p className={styles.hint}>Swipe, tap a card, or use the arrow keys.</p>
    </section>
  );
}
