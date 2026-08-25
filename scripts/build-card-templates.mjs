import { execFileSync } from "node:child_process";
import { readdirSync, mkdirSync, writeFileSync } from "node:fs";
import { basename, join, relative, resolve } from "node:path";

const sourceRoot = process.argv[2] ? resolve(process.argv[2]) : null;

if (!sourceRoot) {
  throw new Error("Usage: npm run templates:build -- /absolute/path/to/Card_Backgrounds_WebP_By_Category");
}

const projectRoot = resolve(import.meta.dirname, "..");
const publicRoot = join(projectRoot, "public", "card-templates");
const manifestPath = join(projectRoot, "lib", "cardTemplates.generated.ts");

const categories = [
  { folder: "Banks", id: "banks", label: "Banks", chip: true },
  { folder: "Credit_Cards", id: "credit-cards", label: "Credit Cards", chip: true },
  { folder: "Digital_Banks", id: "digital-banks", label: "Digital Banks", chip: false },
  { folder: "E_Wallets", id: "e-wallets", label: "E-wallets", chip: false },
  { folder: "Membership_Cards", id: "membership", label: "Membership", chip: false },
  { folder: "Prepaid_Cards", id: "prepaid", label: "Prepaid", chip: true },
];

const nameReplacements = new Map([
  ["7Eleven", "7-Eleven"],
  ["AllBank", "AllBank"],
  ["BanKo", "BanKo"],
  ["CoinsPH", "Coins.ph"],
  ["DigitalBank", "Digital Bank"],
  ["EastWest", "EastWest"],
  ["EveryDay", "Every Day"],
  ["EWallet", "E-wallet"],
  ["MariBank", "MariBank"],
  ["Metrobank", "Metrobank"],
  ["OwnBank", "OwnBank"],
  ["PalawanPay", "PalawanPay"],
  ["PayPal", "PayPal"],
  ["SecurityBank", "Security Bank"],
  ["ShopeePay", "ShopeePay"],
  ["UnionBank", "UnionBank"],
  ["UnionDigital", "UnionDigital"],
]);

function slugify(value) {
  return value
    .replace(/\.webp$/i, "")
    .replace(/_background$/i, "")
    .replace(/([a-z])([A-Z])/g, "$1-$2")
    .replace(/[^a-zA-Z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .toLowerCase();
}

function displayName(filename) {
  return filename
    .replace(/_background\.webp$/i, "")
    .split("_")
    .map((part) => nameReplacements.get(part) ?? part)
    .join(" ");
}

function linearChannel(value) {
  const channel = value / 255;
  return channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4;
}

function luminance(sample) {
  return 0.2126 * linearChannel(sample[0]) + 0.7152 * linearChannel(sample[1]) + 0.0722 * linearChannel(sample[2]);
}

function contrast(a, b) {
  const high = Math.max(a, b);
  const low = Math.min(a, b);
  return (high + 0.05) / (low + 0.05);
}

function measure(sample, key) {
  const strengths = { off: 0, soft: 0.32, strong: 0.55, veil: 0.5 };
  const alpha = strengths[key] * (key === "veil" ? 1 : 0.86);
  const rawLum = luminance(sample);
  const useDark = alpha === 0 && rawLum > 0.55;
  const scrimValue = useDark ? 255 : 0;
  const blended = sample.map((value) => value * (1 - alpha) + scrimValue * alpha);
  return contrast(luminance(blended), useDark ? 0 : 1);
}

function recommendedScrim(sample) {
  return ["off", "soft", "strong", "veil"].find((key) => measure(sample, key) >= 4.5) ?? "veil";
}

function sampleBalanceZone(imagePath) {
  const data = execFileSync("ffmpeg", [
    "-v",
    "error",
    "-i",
    imagePath,
    "-vf",
    "scale=64:40,crop=46:22:0:18",
    "-f",
    "rawvideo",
    "-pix_fmt",
    "rgb24",
    "pipe:1",
  ]);

  const sample = [0, 0, 0];
  const pixels = data.length / 3;
  for (let index = 0; index < data.length; index += 3) {
    sample[0] += data[index];
    sample[1] += data[index + 1];
    sample[2] += data[index + 2];
  }
  return sample.map((value) => Math.round(value / pixels));
}

function toHex(sample) {
  return `#${sample.map((value) => value.toString(16).padStart(2, "0")).join("")}`;
}

mkdirSync(publicRoot, { recursive: true });

const templates = [];

for (const category of categories) {
  const sourceDir = join(sourceRoot, category.folder);
  const outputDir = join(publicRoot, category.id);
  mkdirSync(outputDir, { recursive: true });

  const files = readdirSync(sourceDir)
    .filter((name) => name.toLowerCase().endsWith(".webp"))
    .sort((a, b) => a.localeCompare(b));

  for (const filename of files) {
    const sourcePath = join(sourceDir, filename);
    const outputName = `${slugify(filename)}.webp`;
    const outputPath = join(outputDir, outputName);

    // Every supplied source is 1920×1080. Crop the centre to the app's 320:196 card ratio,
    // then keep a 3× rendition for crisp card previews without decoding the full source.
    execFileSync("cwebp", [
      "-preset",
      "picture",
      "-q",
      "82",
      "-m",
      "6",
      "-mt",
      "-crop",
      "78",
      "0",
      "1764",
      "1080",
      "-resize",
      "960",
      "588",
      "-quiet",
      sourcePath,
      "-o",
      outputPath,
    ]);

    const sample = sampleBalanceZone(outputPath);
    templates.push({
      id: `${category.id}/${slugify(filename)}`,
      name: displayName(filename),
      category: category.id,
      src: `/card-templates/${category.id}/${outputName}`,
      focal: [0, 0],
      sample,
      fallback: toHex(sample),
      scrim: recommendedScrim(sample),
      textMode: "auto",
      chip: category.chip,
    });
  }
}

const ids = new Set(templates.map(({ id }) => id));
const sources = new Set(templates.map(({ src }) => src));
if (ids.size !== templates.length || sources.size !== templates.length) {
  throw new Error("Template IDs and public paths must be unique.");
}

const sourceNote = basename(sourceRoot);
const output = `/* Generated by scripts/build-card-templates.mjs from ${sourceNote}. */\n` +
  `export const CARD_TEMPLATE_DATA = ${JSON.stringify(templates, null, 2)} as const;\n`;

writeFileSync(manifestPath, output);
console.log(`Built ${templates.length} card templates in ${relative(projectRoot, publicRoot)}.`);
