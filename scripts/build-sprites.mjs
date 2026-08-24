#!/usr/bin/env node
/**
 * Builds the sprite atlases in public/ from PNG frame sequences.
 *
 * Run: node scripts/build-sprites.mjs
 *
 * The sequences themselves are not in the repo — they are large rendered exports. Point
 * SOURCES at wherever they live and re-run this when they change.
 *
 * Two things here are load-bearing:
 *
 * 1. Frames are cropped to the union bounding box of content across the whole sequence.
 *    Roughly a third of every source frame is transparent padding, and cropping per-frame
 *    instead would make the character jitter because each frame's box differs.
 *
 * 2. Palette quantisation is followed by an alpha clean-up pass. libimagequant likes to
 *    represent "transparent" with a near-transparent *colour* (alpha 3 of a mid-brown here)
 *    rather than a true alpha 0. Over a white page nobody notices; over the app's near-black
 *    onboarding screen every cell renders as a faintly lit rectangle. Forcing sub-threshold
 *    alpha to 0 and re-encoding fixes it.
 */
import fs from "node:fs";
import path from "node:path";
import sharp from "sharp";

const SOURCES = [
  {
    name: "celebrate",
    dir: "/Users/rli/Documents/Celebrate",
    match: /^Celebrate\d+\.png$/,
    cols: 8,
    rows: 4,
    cellW: 300,
    colours: 128,
  },
  {
    name: "sad",
    dir: "/Users/rli/Desktop/Sad",
    match: /^sad_blink_\d+\.png$/,
    cols: 10,
    rows: 6,
    cellW: 240,
    colours: 128,
  },
  {
    name: "peekaboo",
    dir: "/Users/rli/Desktop/Onboarding",
    match: /^peekaboo_\d+\.png$/,
    cols: 9,
    rows: 6,
    cellW: 280,
    colours: 128,
  },
];

const OUT_DIR = path.join(process.cwd(), "public");
/** Alpha at or below this is treated as fully transparent. */
const ALPHA_FLOOR = 8;

/** Union bounding box of non-transparent content across every frame. */
async function unionBox(files) {
  let L = Infinity, T = Infinity, R = -1, B = -1;
  for (const f of files) {
    const { data, info } = await sharp(f).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    const { width, height, channels } = info;
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        if (data[(y * width + x) * channels + 3] > ALPHA_FLOOR) {
          if (x < L) L = x;
          if (x > R) R = x;
          if (y < T) T = y;
          if (y > B) B = y;
        }
      }
    }
  }
  return { left: L, top: T, width: R - L + 1, height: B - T + 1 };
}

/** Zero out sub-threshold alpha so the re-encode gets a true transparent palette entry. */
async function cleanAlpha(buf) {
  const { data, info } = await sharp(buf).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  for (let i = 0; i < data.length; i += info.channels) {
    if (data[i + 3] <= ALPHA_FLOOR) {
      data[i] = 0;
      data[i + 1] = 0;
      data[i + 2] = 0;
      data[i + 3] = 0;
    }
  }
  return { data, info };
}

async function build(spec) {
  const files = fs
    .readdirSync(spec.dir)
    .filter((f) => spec.match.test(f))
    .sort()
    .map((f) => path.join(spec.dir, f));

  const expected = spec.cols * spec.rows;
  if (files.length !== expected) {
    throw new Error(
      `${spec.name}: found ${files.length} frames but the grid is ${spec.cols}x${spec.rows} = ${expected}. ` +
        `The stepping math assumes no blank trailing cells, so the grid has to match exactly.`,
    );
  }

  const box = await unionBox(files);
  const cellH = Math.round(spec.cellW * (box.height / box.width));
  const sheetW = spec.cols * spec.cellW;
  const sheetH = spec.rows * cellH;
  // Older mobile GPUs cap textures at 4096px; past that the sheet fails to draw or is
  // silently downscaled.
  if (sheetW > 4096 || sheetH > 4096) {
    throw new Error(`${spec.name}: sheet ${sheetW}x${sheetH} exceeds the 4096px texture cap.`);
  }

  const tiles = [];
  for (let i = 0; i < files.length; i++) {
    const buf = await sharp(files[i]).extract(box).resize(spec.cellW, cellH).png().toBuffer();
    tiles.push({ input: buf, left: (i % spec.cols) * spec.cellW, top: Math.floor(i / spec.cols) * cellH });
  }

  const flat = await sharp({
    create: { width: sheetW, height: sheetH, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } },
  })
    .composite(tiles)
    .png()
    .toBuffer();

  // Quantise, scrub the alpha the quantiser fudged, then re-encode.
  const quantised = await sharp(flat)
    .png({ compressionLevel: 9, palette: true, colours: spec.colours, dither: 0, effort: 10 })
    .toBuffer();
  const cleaned = await cleanAlpha(quantised);
  const out = await sharp(cleaned.data, {
    raw: { width: cleaned.info.width, height: cleaned.info.height, channels: cleaned.info.channels },
  })
    .png({ compressionLevel: 9, palette: true, colours: spec.colours, dither: 0, effort: 10 })
    .toBuffer();

  // Verify the fix actually took, rather than trusting it.
  const check = await sharp(out).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const c = check.info.channels;
  let opaqueCorners = 0;
  for (const [x, y] of [[1, 1], [sheetW - 2, 1], [1, sheetH - 2], [sheetW - 2, sheetH - 2]]) {
    if (check.data[(y * check.info.width + x) * c + 3] !== 0) opaqueCorners++;
  }

  fs.mkdirSync(OUT_DIR, { recursive: true });
  fs.writeFileSync(path.join(OUT_DIR, `${spec.name}.png`), out);

  console.log(
    `${spec.name}.png  ${spec.cols}x${spec.rows}=${files.length} frames  ` +
      `cell ${spec.cellW}x${cellH}  sheet ${sheetW}x${sheetH}  ` +
      `${(out.length / 1024).toFixed(0)}KB  ` +
      (opaqueCorners === 0 ? "transparent corners OK" : `WARNING: ${opaqueCorners} corners not transparent`),
  );
  return { name: spec.name, cellW: spec.cellW, cellH, frames: files.length, cols: spec.cols, rows: spec.rows };
}

for (const spec of SOURCES) {
  // The sequences live outside the repo, so one of them being moved or archived is normal.
  // Skip it and leave the already-built atlas in public/ alone rather than failing the run
  // and taking the other sheets down with it.
  if (!fs.existsSync(spec.dir)) {
    console.log(`${spec.name}: source ${spec.dir} not found — skipping, public/${spec.name}.png left as-is`);
    continue;
  }
  const r = await build(spec);
  console.log(`   -> lib/sprites.ts should read: cols ${r.cols}, rows ${r.rows}, frames ${r.frames}, cellW ${r.cellW}, cellH ${r.cellH}`);
}
