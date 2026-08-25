"use client";

import { useLayoutEffect, useRef, type ChangeEvent } from "react";

import { amountDisplay, moneyInput } from "@/lib/format";

/**
 * Drives a plain `<input>` for a peso amount with live thousands separators, without the
 * caret jumping to the end on every keystroke.
 *
 * A comma-formatted controlled input is a caret trap: React sets `value` to the fully
 * re-formatted string on every render, and the browser resets the caret to match unless told
 * otherwise. This counts how many non-comma characters sat to the left of the caret right
 * after the keystroke, reformats, then places the caret after that same count of non-comma
 * characters in the new string — so typing "5" in the middle of "12,000" leaves the cursor
 * right after the "5" instead of bouncing to the end.
 *
 * `raw` is the source of truth — a plain digit string, the same contract `moneyInput` and
 * `amountDisplay` already use everywhere else in the app. This only ever formats it for
 * display and hands the cleaned raw string back through `onRawChange`; it never owns state
 * itself, so callers that need a "revert to canonical value on blur" behaviour (the money
 * fields in the card editor) are still free to add their own `onBlur`.
 */
export function useMoneyField(raw: string, onRawChange: (raw: string) => void) {
  const ref = useRef<HTMLInputElement>(null);
  const pendingCaret = useRef<number | null>(null);
  // amountDisplay("") deliberately returns "0" for its original caller — a read-only span
  // in the keypad, where showing a resting "0" is the point. A real `<input>` already has
  // its own `placeholder` for that job, and inheriting the same "0" here would type-ahead a
  // phantom leading zero into every fresh field: the first keystroke lands after it rather
  // than replacing it, so typing "500" silently became "0500".
  const display = raw ? amountDisplay(raw) : "";

  // Runs after the DOM has the new formatted value but before the browser paints, so the
  // caret never visibly jumps to the end first.
  useLayoutEffect(() => {
    if (pendingCaret.current === null || !ref.current) return;
    ref.current.setSelectionRange(pendingCaret.current, pendingCaret.current);
    pendingCaret.current = null;
  }, [display]);

  const onChange = (e: ChangeEvent<HTMLInputElement>) => {
    const input = e.target;
    // The event's own value/selectionStart already reflect the post-keystroke state,
    // whether this was an insert, a delete, or a selected range typed over.
    const caret = input.selectionStart ?? input.value.length;
    const before = countMeaningful(input.value.slice(0, caret));

    const cleaned = moneyInput(input.value);
    pendingCaret.current = caretAtCount(amountDisplay(cleaned), before);
    onRawChange(cleaned);
  };

  return { ref, display, onChange };
}

function countMeaningful(s: string): number {
  let n = 0;
  for (const ch of s) if (ch !== ",") n++;
  return n;
}

function caretAtCount(s: string, count: number): number {
  if (count <= 0) return 0;
  let seen = 0;
  for (let i = 0; i < s.length; i++) {
    if (s[i] === ",") continue;
    seen++;
    if (seen >= count) return i + 1;
  }
  return s.length;
}
