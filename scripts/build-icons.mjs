#!/usr/bin/env node
/**
 * Builds the app icons in app/ from the rendered source artwork.
 *
 * Run: node scripts/build-icons.mjs
 *
 * The source is a rendered raster whose rounded-square icon shape is already baked in, on a
 * solid black surround with no alpha. Two things follow from that:
 *
 * 1. The black has to go. Shipped as-is, a browser tab would show a black square with the
 *    icon inset in it. The art is cropped to its own bounds and a rounded mask is applied so
 *    the corners are genuinely transparent.
 *
 * 2. apple-icon wants full bleed. iOS applies its own squircle mask, so a pre-rounded icon
 *    with transparent corners ends up visibly inset inside iOS's rounding. The corners are
 *    filled with the artwork's own background amber instead, and iOS rounds that.
 */
import fs from "node:fs";
import path from "node:path";
import sharp from "sharp";

const SRC = "/Users/rli/Downloads/ChatGPT Image Aug 24, 2026, 04_32_27 PM.png";
const OUT_DIR = path.join(process.cwd(), "app");
const PUB_DIR = path.join(process.cwd(), "public");

/** Luminance above this is artwork; below it is the black surround. */
const ART_THRESHOLD = 28;

async function artBounds(src) {
  const { data, info } = await sharp(src).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const { width: w, height: h, channels: c } = info;
  const lum = (x, y) => {
    const i = (y * w + x) * c;
    return 0.2126 * data[i] + 0.7152 * data[i + 1] + 0.0722 * data[i + 2];
  };
  let L = Infinity, T = Infinity, R = -1, B = -1;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      if (lum(x, y) > ART_THRESHOLD) {
        if (x < L) L = x;
        if (x > R) R = x;
        if (y < T) T = y;
        if (y > B) B = y;
      }
    }
  }
  // Square it off from the centre so the mask's corners stay symmetric.
  const side = Math.min(R - L + 1, B - T + 1);
  return {
    left: L + Math.floor((R - L + 1 - side) / 2),
    top: T + Math.floor((B - T + 1 - side) / 2),
    width: side,
    height: side,
  };
}

/** Rounded-square alpha mask, matching the radius baked into the artwork. */
function roundedMask(size, radiusRatio = 0.2237) {
  const r = Math.round(size * radiusRatio);
  return Buffer.from(
    `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}">` +
      `<rect width="${size}" height="${size}" rx="${r}" ry="${r}" fill="#fff"/></svg>`,
  );
}

const box = await artBounds(SRC);
const base = sharp(SRC).extract(box);

// Background amber, sampled just inside the top edge away from the character.
const { data: px } = await base
  .clone()
  .extract({ left: Math.round(box.width * 0.5), top: 14, width: 1, height: 1 })
  .raw()
  .toBuffer({ resolveWithObject: true });
const bg = { r: px[0], g: px[1], b: px[2] };

fs.mkdirSync(OUT_DIR, { recursive: true });
fs.mkdirSync(PUB_DIR, { recursive: true });

async function write(file, size, { fullBleed }) {
  const art = await base.clone().resize(size, size, { fit: "fill" }).png().toBuffer();
  let img = sharp(art).composite([{ input: roundedMask(size), blend: "dest-in" }]);
  if (fullBleed) {
    img = sharp(await img.png().toBuffer()).flatten({ background: bg });
  }
  const out = await img.png({ compressionLevel: 9, palette: true, colours: 200, dither: 0, effort: 10 }).toBuffer();
  fs.writeFileSync(file, out);
  console.log(`${path.relative(process.cwd(), file)}  ${size}x${size}  ${(out.length / 1024).toFixed(0)}KB${fullBleed ? "  (full bleed for iOS masking)" : "  (transparent corners)"}`);
}

console.log(`source ${box.width}x${box.width} cropped from the black surround; bg rgb(${bg.r},${bg.g},${bg.b})`);
await write(path.join(OUT_DIR, "icon.png"), 512, { fullBleed: false });
await write(path.join(OUT_DIR, "apple-icon.png"), 180, { fullBleed: true });
// Small raster for the in-app brand mark, which renders at ~20px.
await write(path.join(PUB_DIR, "brand-mark.png"), 96, { fullBleed: false });
