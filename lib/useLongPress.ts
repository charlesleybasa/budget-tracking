"use client";

import { useCallback, useEffect, useRef } from "react";
import type { MouseEvent as ReactMouseEvent, PointerEvent as ReactPointerEvent } from "react";

/** How long a press must be held before it counts as a long press. */
const HOLD_MS = 450;
/** Movement past this cancels — the gesture was a scroll or a drag, not a press. */
const SLOP_PX = 10;
/** How long after a hold fires its trailing click is still considered part of that gesture. */
const CLICK_SUPPRESS_MS = 700;

/**
 * Fires `onLongPress` when a pointer is held still on the element.
 *
 * The two things that make this fiddly on a phone, both handled here:
 *
 * 1. A long press on an image opens the OS "save image" sheet, which would land on top of
 *    whatever the gesture was meant to do. `contextmenu` is cancelled, and the CSS side sets
 *    `-webkit-touch-callout: none` to stop Safari's variant of the same thing.
 * 2. A press that turns into a scroll must not fire. Movement past a slop threshold cancels,
 *    so dragging the card away never triggers the code.
 *
 * Returns props to spread onto the target. Pair it with an `onClick` — a long press is a
 * shortcut, never the only way in.
 */
export function useLongPress(onLongPress: () => void) {
  const timer = useRef<number | null>(null);
  const origin = useRef({ x: 0, y: 0 });
  /**
   * When the hold last fired, so the trailing click it produces can be swallowed.
   *
   * A timestamp rather than a boolean: the trailing click does not always arrive — opening an
   * overlay can take the pointer away first — and a sticky boolean would then eat the *next*
   * click instead. That next click is often a keyboard Enter, which emits no pointerdown to
   * reset the flag, so the control would go dead for keyboard users.
   */
  const firedAt = useRef(0);

  const clear = useCallback(() => {
    if (timer.current !== null) {
      window.clearTimeout(timer.current);
      timer.current = null;
    }
  }, []);

  useEffect(() => clear, [clear]);

  return {
    onPointerDown: (e: ReactPointerEvent) => {
      // Secondary buttons open the real context menu; leave them alone.
      if (e.pointerType === "mouse" && e.button !== 0) return;
      firedAt.current = 0;
      origin.current = { x: e.clientX, y: e.clientY };
      clear();
      timer.current = window.setTimeout(() => {
        firedAt.current = Date.now();
        timer.current = null;
        onLongPress();
      }, HOLD_MS);
    },

    onPointerMove: (e: ReactPointerEvent) => {
      if (timer.current === null) return;
      const dx = e.clientX - origin.current.x;
      const dy = e.clientY - origin.current.y;
      if (Math.hypot(dx, dy) > SLOP_PX) clear();
    },

    onPointerUp: clear,
    onPointerLeave: clear,
    onPointerCancel: () => {
      clear();
      firedAt.current = 0;
    },

    onContextMenu: (e: ReactMouseEvent) => e.preventDefault(),

    // A completed hold still emits a click afterwards; drop that one so the handler does not
    // run twice.
    onClickCapture: (e: ReactMouseEvent) => {
      if (Date.now() - firedAt.current > CLICK_SUPPRESS_MS) return;
      firedAt.current = 0;
      e.preventDefault();
      e.stopPropagation();
    },
  };
}
