/**
 * The Pesolita mark: the mascot's face struck on a peso coin.
 *
 * A coin rather than a plain head, because the head alone is brown — and brown on the app's
 * near-black chrome has almost no contrast, which is why the old star mark was yellow. The
 * coin gives the character a field to sit on that reads on any background, and says what the
 * app is about in the same breath.
 *
 * Deliberately simplified from `Mascot`: no shell, no bag, no gradients, and the linework is
 * heavier. This has to survive a 16px favicon, where anything finer turns to mush.
 */
export function MascotMark({ size = "100%" }: { size?: number | string }) {
  return (
    <svg viewBox="0 0 48 48" width={size} height={size} aria-hidden="true" focusable="false">
      {/* coin */}
      <circle cx="24" cy="24" r="22.6" fill="#ffca28" stroke="#d8a318" strokeWidth="2.8" />
      <circle cx="24" cy="24" r="18.4" fill="none" stroke="#d8a318" strokeWidth="1.3" opacity="0.4" />

      {/* antennae — drawn first so the head caps their base */}
      <path
        d="M19.5 17.5 C 17.6 13.4, 15.4 10.8, 12.3 8.6"
        fill="none"
        stroke="#4f3020"
        strokeWidth="2.5"
        strokeLinecap="round"
      />
      <path
        d="M28.5 17.5 C 30.4 13.4, 32.6 10.8, 35.7 8.6"
        fill="none"
        stroke="#4f3020"
        strokeWidth="2.5"
        strokeLinecap="round"
      />

      {/* head */}
      <ellipse cx="24" cy="27.6" rx="13.6" ry="11.9" fill="#a2653c" stroke="#4f3020" strokeWidth="2.2" />

      {/* eyes: the one feature that has to survive at favicon size, so they stay oversized */}
      <ellipse cx="18.9" cy="26.4" rx="4.4" ry="5.1" fill="#fff" stroke="#4f3020" strokeWidth="1.5" />
      <ellipse cx="29.1" cy="26.4" rx="4.4" ry="5.1" fill="#fff" stroke="#4f3020" strokeWidth="1.5" />
      <circle cx="19.3" cy="27.1" r="2.9" fill="#33200f" />
      <circle cx="29.5" cy="27.1" r="2.9" fill="#33200f" />
      <circle cx="17.9" cy="25.4" r="1.25" fill="#fff" />
      <circle cx="28.1" cy="25.4" r="1.25" fill="#fff" />

      {/* smile */}
      <path d="M21 33.4 A 3.4 3.4 0 0 0 27 33.4 Z" fill="#82322b" />
    </svg>
  );
}
