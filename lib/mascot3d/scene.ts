import {
  ACESFilmicToneMapping,
  CanvasTexture,
  DirectionalLight,
  HemisphereLight,
  Mesh,
  MeshBasicMaterial,
  OrthographicCamera,
  PlaneGeometry,
  PMREMGenerator,
  Scene,
  SRGBColorSpace,
  WebGLRenderer,
} from "three";
import { RoomEnvironment } from "three/addons/environments/RoomEnvironment.js";

import { createMascot } from "./model";
import { CELEBRATION_SECONDS, sampleCelebration } from "./animation";
import { createCelebrationEffects } from "./effects";

/** Own every GPU resource and listener for one success overlay, including StrictMode remounts. */
export function mountCelebration(host: HTMLElement, onAvailability: (ready: boolean) => void) {
  const canvas = document.createElement("canvas");
  const motion = window.matchMedia("(prefers-reduced-motion: reduce)");
  const cleanup: Array<() => void> = [];
  let disposed = false;
  let frame = 0;
  let elapsed = 0;
  let previousTime: number | undefined;

  const stop = () => {
    cancelAnimationFrame(frame);
    frame = 0;
    previousTime = undefined;
  };
  const dispose = () => {
    if (disposed) return;
    disposed = true;
    stop();
    for (const release of cleanup.reverse()) release();
    canvas.remove();
  };

  try {
    const renderer = new WebGLRenderer({ canvas, alpha: true, antialias: true, powerPreference: "low-power" });
    cleanup.push(() => {
      renderer.dispose();
      renderer.forceContextLoss();
    });
    renderer.setClearColor(0x000000, 0);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.outputColorSpace = SRGBColorSpace;
    renderer.toneMapping = ACESFilmicToneMapping;
    renderer.toneMappingExposure = 0.8;

    const scene = new Scene();
    // Broad studio reflections give the large dark eyes a soft, dimensional highlight.
    const studio = new RoomEnvironment();
    const reflections = new PMREMGenerator(renderer);
    try {
      const environment = reflections.fromScene(studio, 0.025);
      scene.environment = environment.texture;
      scene.environmentIntensity = 0.35;
      cleanup.push(() => environment.dispose());
    } finally {
      studio.dispose();
      reflections.dispose();
    }
    const camera = new OrthographicCamera(-2.6, 2.6, 3.1, -3.1, 0.1, 30);
    camera.position.set(0, 2.65, 9);
    camera.lookAt(0, 2.12, 0);
    scene.add(new HemisphereLight(0xfff8ef, 0x765c49, 0.65));
    const key = new DirectionalLight(0xfff5e8, 1.6);
    key.position.set(-3, 6, 5);
    const fill = new DirectionalLight(0xeaf0ff, 0.55);
    fill.position.set(4, 3, 4);
    const rim = new DirectionalLight(0xffdfb5, 1.1);
    rim.position.set(2, 5, -4);
    scene.add(key, fill, rim);

    const mascot = createMascot();
    cleanup.push(mascot.dispose);
    scene.add(mascot.root);
    const effects = createCelebrationEffects();
    cleanup.push(effects.dispose);
    scene.add(effects.root);

    // A soft contact shadow grounds the hop without a shadow-map render on every frame.
    const shadowCanvas = document.createElement("canvas");
    shadowCanvas.width = shadowCanvas.height = 64;
    const context = shadowCanvas.getContext("2d");
    if (context) {
      const gradient = context.createRadialGradient(32, 32, 0, 32, 32, 32);
      gradient.addColorStop(0, "rgba(10, 22, 54, 0.32)");
      gradient.addColorStop(1, "rgba(10, 22, 54, 0)");
      context.fillStyle = gradient;
      context.fillRect(0, 0, 64, 64);
    }
    const shadowTexture = new CanvasTexture(shadowCanvas);
    const shadowMaterial = new MeshBasicMaterial({ map: shadowTexture, transparent: true, depthWrite: false });
    const shadowGeometry = new PlaneGeometry(2.8, 1.8);
    const shadow = new Mesh(shadowGeometry, shadowMaterial);
    shadow.rotation.x = -Math.PI / 2;
    shadow.position.y = -0.025;
    scene.add(shadow);
    cleanup.push(() => {
      shadowTexture.dispose();
      shadowMaterial.dispose();
      shadowGeometry.dispose();
    });

    const draw = () => {
      mascot.pose(elapsed, motion.matches);
      effects.pose(elapsed, motion.matches);
      camera.zoom = 1 / (1 - 0.05 * sampleCelebration(elapsed, motion.matches).push);
      camera.updateProjectionMatrix();
      const height = Math.max(0, mascot.root.position.y);
      shadow.scale.setScalar(1 - Math.min(height * 0.25, 0.22));
      shadowMaterial.opacity = 1 - Math.min(height * 0.6, 0.5);
      renderer.render(scene, camera);
    };
    const fail = () => {
      onAvailability(false);
      dispose();
    };
    const tick = (now: number) => {
      frame = 0;
      if (disposed || document.hidden) return;
      if (previousTime !== undefined) elapsed = Math.min(CELEBRATION_SECONDS, elapsed + (now - previousTime) / 1000);
      previousTime = now;
      try {
        draw();
      } catch {
        fail();
        return;
      }
      if (!motion.matches && elapsed < CELEBRATION_SECONDS) frame = requestAnimationFrame(tick);
    };
    const resume = () => {
      stop();
      if (disposed || document.hidden) return;
      try {
        draw();
      } catch {
        fail();
        return;
      }
      if (!motion.matches && elapsed < CELEBRATION_SECONDS) frame = requestAnimationFrame(tick);
    };
    const resize = () => {
      if (disposed) return;
      const width = Math.max(host.clientWidth, 1);
      const height = Math.max(host.clientHeight, 1);
      const halfWidth = 3.1 * (width / height);
      camera.left = -halfWidth;
      camera.right = halfWidth;
      camera.updateProjectionMatrix();
      renderer.setSize(width, height, false);
      resume();
    };
    const onContextLost = (event: Event) => {
      event.preventDefault();
      fail();
    };

    canvas.addEventListener("webglcontextlost", onContextLost);
    motion.addEventListener("change", resume);
    document.addEventListener("visibilitychange", resume);
    const observer = new ResizeObserver(resize);
    cleanup.push(() => {
      observer.disconnect();
      canvas.removeEventListener("webglcontextlost", onContextLost);
      motion.removeEventListener("change", resume);
      document.removeEventListener("visibilitychange", resume);
    });
    host.appendChild(canvas);
    observer.observe(host);
    resize();
    if (!disposed) onAvailability(true);
  } catch {
    dispose();
    onAvailability(false);
  }

  return dispose;
}
