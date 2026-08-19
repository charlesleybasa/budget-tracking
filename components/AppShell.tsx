"use client";

import { useEffect } from "react";

import { Mark } from "@/components/Mark";
import { Nav } from "@/components/Nav";
import { Toast } from "@/components/Toast";
import { SuccessOverlay } from "@/components/overlays/SuccessOverlay";
import { TxSheet } from "@/components/overlays/TxSheet";
import { CardDetail } from "@/components/screens/CardDetail";
import { CardEditor } from "@/components/screens/CardEditor";
import { Home } from "@/components/screens/Home";
import { Insights } from "@/components/screens/Insights";
import { Onboarding } from "@/components/screens/Onboarding";
import { SearchScreen } from "@/components/screens/SearchScreen";
import { SettingsScreen } from "@/components/screens/SettingsScreen";
import { Transfer } from "@/components/screens/Transfer";
import { useWallet } from "@/lib/store";
import { useBackNavigation } from "@/lib/useBackNavigation";
import type { Screen } from "@/lib/types";

import styles from "./AppShell.module.css";

function CurrentScreen() {
  const { state } = useWallet();
  switch (state.screen) {
    case "onboard":
      return <Onboarding />;
    case "home":
      return <Home />;
    case "detail":
      return <CardDetail />;
    case "insights":
      return <Insights />;
    case "search":
      return <SearchScreen />;
    case "editor":
      return <CardEditor />;
    case "transfer":
      return <Transfer />;
    case "settings":
      return <SettingsScreen />;
    default:
      return <Home />;
  }
}

/** Screens that are a task rather than a destination — Escape backs out of them. */
const DISMISSABLE: readonly Screen[] = ["detail", "editor", "transfer", "search"];

export function AppShell() {
  const { state, actions } = useWallet();

  // Hardware and browser back should walk back through the app, not out of it.
  const away = state.screen !== "home" || !!state.sheet || !!state.success;
  useBackNavigation(!away, () => {
    if (state.success) actions.closeSuccess();
    else if (state.sheet) actions.closeSheet();
    else actions.go("home");
  });

  // One Escape handler for the whole app, applied to whatever layer is on top.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== "Escape") return;
      if (state.success) actions.closeSuccess();
      else if (state.sheet) actions.closeSheet();
      else if (DISMISSABLE.includes(state.screen)) actions.go("home");
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [state.success, state.sheet, state.screen, actions]);
  // Onboarding owns the whole viewport; every other screen keeps the navigation beside it.
  const showNav = state.hydrated && state.screen !== "onboard";

  return (
    <main className={`${styles.app} ${showNav ? "" : styles.appSolo}`}>
      {showNav ? <Nav /> : null}

      <div className={styles.surface}>
        {/* Reading the device store is an effect, so nothing renders until it has run —
            otherwise a returning user gets a frame of onboarding they already finished. */}
        {state.hydrated ? (
          <>
            <CurrentScreen />
            <TxSheet />
            <SuccessOverlay />
            <Toast />
          </>
        ) : (
          <div className={styles.splash}>
            <div className={styles.splashMark}>
              <Mark color="#ffca28" />
            </div>
          </div>
        )}
      </div>
    </main>
  );
}
