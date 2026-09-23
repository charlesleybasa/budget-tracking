#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";

import sharp from "sharp";

const source = process.argv[2];
const outputDir = process.argv[3];

if (!source || !outputDir) {
  throw new Error("Usage: node scripts/build-cute-eyes-slider.mjs <source.png> <output-dir>");
}

const { data, info } = await sharp(source)
  .removeAlpha()
  .raw()
  .toBuffer({ resolveWithObject: true });

const { width, height, channels } = info;
const pixelCount = width * height;
const background = new Uint8Array(pixelCount);
const queue = new Int32Array(pixelCount);
let readIndex = 0;
let writeIndex = 0;

function isNeutralBackground(index) {
  const offset = index * channels;
  const red = data[offset];
  const green = data[offset + 1];
  const blue = data[offset + 2];
  const darkest = Math.min(red, green, blue);
  const lightest = Math.max(red, green, blue);
  return lightest - darkest <= 38 && darkest >= 104;
}

function enqueue(index) {
  if (background[index] || !isNeutralBackground(index)) return;
  background[index] = 1;
  queue[writeIndex++] = index;
}

for (let x = 0; x < width; x += 1) {
  enqueue(x);
  enqueue((height - 1) * width + x);
}
for (let y = 0; y < height; y += 1) {
  enqueue(y * width);
  enqueue(y * width + width - 1);
}

while (readIndex < writeIndex) {
  const index = queue[readIndex++];
  const x = index % width;
  const y = Math.floor(index / width);
  if (x > 0) enqueue(index - 1);
  if (x + 1 < width) enqueue(index + 1);
  if (y > 0) enqueue(index - width);
  if (y + 1 < height) enqueue(index + width);
  if (x > 0 && y > 0) enqueue(index - width - 1);
  if (x + 1 < width && y > 0) enqueue(index - width + 1);
  if (x > 0 && y + 1 < height) enqueue(index + width - 1);
  if (x + 1 < width && y + 1 < height) enqueue(index + width + 1);
}

const rgba = Buffer.alloc(pixelCount * 4);
for (let index = 0; index < pixelCount; index += 1) {
  const sourceOffset = index * channels;
  const targetOffset = index * 4;
  rgba[targetOffset] = data[sourceOffset];
  rgba[targetOffset + 1] = data[sourceOffset + 1];
  rgba[targetOffset + 2] = data[sourceOffset + 2];
  rgba[targetOffset + 3] = background[index] ? 0 : 255;
}

await fs.mkdir(outputDir, { recursive: true });
const contactSheetPath = path.join(outputDir, "cute-eyes-source-clean.png");
await sharp(rgba, { raw: { width, height, channels: 4 } })
  .png({ compressionLevel: 9 })
  .toFile(contactSheetPath);

const columns = 4;
const rows = 2;
const sourceCellWidth = width / columns;
const sourceCellHeight = height / rows;

if (!Number.isInteger(sourceCellWidth) || !Number.isInteger(sourceCellHeight)) {
  throw new Error(`Source dimensions ${width}x${height} are not divisible by ${columns}x${rows}`);
}

const framesDir = path.join(outputDir, "frames");
await fs.mkdir(framesDir, { recursive: true });

for (let frame = 0; frame < columns * rows; frame += 1) {
  const left = (frame % columns) * sourceCellWidth;
  const top = Math.floor(frame / columns) * sourceCellHeight;
  const framePath = path.join(framesDir, `frame-${String(frame + 1).padStart(2, "0")}.png`);

  await sharp(rgba, { raw: { width, height, channels: 4 } })
    .extract({ left, top, width: sourceCellWidth, height: sourceCellHeight })
    .resize({ width: 768, height: 1024, fit: "fill", kernel: sharp.kernel.lanczos3 })
    .extend({
      left: 128,
      right: 128,
      top: 0,
      bottom: 0,
      background: { r: 0, g: 0, b: 0, alpha: 0 },
    })
    .png({ compressionLevel: 9 })
    .toFile(framePath);
}

console.log(`Cleaned source: ${contactSheetPath}`);
console.log(`Frames: ${framesDir} (8 x 1024x1024 RGBA)`);
