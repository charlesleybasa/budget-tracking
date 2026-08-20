"use client";

import { buildBackup, downloadText } from "@/lib/backup";
import { useWallet } from "@/lib/store";

/**
 * Writes the whole wallet out as one restorable file.
 *
 * Shared rather than local to the settings screen because the erase confirmation offers the
 * same backup — that offer is the thing that turns an irreversible action into a reversible
 * one, so both callers must produce exactly the same file.
 *
 * Returns false when there was nothing worth writing, which lets a caller tell "saved" from
 * "there was nothing to save".
 */
export function useBackup(): () => boolean {
  const { state, actions } = useWallet();

  return () => {
    if (state.cards.length === 0) {
      actions.toast("Nothing to back up yet.");
      return false;
    }
    downloadText(
      `pesolita-backup-${new Date().toISOString().slice(0, 10)}.json`,
      buildBackup({
        cards: state.cards,
        tx: state.tx,
        dismissedNotices: state.dismissedNotices,
        userName: state.userName,
        privacy: state.privacy,
        homeLayout: state.homeLayout,
        nudgeLowBalance: state.nudgeLowBalance,
        nudgeDailyLog: state.nudgeDailyLog,
      }),
      "application/json",
    );
    actions.toast("Backup saved.");
    return true;
  };
}
