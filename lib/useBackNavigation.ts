"use client";

import { useEffect, useRef } from "react";

/**
 * The app is a single route, so without this the phone's back gesture and the browser's back
 * button leave the app entirely from any screen — the most jarring thing a web app can do on
 * Android. Each navigation away from home pushes a history entry, and popping one walks back
 * to home rather than off the site.
 */
export function useBackNavigation(atHome: boolean, goHome: () => void): void {
  const pushedRef = useRef(false);

  useEffect(() => {
    const onPop = () => {
      pushedRef.current = false;
      // Something was open; close it instead of leaving.
      goHome();
    };
    window.addEventListener("popstate", onPop);
    return () => window.removeEventListener("popstate", onPop);
  }, [goHome]);

  useEffect(() => {
    if (atHome) {
      pushedRef.current = false;
      return;
    }
    if (pushedRef.current) return;
    pushedRef.current = true;
    window.history.pushState({ pesolita: true }, "");
  }, [atHome]);
}
