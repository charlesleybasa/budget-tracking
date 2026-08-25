"use client";

import { useCallback, useLayoutEffect, useRef, useState } from "react";

import { MascotMark } from "@/components/MascotMark";
import { useWallet } from "@/lib/store";
import type { Screen } from "@/lib/types";

import styles from "./Nav.module.css";

interface Destination {
  screen: Screen;
  label: string;
  d: string;
}

const DESTINATIONS: readonly Destination[] = [
  { screen: "home", label: "Home", d: "M4 11.5L12 5l8 6.5V20a1 1 0 01-1 1h-4v-6H9v6H5a1 1 0 01-1-1z" },
  { screen: "insights", label: "Insights", d: "M5 19V9M10 19V5M15 19v-7M20 19v-4" },
  { screen: "search", label: "Search", d: "M11 18a7 7 0 100-14 7 7 0 000 14zM16.5 16.5L21 21" },
  {
    screen: "settings",
    label: "Settings",
    d: "M12 15.5a3.5 3.5 0 100-7 3.5 3.5 0 000 7zM12 2.5l1.6 2.1 2.6-.5.5 2.6 2.3 1.3-1.2 2.4 1.2 2.4-2.3 1.3-.5 2.6-2.6-.5L12 21.5l-1.6-2.1-2.6.5-.5-2.6L5 15.9l1.2-2.4L5 11.1l2.3-1.3.5-2.6 2.6.5z",
  },
];

/**
 * Search is a primary destination, so the phone bar stays available there. Card detail,
 * the editor and transfer remain focused tasks with their own dismiss affordances. The
 * desktop rail persists everywhere.
 */
const PHONE_BAR_SCREENS: readonly Screen[] = ["home", "insights", "search", "settings"];

interface Box {
  x: number;
  y: number;
  w: number;
  h: number;
}

export function Nav() {
  const { state, actions } = useWallet();
  const navRef = useRef<HTMLElement>(null);
  const tabRefs = useRef(new Map<Screen, HTMLButtonElement>());
  const [box, setBox] = useState<Box | null>(null);

  const activeIndex = DESTINATIONS.findIndex((d) => d.screen === state.screen);
  const onPhoneBar = PHONE_BAR_SCREENS.includes(state.screen);

  /**
   * The indicator is placed from the active tab's measured box rather than from a counter and
   * a table of magic offsets. Measuring is the only approach that stays correct across the
   * bar, the rail, the labelled wide rail and the short-viewport variant at once — and it
   * cannot drift out of alignment when any of that spacing changes.
   */
  const place = useCallback(() => {
    const nav = navRef.current;
    const tab = activeIndex >= 0 ? tabRefs.current.get(DESTINATIONS[activeIndex].screen) : undefined;
    if (!nav || !tab) return;
    const navRect = nav.getBoundingClientRect();
    const tabRect = tab.getBoundingClientRect();
    setBox({
      x: Math.round(tabRect.left - navRect.left),
      y: Math.round(tabRect.top - navRect.top),
      w: Math.round(tabRect.width),
      h: Math.round(tabRect.height),
    });
  }, [activeIndex]);

  useLayoutEffect(() => {
    place();
    const nav = navRef.current;
    if (!nav) return;
    // Breakpoint changes move every tab; re-measure rather than predict.
    const observer = new ResizeObserver(place);
    observer.observe(nav);
    return () => observer.disconnect();
  }, [place]);

  return (
    <nav ref={navRef} className={`${styles.nav} ${onPhoneBar ? "" : styles.hiddenOnPhone}`} aria-label="Main">
      <div className={styles.brand} aria-hidden="true">
        <span className={styles.brandMark}>
          <MascotMark />
        </span>
        <span className={styles.brandName}>Pesolita</span>
      </div>

      {box ? (
        <div
          className={styles.indicator}
          aria-hidden="true"
          style={{
            transform: `translate(${box.x}px, ${box.y}px)`,
            width: box.w,
            height: box.h,
            // Nothing is selected on a focused task screen, so the pill steps aside.
            opacity: activeIndex >= 0 ? 1 : 0,
          }}
        />
      ) : null}

      {DESTINATIONS.map((destination, i) => {
        const active = state.screen === destination.screen;
        const isFabSlot = i === 2;
        return (
          <span key={destination.screen} className={styles.slot} style={{ display: "contents" }}>
            {isFabSlot ? (
              <button
                type="button"
                className={styles.fab}
                onClick={() => actions.openSheet("withdraw")}
                aria-label="Log a spend"
              >
                <svg
                  className={styles.fabIcon}
                  width={24}
                  height={24}
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="#fff"
                  strokeWidth={2.6}
                  strokeLinecap="round"
                  aria-hidden="true"
                >
                  <path d="M12 5v14M5 12h14" />
                </svg>
                <span className={styles.fabLabel}>Log spend</span>
              </button>
            ) : null}

            <button
              ref={(el) => {
                if (el) tabRefs.current.set(destination.screen, el);
                else tabRefs.current.delete(destination.screen);
              }}
              type="button"
              className={`${styles.tab} ${active ? styles.tabActive : ""}`}
              onClick={() => actions.go(destination.screen)}
              aria-current={active ? "page" : undefined}
              aria-label={destination.label}
            >
              <svg
                className={styles.tabIcon}
                width={22}
                height={22}
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth={2.1}
                strokeLinecap="round"
                strokeLinejoin="round"
                aria-hidden="true"
              >
                <path d={destination.d} />
              </svg>
              <span className={styles.tabLabel}>{destination.label}</span>
            </button>
          </span>
        );
      })}
    </nav>
  );
}
