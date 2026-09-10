import * as THREE from "three";

import { BURST_AT, LAND_AT, SOURCE_SCALE, sampleCelebration } from "./animation";

type Kind = "coin" | "star" | "confetti" | "dust" | "wave";

/** The supplied celebration's burst and landing effects, sampled without a live simulation. */
export function createCelebrationEffects() {
  const root = new THREE.Group();
  root.name = "Celebration coins and confetti";
  root.scale.setScalar(SOURCE_SCALE);
  const geometries = new Set<THREE.BufferGeometry>();
  const materials = new Set<THREE.Material>();
  const particles: Array<{
    object: THREE.Object3D;
    materials: THREE.MeshStandardMaterial[];
    kind: Kind;
    start: number;
    life: number;
    base: number;
    gravity: number;
    position: THREE.Vector3;
    velocity: THREE.Vector3;
    spin: THREE.Vector3;
  }> = [];

  let seed = 617;
  function random(min: number, max: number) {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    return min + seed / 4294967296 * (max - min);
  }
  function geometry<T extends THREE.BufferGeometry>(value: T): T {
    geometries.add(value);
    return value;
  }
  function material(color: number, emissive = 0, metalness = 0) {
    const value = new THREE.MeshStandardMaterial({
      color, emissive, emissiveIntensity: 0.7, roughness: 0.35, metalness,
      transparent: true, side: THREE.DoubleSide,
    });
    materials.add(value);
    return value;
  }

  const coinGeometry = geometry(new THREE.CylinderGeometry(0.055, 0.055, 0.016, 24));
  const rimGeometry = geometry(new THREE.TorusGeometry(0.0505, 0.0055, 6, 24));
  const glyph = new THREE.Shape();
  glyph.moveTo(-0.018, -0.028);
  glyph.lineTo(-0.008, -0.028);
  glyph.lineTo(-0.008, -0.002);
  glyph.bezierCurveTo(0.036, -0.002, 0.036, 0.028, -0.008, 0.028);
  glyph.lineTo(-0.018, 0.028);
  glyph.closePath();
  const counter = new THREE.Path();
  counter.moveTo(-0.008, 0.018);
  counter.bezierCurveTo(0.017, 0.018, 0.017, 0.008, -0.008, 0.008);
  counter.closePath();
  glyph.holes.push(counter);
  const glyphGeometry = geometry(new THREE.ShapeGeometry(glyph, 10));
  const barGeometry = geometry(new THREE.PlaneGeometry(0.049, 0.004));
  const star = new THREE.Shape();
  for (let index = 0; index < 8; index++) {
    const angle = index / 8 * Math.PI * 2;
    const radius = index % 2 ? 0.013 : 0.046;
    if (index === 0) star.moveTo(Math.cos(angle) * radius, Math.sin(angle) * radius);
    else star.lineTo(Math.cos(angle) * radius, Math.sin(angle) * radius);
  }
  star.closePath();
  const starGeometry = geometry(new THREE.ShapeGeometry(star));
  const confettiGeometry = geometry(new THREE.PlaneGeometry(0.032, 0.052));
  const dustGeometry = geometry(new THREE.SphereGeometry(0.042, 12, 10));
  const waveGeometry = geometry(new THREE.TorusGeometry(0.16, 0.014, 8, 48));
  const palette = [0xffca28, 0x1d6ff2, 0x78bc8b, 0xe79a87];
  const centerY = 0.98 + sampleCelebration(BURST_AT).rootY * 0.4;

  for (const [kind, count] of [["coin", 12], ["star", 11], ["confetti", 20], ["dust", 7], ["wave", 1]] as const) {
    for (let index = 0; index < count; index++) {
      const object = new THREE.Group();
      object.name = `${kind} ${index + 1}`;
      const finishes: THREE.MeshStandardMaterial[] = [];
      const add = (shape: THREE.BufferGeometry, finish: THREE.MeshStandardMaterial) => {
        if (!finishes.includes(finish)) finishes.push(finish);
        const mesh = new THREE.Mesh(shape, finish);
        object.add(mesh);
        return mesh;
      };
      if (kind === "coin") {
        add(coinGeometry, material(0xffca28, 0, 0.35)).rotation.x = Math.PI / 2;
        add(rimGeometry, material(0xdfa016, 0, 0.35)).position.z = 0.008;
        const ink = material(0xb87512);
        add(glyphGeometry, ink).position.z = 0.009;
        for (const y of [0.008, 0.017]) add(barGeometry, ink).position.set(0, y, 0.01);
      } else if (kind === "star") add(starGeometry, material(0xffd75a, 0xffb422));
      else if (kind === "confetti") add(confettiGeometry, material(palette[index % 4]));
      else if (kind === "dust") add(dustGeometry, material(0xfff3e2, 0xffeacd));
      else add(waveGeometry, material(0xffd066, 0xffa726)).rotation.x = -Math.PI / 2;
      if (kind === "dust" || kind === "wave") finishes.forEach(finish => { finish.depthWrite = false; });

      const angle = index / count * Math.PI * 2 + random(-0.25, 0.25);
      const position = new THREE.Vector3(Math.cos(angle) * 0.2, centerY + random(-0.12, 0.16), Math.sin(angle) * 0.14);
      const velocity = new THREE.Vector3(Math.cos(angle) * random(0.5, 0.95), random(1.1, 1.85), Math.sin(angle) * random(0.35, 0.7));
      const spin = new THREE.Vector3(random(-5, 5), random(4, 11), random(-3, 3));
      let start = BURST_AT + index * 0.02;
      let life = random(1.25, 1.55);
      let base = random(0.85, 1.15);
      let gravity = 3.6;
      if (kind === "star") {
        const radius = random(0.46, 0.78);
        position.set(Math.cos(angle) * radius, centerY + random(-0.3, 0.42), Math.sin(angle) * radius * 0.7);
        velocity.set(Math.cos(angle) * 0.16, random(0.1, 0.4), Math.sin(angle) * 0.1);
        spin.set(0, 0, random(-1.6, 1.6));
        start = BURST_AT + index * 0.045;
        life = random(0.65, 0.95); base = random(0.6, 1.05); gravity = 0;
      } else if (kind === "confetti") {
        position.set(Math.cos(angle) * 0.3, centerY + random(0, 0.5), Math.sin(angle) * 0.22);
        velocity.set(Math.cos(angle) * random(0.5, 1.15), random(0.75, 1.45), Math.sin(angle) * random(0.35, 0.8));
        spin.set(random(-8, 8), random(-8, 8), random(-8, 8));
        start = BURST_AT + index * 0.012;
        life = random(1.3, 1.7); base = random(0.8, 1.3); gravity = 2.3;
      } else if (kind === "dust" || kind === "wave") {
        position.set(Math.cos(angle) * 0.14, 0.03, Math.sin(angle) * 0.12);
        velocity.set(Math.cos(angle) * random(0.55, 1), random(0.14, 0.34), Math.sin(angle) * random(0.4, 0.7));
        spin.set(0, 0, 0);
        start = LAND_AT; life = random(0.4, 0.6); base = random(0.5, 0.85); gravity = 0.4;
        if (kind === "wave") {
          position.set(0, 0.012, 0); velocity.set(0, 0, 0);
          life = 0.5; base = 1; gravity = 0;
        }
      }
      // Match the source's clear space around the face.
      if (kind !== "dust" && kind !== "wave" && position.z > 0.16 && Math.abs(position.x) < 0.34 && position.y < 1.3) {
        position.x += (position.x >= 0 ? 1 : -1) * 0.3;
        position.z += 0.16;
      }
      object.visible = false;
      root.add(object);
      particles.push({ object, materials: finishes, kind, start, life, base, gravity, position, velocity, spin });
    }
  }

  return {
    root,
    pose(seconds: number, reducedMotion: boolean) {
      root.visible = !reducedMotion;
      for (const p of particles) {
        const age = seconds - p.start;
        p.object.visible = !reducedMotion && age >= 0 && age < p.life;
        if (!p.object.visible) continue;
        p.object.position.copy(p.position).addScaledVector(p.velocity, age);
        p.object.position.y -= 0.5 * p.gravity * age * age;
        p.object.rotation.set(p.spin.x * age, p.spin.y * age, p.spin.z * age);
        const fadeIn = Math.min(age / 0.1, 1);
        const fadeOut = Math.min((p.life - age) / 0.3, 1);
        let scale = p.base * (1 + 2 * (fadeIn - 1) ** 3 + 1.2 * (fadeIn - 1) ** 2) * (1 - (1 - fadeOut) ** 2);
        if (p.kind === "star") scale *= 0.85 + 0.3 * Math.sin(age * 16);
        if (p.kind === "dust") scale = p.base * (0.5 + 2.2 * (1 - (1 - age / p.life) ** 3));
        if (p.kind === "wave") scale = 0.35 + 2.4 * (1 - (1 - age / p.life) ** 3);
        p.object.scale.setScalar(Math.max(scale, 0.001));
        const opacity = p.kind === "dust" ? 0.2 * (1 - age / p.life) : p.kind === "wave" ? 0.4 * (1 - age / p.life) : fadeOut;
        p.materials.forEach(finish => { finish.opacity = opacity; });
      }
    },
    dispose() {
      geometries.forEach(value => value.dispose());
      materials.forEach(value => value.dispose());
      geometries.clear(); materials.clear(); root.clear();
    },
  };
}
