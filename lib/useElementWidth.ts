"use client";

import { useEffect, useState, type RefObject } from "react";

/**
 * Live content width of an element, in px. The card artwork scales every dimension off its
 * rendered width, so it needs a real measurement rather than a fixed constant once the app
 * stretches to whatever the device gives it.
 */
export function useElementWidth(ref: RefObject<HTMLElement | null>): number | null {
  const [width, setWidth] = useState<number | null>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    const observer = new ResizeObserver((entries) => {
      const next = entries[0]?.contentRect.width;
      if (next) setWidth(Math.round(next));
    });
    observer.observe(el);
    setWidth(Math.round(el.getBoundingClientRect().width));

    return () => observer.disconnect();
  }, [ref]);

  return width;
}
