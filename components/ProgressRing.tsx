import type { CSSProperties } from "react";

import { progressColor } from "@/lib/selectors";

export interface ProgressRingProps {
  /** 0–1. */
  progress: number;
  size: number;
  /** On a savings goal a high number is good; on a spend limit it is not. */
  goalMode?: boolean;
}

/** The sweep runs off a keyframe, so it plays whenever the ring mounts and never needs a flag. */
export function ProgressRing({ progress, size, goalMode = false }: ProgressRingProps) {
  const r = size / 2 - 6;
  const circumference = 2 * Math.PI * r;
  const offset = circumference * (1 - Math.min(1, progress));

  return (
    <svg width={size} height={size} style={{ flex: "none", transform: "rotate(-90deg)" }} aria-hidden="true">
      <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="#e3e2dc" strokeWidth={9} />
      <circle
        cx={size / 2}
        cy={size / 2}
        r={r}
        fill="none"
        stroke={progressColor(progress, goalMode)}
        strokeWidth={9}
        strokeLinecap="round"
        strokeDasharray={circumference}
        style={
          {
            "--ring-len": circumference,
            "--ring-off": offset,
            strokeDashoffset: offset,
            animation: "bwRingSweep 1.1s cubic-bezier(.2,.8,.2,1) both",
          } as CSSProperties
        }
      />
    </svg>
  );
}
