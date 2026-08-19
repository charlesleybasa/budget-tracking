/** Peso amount with two decimals, always positive — the sign is carried by the label. */
export function peso(n: number): string {
  return (Math.round(Math.abs(n) * 100) / 100).toLocaleString("en-PH", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

/** Peso amount rounded to whole pesos, for headlines and bar labels. */
export function peso0(n: number): string {
  return Math.round(Math.abs(n)).toLocaleString("en-PH");
}

/** Signed amount as it appears in a transaction row. */
export function signedPeso(n: number): string {
  return `${n > 0 ? "+₱" : "−₱"}${peso(n)}`;
}

/** Whole calendar days between an instant and today. */
export function daysAgo(at: number, now: number = Date.now()): number {
  if (!Number.isFinite(at)) return 0;
  const a = new Date(at);
  const b = new Date(now);
  a.setHours(0, 0, 0, 0);
  b.setHours(0, 0, 0, 0);
  return Math.round((b.getTime() - a.getTime()) / 864e5);
}

export function dayLabel(at: number, now: number = Date.now()): string {
  if (!Number.isFinite(at)) return "Undated";
  const offset = daysAgo(at, now);
  if (offset === 0) return "Today";
  if (offset === 1) return "Yesterday";
  return new Date(at).toLocaleDateString("en-PH", {
    weekday: "long",
    day: "numeric",
    month: "short",
  });
}

/** Minus sign for a negative amount. The peso mark follows it: −₱150.00 */
export function minusIfNegative(n: number): string {
  return n < 0 ? "−" : "";
}

/** Days remaining in the current calendar month, counting today. */
export function daysLeftInMonth(now: Date = new Date()): number {
  const total = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
  return total - now.getDate() + 1;
}

export function monthName(now: Date = new Date()): string {
  return now.toLocaleDateString("en-PH", { month: "long" });
}

export function greetingFor(now: Date = new Date()): string {
  const h = now.getHours();
  if (h < 12) return "Good morning";
  if (h < 18) return "Good afternoon";
  return "Good evening";
}

/** First letter of a merchant name, for the transaction row avatar. */
export function merchantInitial(merchant: string): string {
  return merchant.replace(/[^A-Za-z]/g, "").slice(0, 1).toUpperCase() || "₱";
}

/** Strip anything that is not a number or a decimal point. */
export function numericInput(value: string): string {
  return value.replace(/[^0-9.]/g, "");
}

/**
 * Money as typed: digits, at most one decimal point, at most two decimals. Returned as text
 * so a trailing "." survives until the next keystroke.
 */
export function moneyInput(value: string): string {
  const cleaned = value.replace(/[^0-9.]/g, "");
  const [whole, ...rest] = cleaned.split(".");
  if (rest.length === 0) return whole.slice(0, 9);
  return `${whole.slice(0, 9)}.${rest.join("").slice(0, 2)}`;
}
