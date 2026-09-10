"use client";

import { useEffect, useRef, useState } from "react";

import { Mascot } from "@/components/Mascot";
import { loadCelebration3D } from "@/lib/mascot3d/load";

import styles from "./CelebrationMascot3D.module.css";

export function CelebrationMascot3D() {
  const hostRef = useRef<HTMLDivElement>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const host = hostRef.current;
    if (!host) return;
    let cancelled = false;
    let dispose: (() => void) | undefined;

    void loadCelebration3D()
      .then(({ mountCelebration }) => {
        if (cancelled) return;
        dispose = mountCelebration(host, (available) => {
          if (!cancelled) setReady(available);
        });
      })
      .catch(() => {
        if (!cancelled) setReady(false);
      });

    return () => {
      cancelled = true;
      dispose?.();
    };
  }, []);

  return (
    <div className={styles.stage} aria-hidden="true" data-mascot-3d={ready ? "ready" : "fallback"}>
      {!ready && (
        <div className={styles.fallback}>
          <Mascot mood="cheer" size={168} />
        </div>
      )}
      <div ref={hostRef} className={styles.canvas} style={{ visibility: ready ? "visible" : "hidden" }} />
    </div>
  );
}
