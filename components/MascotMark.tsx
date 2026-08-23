import { useId } from "react";

/**
 * The Pesolita brand mark: the app icon, reduced to what survives 22px.
 *
 * Same squircle, same cream ground, same face as `app/icon.svg` — but the body, the waving
 * arm, the ₱ bubble and the sparkles are all dropped. At the size this renders in the nav
 * those read as noise around the head rather than as detail, and the head plus the eyes are
 * what actually identifies the character.
 *
 * Kept in lockstep with the app icon on purpose: the thing in the chrome and the thing on the
 * home screen should be recognisably one mark.
 */
export function MascotMark({ size = "100%" }: { size?: number | string }) {
  // The gradients are document-scoped, so every instance needs its own ids.
  const uid = useId().replace(/:/g, "");
  const bg = `${uid}-bg`;
  const hd = `${uid}-hd`;
  const clip = `${uid}-clip`;

  return (
    <svg viewBox="0 0 48 48" width={size} height={size} aria-hidden="true" focusable="false">
      <defs>
        <radialGradient id={bg} cx="42%" cy="30%" r="82%">
          <stop offset="0%" stopColor="#F9EDD6" />
          <stop offset="100%" stopColor="#DCC098" />
        </radialGradient>
        <radialGradient id={hd} cx="35%" cy="24%" r="80%">
          <stop offset="0%" stopColor="#BA7F52" />
          <stop offset="100%" stopColor="#935729" />
        </radialGradient>
        <clipPath id={clip}>
          <ellipse cx="24" cy="27.5" rx="14.6" ry="13.1" />
        </clipPath>
      </defs>

      <rect width="48" height="48" rx="11" fill={`url(#${bg})`} />

      <path d="M19 18.5 C 16 13.5, 12.4 10, 8.4 7.6" fill="none" stroke="#6b4226" strokeWidth="2.6" strokeLinecap="round" />
      <path d="M29 18.5 C 32 13.5, 35.6 10, 39.6 7.6" fill="none" stroke="#6b4226" strokeWidth="2.6" strokeLinecap="round" />

      <ellipse cx="24" cy="27.5" rx="14.6" ry="13.1" fill={`url(#${hd})`} stroke="#4f3020" strokeWidth="2.2" />

      <g clipPath={`url(#${clip})`}>
        <ellipse cx="11.5" cy="33" rx="3.6" ry="2.5" fill="#e79a87" opacity="0.55" />
        <ellipse cx="36.5" cy="33" rx="3.6" ry="2.5" fill="#e79a87" opacity="0.55" />
      </g>

      {/* Oversized on purpose — at 22px the eyes are the only feature still doing work. */}
      <ellipse cx="18.6" cy="26.4" rx="4.7" ry="5.3" fill="#fff" stroke="#4f3020" strokeWidth="1.7" />
      <ellipse cx="29.4" cy="26.4" rx="4.7" ry="5.3" fill="#fff" stroke="#4f3020" strokeWidth="1.7" />
      <circle cx="18.9" cy="27.1" r="3.1" fill="#33200f" />
      <circle cx="29.7" cy="27.1" r="3.1" fill="#33200f" />
      <circle cx="17.4" cy="25.2" r="1.45" fill="#fff" />
      <circle cx="28.2" cy="25.2" r="1.45" fill="#fff" />

      <path d="M20.6 33.6 Q24 32.5 27.4 33.6 Q27.4 38 24 38 Q20.6 38 20.6 33.6 Z" fill="#82322b" />
    </svg>
  );
}
