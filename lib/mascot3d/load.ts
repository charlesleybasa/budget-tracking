/** Keep the renderer and Three.js outside the wallet's initial JavaScript bundle. */
export function loadCelebration3D() {
  return import("./scene");
}

export function preloadCelebration3D() {
  // Preloading is optional: the celebration retains its fallback if a chunk is unavailable.
  void loadCelebration3D().catch(() => undefined);
}
