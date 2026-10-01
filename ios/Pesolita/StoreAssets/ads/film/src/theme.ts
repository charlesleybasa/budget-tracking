import { loadFont as loadAnton } from "@remotion/google-fonts/Anton";
import { continueRender, delayRender, staticFile } from "remotion";

// Brand colours, from make_assets.py (the app's palette).
export const INK = "#0B0B0D";
export const GOLD = "#FFCA28";
export const BLUE = "#1D6FF2";
export const WHITE = "#F5F4F0";
export const DANGER = "#FF3B30";

// Trailer display face (OFL) and the brand face (Outfit, bundled). ₱ falls back to the system
// font (SF on the Mac that renders), exactly as it does in the app.
export const { fontFamily: ANTON } = loadAnton();
export const OUTFIT = "Outfit, -apple-system, 'SF Pro Display', sans-serif";
export const DISPLAY = `${ANTON}, Impact, sans-serif`;

const handle = delayRender("Outfit font");
const outfit = new FontFace("Outfit", `url(${staticFile("fonts/Outfit.ttf")})`, { weight: "100 900" });
outfit
  .load()
  .then((f) => {
    document.fonts.add(f);
    continueRender(handle);
  })
  .catch(() => continueRender(handle));
