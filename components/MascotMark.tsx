/**
 * The Pesolita brand mark — the app icon, at the sizes the chrome renders it.
 *
 * A raster rather than the hand-drawn SVG it replaces: the icon artwork is a rendered
 * illustration with painted shading, and there is no vector source to reduce it from. It is
 * built by scripts/build-icons.mjs from the same file as app/icon.png, so the mark in the nav
 * and the icon on the home screen can never drift apart.
 *
 * Served at 96px for a static ~20px slot, which covers 3x displays with room to spare and
 * still only costs 8KB.
 */
export function MascotMark({ size = "100%" }: { size?: number | string }) {
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src="/brand-mark.png"
      alt=""
      aria-hidden="true"
      width={96}
      height={96}
      style={{ width: size, height: size, display: "block", objectFit: "contain" }}
    />
  );
}
