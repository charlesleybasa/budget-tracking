"use client";

import { useState, type ReactNode } from "react";

import { buildBackup, downloadText } from "@/lib/backup";
import { useRestore } from "@/lib/useRestore";
import { transactionsToCsv } from "@/lib/csv";
import { useWallet } from "@/lib/store";

import styles from "./SettingsScreen.module.css";

function Toggle({ on }: { on: boolean }) {
  return (
    <span className={styles.toggle} style={{ background: on ? "#0b8f6a" : "#dcdbd5" }} aria-hidden="true">
      <span className={styles.toggleKnob} style={{ transform: on ? "translateX(17px)" : "none" }} />
    </span>
  );
}

interface Row {
  label: string;
  sub: string;
  bg: string;
  icon: ReactNode;
  onClick: () => void;
  toggle?: boolean;
  danger?: boolean;
}

export function SettingsScreen() {
  const { state, actions } = useWallet();
  // Erasing everything is irreversible, so it takes two deliberate taps.
  const [confirmReset, setConfirmReset] = useState(false);

  const activeName = state.cards.find((c) => c.id === state.activeId)?.nick ?? "your card";

  const firstName = state.userName.trim().split(" ")[0] || "there";
  const initials =
    (state.userName.trim() || "Pesolita")
      .split(" ")
      .map((w) => w.charAt(0).toUpperCase())
      .slice(0, 2)
      .join("") || "P";

  const restore = useRestore();

  const exportCsv = () => {
    if (state.tx.length === 0) {
      actions.toast("Nothing to export yet.");
      return;
    }
    // The BOM keeps spreadsheet apps from mangling the peso sign.
    downloadText(
      "pesolita-transactions.csv",
      `\ufeff${transactionsToCsv(state.tx, state.cards)}`,
      "text/csv;charset=utf-8",
    );
    actions.toast(`Exported ${state.tx.length} rows.`);
  };

  const backup = () => {
    if (state.cards.length === 0) {
      actions.toast("Nothing to back up yet.");
      return;
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
  };


  const groups: ReadonlyArray<{ title: string; rows: Row[] }> = [
    {
      title: "Money",
      rows: [
        {
          label: "Card limits",
          sub: state.cards.length > 0 ? `Edit ${activeName}` : "Add a card first",
          bg: "#ffca2833",
          icon: (
            <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="#a4801a" strokeWidth={2.2} strokeLinecap="round">
              <path d="M4 18V8M10 18V5M16 18v-6M4 21h16" />
            </svg>
          ),
          onClick: () =>
            state.cards.length > 0 ? actions.openEditor(state.activeId) : actions.toast("Add a card first."),
        },
      ],
    },
    {
      title: "Nudges",
      rows: [
        {
          label: "Low balance nudge",
          sub: "When a card drops under ₱1,500",
          bg: "#f0483e33",
          icon: (
            <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="#f0483e" strokeWidth={2.2} strokeLinecap="round">
              <path d="M12 4l9 16H3z M12 10v4M12 17h.01" />
            </svg>
          ),
          onClick: () => {
            const next = !state.nudgeLowBalance;
            actions.patch({ nudgeLowBalance: next });
            actions.toast(next ? "Low balance nudges on." : "Low balance nudges off.");
          },
          toggle: state.nudgeLowBalance,
        },
        {
          label: "Daily log reminder",
          sub: "A nudge at 9pm — needs notification permission",
          bg: "#7c3aed33",
          icon: (
            <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="#7c3aed" strokeWidth={2.2} strokeLinecap="round">
              <path d="M18 8a6 6 0 10-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4" />
            </svg>
          ),
          onClick: () => {
            const next = !state.nudgeDailyLog;
            actions.patch({ nudgeDailyLog: next });
            actions.toast(next ? "Reminder set for 9pm." : "Daily reminder off.");
          },
          toggle: state.nudgeDailyLog,
        },
      ],
    },
    {
      title: "Your data",
      rows: [
        {
          label: "Hide balances",
          sub: "Blur every number on unlock",
          bg: "#0b0b0c14",
          icon: (
            <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="#0b0b0c" strokeWidth={2.2} strokeLinecap="round">
              <path d="M2 12s3.6-6.5 10-6.5S22 12 22 12s-3.6 6.5-10 6.5S2 12 2 12z" />
              <circle cx={12} cy={12} r={2.8} />
            </svg>
          ),
          onClick: () => actions.patch({ privacy: !state.privacy }),
          toggle: state.privacy,
        },
        {
          label: "Back up wallet",
          sub: "Cards, history and settings as one file",
          bg: "#0b8f6a26",
          icon: (
            <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="#0b8f6a" strokeWidth={2.2} strokeLinecap="round">
              <path d="M12 3v12M7 10l5 5 5-5M4 20h16" />
            </svg>
          ),
          onClick: backup,
        },
        {
          label: "Restore from backup",
          sub: "Replaces everything on this device",
          bg: "#1d6ff226",
          icon: (
            <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="#1d6ff2" strokeWidth={2.2} strokeLinecap="round">
              <path d="M12 21V9M7 14l5-5 5 5M4 4h16" />
            </svg>
          ),
          onClick: restore.open,
        },
        {
          label: "Export CSV",
          sub: "Transactions only, for a spreadsheet",
          bg: "#0b0b0c14",
          icon: (
            <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="#0b0b0c" strokeWidth={2.2} strokeLinecap="round">
              <path d="M4 4h11l5 5v11H4zM15 4v5h5M8 13h8M8 17h5" />
            </svg>
          ),
          onClick: exportCsv,
        },
        {
          label: confirmReset ? "Tap again to erase everything" : "Start over",
          sub: confirmReset
            ? "Every card and every entry, gone for good"
            : "Erase all cards and history from this device",
          bg: "#f0483e26",
          danger: true,
          icon: (
            <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="#c62f26" strokeWidth={2.2} strokeLinecap="round">
              <path d="M4 7h16M9 7V5h6v2M6 7l1 13h10l1-13M10 11v6M14 11v6" />
            </svg>
          ),
          onClick: () => {
            if (!confirmReset) {
              setConfirmReset(true);
              window.setTimeout(() => setConfirmReset(false), 4000);
              return;
            }
            actions.resetEverything();
          },
        },
      ],
    },
  ];

  return (
    <section
      className={`${styles.screen} bwEnterUp`}
      aria-label="Settings"
    >
      <div className={styles.header}>
        <div className={styles.headerInner}>
        <div className={styles.nav}>
          <button type="button" className={`${styles.roundBtn} ${styles.backBtn}`} onClick={() => actions.go("home")} aria-label="Back to home">
            <svg width={16} height={16} viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth={2.6} strokeLinecap="round">
              <path d="M19 12H6M12 6l-6 6 6 6" />
            </svg>
          </button>
          <div className={styles.navTitle}>Settings</div>
          <div className={styles.navSpacer} />
        </div>

        <div className={styles.profile}>
          <div className={styles.avatar}>{initials}</div>
          <div>
            <div className={styles.name}>{firstName}</div>
            <div className={styles.meta}>
              {state.cards.length === 0
                ? "No cards yet · nothing connected to a bank"
                : `${state.cards.length} ${state.cards.length === 1 ? "card" : "cards"} · nothing connected to a bank`}
            </div>
          </div>
        </div>
        </div>
      </div>

      <input {...restore.inputProps} />

      <div className={styles.scroll}>
        <div className={styles.scrollInner}>
        {groups.map((group) => (
          <div key={group.title} className={styles.group}>
            <div className={styles.groupTitle}>{group.title}</div>
            <div className={styles.rows}>
              {group.rows.map((row) => (
                <button
                  key={row.label}
                  type="button"
                  className={`${styles.row} ${row.danger ? styles.rowDanger : ""}`}
                  onClick={row.onClick}
                  aria-pressed={row.toggle === undefined ? undefined : row.toggle}
                >
                  <span className={styles.rowIcon} style={{ background: row.bg }}>
                    {row.icon}
                  </span>
                  <span style={{ flex: 1 }}>
                    <span className={styles.rowLabel} style={{ display: "block" }}>
                      {row.label}
                    </span>
                    <span className={styles.rowSub} style={{ display: "block" }}>
                      {row.sub}
                    </span>
                  </span>
                  {row.toggle === undefined ? null : <Toggle on={row.toggle} />}
                </button>
              ))}
            </div>
          </div>
        ))}

        <p className={styles.footer}>Pesolita 1.0 · Your numbers never leave this device.</p>
        </div>
      </div>

    </section>
  );
}
