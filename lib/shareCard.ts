import { peso, peso0 } from "@/lib/format";
import type { EventShare, EventTotals } from "@/lib/selectors";
import { APP_STORE_URL } from "@/lib/constants";
import type { EventGroup } from "@/lib/types";

/**
 * Sharing, in an app that makes no network calls.
 *
 * The group never installs anything and no invite link exists: the summary is rendered on
 * the device and handed to the OS share sheet, which is where the conversation about money
 * already happens. That is the whole multiplayer story, and it is deliberate — an invite
 * flow would mean accounts, a server, and walking back the promise the store listing makes.
 */

export interface EventSummary {
  event: EventGroup;
  totals: EventTotals;
  shares: readonly EventShare[];
}

/** The plain-text version — what actually gets pasted into a group chat. */
export function eventSummaryText({ event, totals, shares }: EventSummary): string {
  const lines = [
    `${event.emoji} ${event.name}`,
    `Total: ₱${peso(totals.total)} across ${totals.count === 1 ? "1 spend" : `${totals.count} spends`}`,
    "",
    ...shares.map((s) => {
      const owed = s.owed > 0 ? ` (₱${peso(s.owed)} still to send)` : "";
      return `${s.name}: ₱${peso(s.amount)}${owed}`;
    }),
  ];
  if (totals.owed > 0) {
    lines.push("", `Still out: ₱${peso(totals.owed)}`);
  }
  // The summary lands in a group chat where most readers do not have the app. The link is
  // the only thing in the message that is for them rather than about the money.
  lines.push("", "Split it yourself with Pesolita — free, and nothing leaves your phone:", APP_STORE_URL);
  return lines.join("\n");
}

const CARD_W = 1000;
const PAD = 64;

/**
 * The summary as a picture, painted in the app's own colours so it is recognisable in a
 * chat thread. Canvas rather than SVG because the output is a raster share target anyway,
 * and because a font that fails to load silently would otherwise ruin the layout.
 */
export function renderEventCard(summary: EventSummary): Promise<Blob | null> {
  const { event, totals, shares } = summary;
  const rows = shares.slice(0, 8);
  const height = 300 + rows.length * 78 + (totals.owed > 0 ? 96 : 0) + PAD + 16;

  const canvas = document.createElement("canvas");
  canvas.width = CARD_W;
  canvas.height = height;
  const ctx = canvas.getContext("2d");
  if (!ctx) return Promise.resolve(null);

  const font = (size: number, weight = 600) =>
    `${weight} ${size}px Outfit, ui-sans-serif, system-ui, sans-serif`;

  ctx.fillStyle = "#0b0b0c";
  ctx.fillRect(0, 0, CARD_W, height);

  // A single warm shape behind the header, echoing the card art engine's blob styles.
  ctx.fillStyle = "rgba(255, 202, 40, .14)";
  ctx.beginPath();
  ctx.ellipse(CARD_W - 60, 40, 260, 180, 0, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = "#ffca28";
  ctx.font = font(26, 700);
  ctx.fillText(`${event.emoji}  ${event.name.toUpperCase()}`, PAD, PAD + 34);

  ctx.fillStyle = "#ffffff";
  ctx.font = font(78, 700);
  ctx.fillText(`₱${peso0(totals.total)}`, PAD, PAD + 126);

  ctx.fillStyle = "#a9a9ae";
  ctx.font = font(24, 500);
  ctx.fillText(
    `${totals.count === 1 ? "1 spend" : `${totals.count} spends`} · ₱${peso0(totals.mine)} was mine`,
    PAD,
    PAD + 168,
  );

  let y = 300;
  const max = Math.max(1, ...rows.map((r) => r.amount));

  for (const share of rows) {
    ctx.fillStyle = "#ffffff";
    ctx.font = font(28, 600);
    ctx.fillText(share.name, PAD, y);

    const value = `₱${peso0(share.amount)}`;
    ctx.font = font(28, 700);
    const w = ctx.measureText(value).width;
    ctx.fillText(value, CARD_W - PAD - w, y);

    if (share.owed > 0) {
      ctx.fillStyle = "#ffca28";
      ctx.font = font(20, 500);
      const owed = `₱${peso0(share.owed)} to send`;
      const ow = ctx.measureText(owed).width;
      ctx.fillText(owed, CARD_W - PAD - ow, y + 28);
    }

    ctx.fillStyle = "#22222a";
    roundRect(ctx, PAD, y + 16, CARD_W - PAD * 2, 10, 5);
    ctx.fill();

    ctx.fillStyle = share.color === "#0b0b0c" ? "#ffca28" : share.color;
    roundRect(ctx, PAD, y + 16, Math.max(10, ((CARD_W - PAD * 2) * share.amount) / max), 10, 5);
    ctx.fill();

    y += 78;
  }

  if (totals.owed > 0) {
    ctx.fillStyle = "#ffca28";
    roundRect(ctx, PAD, y + 8, CARD_W - PAD * 2, 64, 20);
    ctx.fill();
    ctx.fillStyle = "#0b0b0c";
    ctx.font = font(26, 700);
    ctx.fillText(`₱${peso0(totals.owed)} still out with the group`, PAD + 26, y + 48);
    y += 96;
  }

  // The picture travels further than the text does — someone screenshots it, someone
  // forwards it — so the footer names the app rather than just signing the card.
  ctx.fillStyle = "#6d6d72";
  ctx.font = font(20, 500);
  ctx.fillText("Split it yourself — Pesolita on the App Store", PAD, height - 28);

  return new Promise((resolve) => canvas.toBlob(resolve, "image/png"));
}

function roundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

export type ShareOutcome = "shared" | "copied" | "failed";

/**
 * Tries the picture, then the text, then the clipboard. Every step is local — the share
 * sheet is the OS's, and the app never uploads anything.
 */
export async function shareEvent(summary: EventSummary): Promise<ShareOutcome> {
  const text = eventSummaryText(summary);
  const title = `${summary.event.name} — what it cost`;

  if (typeof navigator !== "undefined" && "share" in navigator) {
    try {
      const blob = await renderEventCard(summary);
      const file = blob ? new File([blob], "pesolita-split.png", { type: "image/png" }) : null;
      if (file && navigator.canShare?.({ files: [file] })) {
        await navigator.share({ title, text, files: [file] });
        return "shared";
      }
      await navigator.share({ title, text });
      return "shared";
    } catch (err) {
      // A cancelled share throws the same way a failed one does, so fall through quietly
      // rather than reporting a problem the user caused on purpose.
      if (err instanceof DOMException && err.name === "AbortError") return "shared";
    }
  }

  try {
    await navigator.clipboard.writeText(text);
    return "copied";
  } catch {
    return "failed";
  }
}
