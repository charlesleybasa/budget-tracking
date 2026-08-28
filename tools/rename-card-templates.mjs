/*
 * Renames the bundled card templates away from real financial institutions.
 *
 * Pesolita ships in the Finance category, and an app that presents dozens of cards named
 * after real banks reads as claiming an association it does not have — a trademark exposure
 * under App Store guideline 5.2.1, and plausibly part of the 5.6 rejection. The artwork is
 * abstract and stays exactly as it is; only the names and the file slugs change, so nothing
 * in the product asserts a relationship with any institution.
 *
 * Names are derived from each template's own sampled colour so they describe the artwork
 * rather than being arbitrary. Pass --apply to write; without it this only prints the plan.
 */
import { readFileSync, writeFileSync, renameSync, existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const apply = process.argv.includes("--apply");
const manifestPath = join(root, "lib/cardTemplates.generated.ts");

const source = readFileSync(manifestPath, "utf8");
const header = source.slice(0, source.indexOf("["));
const templates = JSON.parse(source.replace(/^.*?=\s*/s, "").replace(/\s+as const;?\s*$/, ""));

/** Colour family from the artwork's own sampled pixel. */
function colourWord([r, g, b]) {
  const max = Math.max(r, g, b) / 255;
  const min = Math.min(r, g, b) / 255;
  const light = (max + min) / 2;
  const delta = max - min;
  if (delta < 0.08) {
    if (light < 0.2) return ["Obsidian", "Onyx", "Midnight"];
    if (light < 0.5) return ["Graphite", "Slate", "Pewter"];
    return ["Silver", "Chalk", "Frost"];
  }
  let hue;
  const [rn, gn, bn] = [r / 255, g / 255, b / 255];
  if (max === rn) hue = ((gn - bn) / delta) % 6;
  else if (max === gn) hue = (bn - rn) / delta + 2;
  else hue = (rn - gn) / delta + 4;
  hue = (hue * 60 + 360) % 360;
  if (hue < 15 || hue >= 345) return ["Crimson", "Scarlet", "Ember"];
  if (hue < 45) return ["Copper", "Rust", "Terracotta"];
  if (hue < 70) return ["Amber", "Gold", "Honey"];
  if (hue < 160) return ["Jade", "Fern", "Emerald"];
  if (hue < 200) return ["Teal", "Lagoon", "Aqua"];
  if (hue < 250) return light < 0.3 ? ["Navy", "Sapphire", "Deep Blue"] : ["Cobalt", "Azure", "Cerulean"];
  if (hue < 290) return ["Indigo", "Violet", "Iris"];
  return ["Plum", "Orchid", "Rose"];
}

const forms = {
  banks: ["Wave", "Ridge", "Arc", "Current", "Bearing", "Meridian", "Fold"],
  "credit-cards": ["Facet", "Prism", "Crest", "Edge", "Vertex"],
  "digital-banks": ["Pulse", "Signal", "Grid", "Node", "Circuit"],
  "e-wallets": ["Ripple", "Orbit", "Beam", "Loop", "Drift"],
  membership: ["Halo", "Star", "Emblem", "Token", "Marque"],
  prepaid: ["Track", "Lane", "Pass", "Route", "Transit"],
};

const slug = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
const taken = new Set();
const plan = [];

for (const template of templates) {
  const colours = colourWord(template.sample);
  const shapes = forms[template.category] ?? ["Card"];
  let name = null;
  outer: for (const shape of shapes) {
    for (const colour of colours) {
      const candidate = `${colour} ${shape}`;
      if (!taken.has(candidate)) { name = candidate; break outer; }
    }
  }
  name ??= `${colours[0]} ${shapes[0]} ${plan.length + 1}`;
  taken.add(name);
  plan.push({ template, name, id: `${template.category}/${slug(name)}` });
}

for (const { template, name, id } of plan) {
  console.log(`${template.name.padEnd(30)} → ${name.padEnd(20)} (${id})`);
}
console.log(`\n${plan.length} templates, ${taken.size} unique names`);

if (!apply) {
  console.log("\nDry run. Pass --apply to rename files and rewrite the manifests.");
  process.exit(0);
}

const roots = [join(root, "public/card-templates"), join(root, "ios/Pesolita/Pesolita/Resources/CardTemplates")];
for (const { template, name, id } of plan) {
  const oldLeaf = template.id.split("/")[1];
  const newLeaf = id.split("/")[1];
  for (const base of roots) {
    const from = join(base, template.category, `${oldLeaf}.webp`);
    const to = join(base, template.category, `${newLeaf}.webp`);
    if (existsSync(from) && from !== to) renameSync(from, to);
  }
  template.name = name;
  template.id = id;
  template.src = `/card-templates/${id}.webp`;
}

writeFileSync(manifestPath, `${header}${JSON.stringify(templates, null, 2)} as const;\n`);
console.log("\nRenamed files and rewrote lib/cardTemplates.generated.ts");
