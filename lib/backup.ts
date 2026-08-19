import { migrateCards, migrateTransactions } from "@/lib/migrate";
import type { Card, HomeLayout, Transaction } from "@/lib/types";

const FORMAT = "pesolita.backup";
const VERSION = 1;

export interface WalletBackup {
  format: typeof FORMAT;
  version: number;
  exportedAt: string;
  cards: Card[];
  tx: Transaction[];
  dismissedNotices: string[];
  userName: string;
  privacy: boolean;
  homeLayout: HomeLayout;
  nudgeLowBalance: boolean;
  nudgeDailyLog: boolean;
}

export type BackupPayload = Omit<WalletBackup, "format" | "version" | "exportedAt">;

export function buildBackup(payload: BackupPayload): string {
  const backup: WalletBackup = {
    format: FORMAT,
    version: VERSION,
    exportedAt: new Date().toISOString(),
    ...payload,
  };
  return JSON.stringify(backup, null, 2);
}

export class BackupError extends Error {}

/**
 * A restore replaces the wallet, so the file is validated before it is trusted — and run
 * through the same migration as stored data, since a backup can be older than this build.
 */
export function parseBackup(text: string): BackupPayload {
  let raw: unknown;
  try {
    raw = JSON.parse(text);
  } catch {
    throw new BackupError("That file isn't a Pesolita backup.");
  }

  const data = raw as Partial<WalletBackup>;
  if (!data || typeof data !== "object" || data.format !== FORMAT) {
    throw new BackupError("That file isn't a Pesolita backup.");
  }
  if (typeof data.version !== "number" || data.version > VERSION) {
    throw new BackupError("That backup came from a newer version of Pesolita.");
  }

  const cards = migrateCards(data.cards);
  return {
    cards,
    tx: migrateTransactions(data.tx, cards),
    dismissedNotices: Array.isArray(data.dismissedNotices) ? data.dismissedNotices.filter((v) => typeof v === "string") : [],
    userName: typeof data.userName === "string" ? data.userName : "",
    privacy: !!data.privacy,
    homeLayout: data.homeLayout === "stack" ? "stack" : "deck",
    nudgeLowBalance: data.nudgeLowBalance !== false,
    nudgeDailyLog: data.nudgeDailyLog !== false,
  };
}

/** Hand the file straight to the browser — the data never goes anywhere else. */
export function downloadText(filename: string, contents: string, mime: string): void {
  const blob = new Blob([contents], { type: mime });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}
