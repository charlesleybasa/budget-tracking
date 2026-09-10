import * as THREE from "three";

import { CELEBRATION_SECONDS, SOURCE_SCALE, sampleAntennaSpring, sampleCelebration } from "./animation";

type Point = readonly [number, number, number];

export interface MascotModel {
  root: THREE.Group;
  pose: (seconds: number, reducedMotion: boolean) => void;
  dispose: () => void;
}

/** Sculpted to the supplied Pesolita storyboard and face close-up. */
export function createMascot(): MascotModel {
  const root = new THREE.Group();
  root.name = "Pesolita";
  const geometries = new Set<THREE.BufferGeometry>();
  const materials = new Set<THREE.Material>();

  function geometry<T extends THREE.BufferGeometry>(value: T): T {
    geometries.add(value);
    return value;
  }

  function material<T extends THREE.Material>(value: T): T {
    materials.add(value);
    return value;
  }

  function satin(color: number, roughness = 0.65) {
    return material(new THREE.MeshStandardMaterial({ color, roughness }));
  }

  function softFinish(color: number, roughness = 0.52) {
    return material(new THREE.MeshPhysicalMaterial({
      color, roughness, clearcoat: 0.22, clearcoatRoughness: 0.48,
      sheen: 0.22, sheenColor: 0xffd7ad, sheenRoughness: 0.75,
    }));
  }
  const skin = softFinish(0xb97743);
  const limbSkin = softFinish(0xa36637, 0.56);
  const antennaColor = softFinish(0x844022, 0.49);
  const shellColor = softFinish(0x66351d, 0.57);
  const shellLeft = softFinish(0x754022, 0.55);
  const shellRight = softFinish(0x703b20, 0.55);
  const shellSeam = satin(0x5c3b25, 0.74);
  const bellyColor = softFinish(0xd58c45, 0.59);
  bellyColor.vertexColors = true;
  const blush = softFinish(0xef8275, 0.68);
  const eyeOutline = satin(0x341b10, 0.36);
  const white = material(new THREE.MeshPhysicalMaterial({
    color: 0xfffaf1, roughness: 0.3, clearcoat: 0.3, clearcoatRoughness: 0.25,
  }));
  const iris = material(new THREE.MeshPhysicalMaterial({
    color: 0xffffff, vertexColors: true, roughness: 0.27, clearcoat: 0.3, clearcoatRoughness: 0.2,
  }));
  const pupil = material(new THREE.MeshPhysicalMaterial({
    color: 0x120905, roughness: 0.3, clearcoat: 0.2,
  }));
  const glint = material(new THREE.MeshBasicMaterial({ color: 0xfffcf5, toneMapped: false }));
  const mouthColor = material(new THREE.MeshBasicMaterial({ color: 0x31090a }));
  const tongueColor = satin(0xf5757c, 0.55);
  const green = softFinish(0x439b52, 0.51);
  const greenEdge = softFinish(0x32733c, 0.56);
  const greenLight = softFinish(0x61af65, 0.54);
  const gold = material(new THREE.MeshStandardMaterial({
    color: 0xf4dc96, roughness: 0.55, metalness: 0.05,
  }));

  // Most soft forms share this geometry, including the tiny fingers.
  const sphereGeometry = geometry(new THREE.SphereGeometry(1, 32, 24));

  function mesh(
    parent: THREE.Object3D,
    shape: THREE.BufferGeometry,
    finish: THREE.Material,
    name: string,
    position: Point = [0, 0, 0],
  ) {
    const object = new THREE.Mesh(shape, finish);
    object.name = name;
    object.position.set(...position);
    object.castShadow = true;
    object.receiveShadow = true;
    parent.add(object);
    return object;
  }

  function oval(
    parent: THREE.Object3D,
    name: string,
    position: Point,
    scale: Point,
    finish: THREE.Material,
  ) {
    const object = mesh(parent, sphereGeometry, finish, name, position);
    object.scale.set(...scale);
    return object;
  }

  function curve(
    parent: THREE.Object3D,
    name: string,
    points: Point[],
    radius: number,
    finish: THREE.Material,
    closed = false,
    segments = 32,
  ) {
    const path = new THREE.CatmullRomCurve3(
      points.map((point) => new THREE.Vector3(...point)), closed, "centripetal",
    );
    return mesh(parent, geometry(new THREE.TubeGeometry(path, segments, radius, 8, closed)), finish, name);
  }

  const body = new THREE.Group();
  body.name = "Body";
  const bodyPivot = new THREE.Group();
  bodyPivot.position.y = 0.33;
  body.position.y = -0.33;
  bodyPivot.add(body);
  root.add(bodyPivot);

  oval(body, "Round abdomen", [0, 0.94, 0], [0.84, 0.72, 0.54], limbSkin);

  // The full shell remains visible in three-quarter views and when the body turns.
  const shellCenter: Point = [0, 1.02, -0.35];
  const shellSize: Point = [0.87, 0.9, 0.58];
  oval(body, "Shell rim", shellCenter, shellSize, shellColor);
  for (const [index, finish] of [shellLeft, shellRight].entries()) {
    const panel = mesh(body, geometry(new THREE.SphereGeometry(
      1, 24, 30, Math.PI + index * Math.PI / 2, Math.PI / 2,
    )), finish, `Wing ${index + 1}`, shellCenter);
    panel.scale.set(0.874, 0.904, 0.584);
  }

  function backZ(x: number, y: number) {
    return -0.35 - 0.586 * Math.sqrt(Math.max(
      0, 1 - (x / 0.874) ** 2 - ((y - 1.02) / 0.904) ** 2,
    ));
  }

  const shellOutline: Point[] = Array.from({ length: 49 }, (_, index) => {
    const angle = index / 49 * Math.PI * 2;
    return [Math.sin(angle) * 0.872, 1.02 + Math.cos(angle) * 0.902, -0.35];
  });
  curve(body, "Wing piping", shellOutline, 0.014, shellSeam, true, 64);
  curve(body, "Central wing seam", Array.from({ length: 25 }, (_, index) => {
    const y = 0.13 + index / 24 * 1.78;
    return [0, y, backZ(0, y) - 0.005];
  }), 0.012, shellSeam);
  for (const side of [-1, 1]) {
    for (const height of [1.36]) {
      const points: Point[] = Array.from({ length: 15 }, (_, index) => {
        const progress = index / 14;
        const x = side * progress * 0.76;
        const y = height + progress * 0.17;
        return [x, y, backZ(x, y) - 0.007];
      });
      curve(body, "Wing vein", points, 0.012, shellSeam, false, 32);
    }
  }

  // Broad, shallow sculpted bands replace the old raised, metallic-looking wires.
  const bellyGeometry = geometry(new THREE.SphereGeometry(1, 64, 96));
  const bellyVertices = bellyGeometry.getAttribute("position");
  const bellyShading = new Float32Array(bellyVertices.count * 3);
  for (let index = 0; index < bellyVertices.count; index++) {
    const x = bellyVertices.getX(index) * 0.755;
    const y = 0.96 + bellyVertices.getY(index) * 0.65;
    let z = bellyVertices.getZ(index) * 0.33;
    let shade = 1;
    if (z > 0) {
      for (const seam of [0.56, 0.81, 1.07, 1.33]) {
        const distance = (y - seam - 0.07 * (x / 0.755) ** 2) / 0.024;
        const groove = Math.exp(-distance * distance) * Math.min(1, z / 0.12);
        z -= 0.024 * groove;
        shade -= 0.18 * groove;
      }
    }
    bellyVertices.setXYZ(index, x, y, 0.34 + z);
    bellyShading.set([shade, shade, shade], index * 3);
  }
  bellyGeometry.setAttribute("color", new THREE.BufferAttribute(bellyShading, 3));
  bellyGeometry.computeVertexNormals();
  mesh(body, bellyGeometry, bellyColor, "Soft segmented golden belly");

  const legs: THREE.Group[] = [];
  for (const side of [-1, 1]) {
    const leg = new THREE.Group();
    leg.name = side < 0 ? "Left foot pivot" : "Right foot pivot";
    leg.position.set(side * 0.43, 0.36, 0.035);
    root.add(leg);
    oval(leg, "Little leg", [0, -0.055, 0], [0.245, 0.285, 0.25], limbSkin);
    oval(leg, "Rounded foot", [side * 0.015, -0.24, 0.125], [0.245, 0.12, 0.31], limbSkin);
    for (const toe of [-1, 1]) {
      const crease: Point[] = Array.from({ length: 9 }, (_, index) => {
        const x = toe * 0.077;
        const y = -0.267 + index / 8 * 0.062;
        const z = 0.125 + 0.312 * Math.sqrt(1 - (x / 0.245) ** 2 - ((y + 0.24) / 0.12) ** 2);
        return [side * 0.015 + x, y, z];
      });
      curve(leg, "Shallow toe crease", crease, 0.0045, antennaColor, false, 12);
    }
    legs.push(leg);
  }

  const arms: THREE.Group[] = [];
  const wrists: THREE.Group[] = [];
  for (const side of [-1, 1]) {
    const arm = new THREE.Group();
    arm.name = side < 0 ? "Left shoulder" : "Waving shoulder";
    arm.position.set(side * 0.79, 1.51, 0.045);
    body.add(arm);
    // One tapered surface prevents visible ball-joint seams through the arm.
    const armGeometry = geometry(new THREE.SphereGeometry(1, 32, 32));
    const armVertices = armGeometry.getAttribute("position");
    for (let index = 0; index < armVertices.count; index++) {
      const longitudinal = armVertices.getY(index);
      const radius = 0.165 + longitudinal * 0.025;
      armVertices.setXYZ(
        index,
        armVertices.getX(index) * radius + side * (1 - longitudinal) * 0.093,
        longitudinal * 0.33 - 0.24,
        armVertices.getZ(index) * radius + (1 - longitudinal) * 0.046,
      );
    }
    armGeometry.computeVertexNormals();
    mesh(arm, armGeometry, limbSkin, "Smooth tapered arm");
    const wrist = new THREE.Group();
    wrist.name = "Wrist";
    wrist.position.set(side * 0.19, -0.535, 0.1);
    arm.add(wrist);
    oval(wrist, "Palm", [0, -0.032, 0], [0.165, 0.176, 0.143], limbSkin);
    oval(wrist, "Thumb", [-side * 0.123, 0.012, 0.075], [0.073, 0.11, 0.076], limbSkin);
    for (const finger of [-1, 0, 1]) {
      oval(wrist, "Finger", [finger * 0.088, -0.147 + Math.abs(finger) * 0.015, 0.025], [0.062, 0.106, 0.084], limbSkin);
    }
    arms.push(arm);
    wrists.push(wrist);
  }

  for (const side of [-1, 1]) {
    const cord: Point[] = [
      [side * 0.57, 1.64, 0.4],
      [side * 0.42, 1.48, 0.55],
      [side * 0.2, 1.28, 0.664],
      [0, 1.19, 0.71],
    ];
    curve(body, "Leather necklace cord", cord, 0.027, antennaColor);
  }

  const pendant = new THREE.Group();
  pendant.name = "Peso pouch pendant";
  pendant.position.set(0, 1.23, 0.72);
  body.add(pendant);
  oval(pendant, "Pendant dark edge", [0, -0.245, 0.005], [0.268, 0.284, 0.071], greenEdge);
  oval(pendant, "Pendant face", [0, -0.24, 0.033], [0.247, 0.26, 0.065], green);
  oval(pendant, "Pouch neck", [0, 0.015, 0.015], [0.11, 0.063, 0.064], greenEdge);
  for (const knot of [-1, 0, 1]) {
    const lobe = oval(pendant, "Pouch knot", [knot * 0.066, 0.042, 0.04], [0.048, 0.067, 0.045], knot === 0 ? greenLight : green);
    lobe.rotation.z = -knot * 0.22;
  }

  // A beveled, raised ₱ mark keeps the accessory dimensional even in profile.
  const peso = new THREE.Shape();
  peso.moveTo(-0.071, -0.145);
  peso.lineTo(-0.015, -0.145);
  peso.lineTo(-0.015, -0.013);
  peso.lineTo(0.019, -0.013);
  peso.quadraticCurveTo(0.125, -0.013, 0.125, 0.071);
  peso.quadraticCurveTo(0.125, 0.15, 0.019, 0.15);
  peso.lineTo(-0.071, 0.15);
  peso.closePath();
  const counter = new THREE.Path();
  counter.moveTo(-0.015, 0.097);
  counter.lineTo(0.014, 0.097);
  counter.quadraticCurveTo(0.069, 0.097, 0.069, 0.067);
  counter.quadraticCurveTo(0.069, 0.034, 0.014, 0.034);
  counter.lineTo(-0.015, 0.034);
  counter.closePath();
  peso.holes.push(counter);
  const extrudeOptions = { depth: 0.016, bevelEnabled: true, bevelSegments: 2, steps: 1, bevelSize: 0.004, bevelThickness: 0.004, curveSegments: 12 };
  mesh(pendant, geometry(new THREE.ExtrudeGeometry(peso, extrudeOptions)), gold, "Raised peso", [-0.021, -0.25, 0.096]);
  for (const barHeight of [0.041, 0.085]) {
    const bar = new THREE.Shape();
    bar.moveTo(-0.103, barHeight);
    bar.lineTo(0.145, barHeight);
    bar.lineTo(0.145, barHeight + 0.014);
    bar.lineTo(-0.103, barHeight + 0.014);
    bar.closePath();
    mesh(pendant, geometry(new THREE.ExtrudeGeometry(bar, extrudeOptions)), gold, "Peso crossbar", [-0.021, -0.25, 0.11]);
  }

  const head = new THREE.Group();
  head.name = "Head";
  head.position.set(0, 2.3, 0.17);
  body.add(head);

  // The close-up has a round forehead and soft, full cheeks with a curved chin.
  // Keep the face projection below on this same surface equation.
  const headWidth = 1.055;
  const headHeight = 0.92;
  const headDepth = 0.8;
  const horizontalPower = 2.05;
  const depthPower = 2.15;
  const verticalPower = (y: number) => y < 0 ? 2.5 : 2.0;
  const foreheadWidth = (y: number) => {
    const height = y / headHeight;
    return headWidth * (1 - 0.05 * (height + Math.sqrt(height * height + 0.04)));
  };
  const signedPower = (value: number, power: number) => Math.sign(value) * Math.abs(value) ** power;
  const headGeometry = geometry(new THREE.SphereGeometry(1, 96, 72));
  const headVertices = headGeometry.getAttribute("position");
  for (let index = 0; index < headVertices.count; index++) {
    const rawX = headVertices.getX(index);
    const rawY = headVertices.getY(index);
    const rawZ = headVertices.getZ(index);
    // Sample the chin evenly in height; stretching latitude rows leaves a
    // visible shading band where the round forehead meets the fuller cheeks.
    const y = headHeight * rawY;
    const ring = Math.sqrt(Math.max(0, 1 - rawY * rawY));
    const fullness = Math.max(0, 1 - Math.abs(rawY) ** verticalPower(y));
    headVertices.setXYZ(
      index,
      ring > 0.00001 ? foreheadWidth(y) * signedPower(rawX / ring, 2 / horizontalPower) * fullness ** (1 / horizontalPower) : 0,
      y,
      ring > 0.00001 ? headDepth * signedPower(rawZ / ring, 2 / depthPower) * fullness ** (1 / depthPower) : 0,
    );
  }
  headGeometry.computeVertexNormals();
  mesh(head, headGeometry, skin, "Round head with soft cheeks");

  function faceZ(x: number, y: number, offset = 0) {
    return headDepth * Math.max(
      0,
      1 - Math.abs(x / foreheadWidth(y)) ** horizontalPower
        - Math.abs(y / headHeight) ** verticalPower(y),
    ) ** (1 / depthPower) + offset;
  }

  const eyes: THREE.Group[] = [];
  const happyEyes: THREE.Object3D[] = [];
  for (const side of [-1, 1]) {
    const eye = new THREE.Group();
    eye.name = side < 0 ? "Left eye" : "Right eye";
    eye.position.set(side * 0.5, 0.055, faceZ(side * 0.5, 0.055));
    head.add(eye);

    // Wrap the whole eye onto the face: an embedded ellipsoid hides its outer
    // white rim inside the cheek, making the eyes appear too small and inset.
    function eyeSurface(name: string, center: Point, size: Point, finish: THREE.Material) {
      const surface = geometry(new THREE.SphereGeometry(1, 40, 32));
      const vertices = surface.getAttribute("position");
      for (let index = 0; index < vertices.count; index++) {
        const x = vertices.getX(index) * size[0] + center[0];
        const y = vertices.getY(index) * size[1] + center[1];
        const z = faceZ(x + eye.position.x, y + eye.position.y)
          - eye.position.z + (center[2] + vertices.getZ(index) * size[2]) * 0.65;
        vertices.setXYZ(index, x, y, z);
      }
      surface.computeVertexNormals();
      if (finish === iris) {
        const colors = new Float32Array(vertices.count * 3);
        const dark = new THREE.Color(0x3a210e);
        const warm = new THREE.Color(0xc17929);
        const color = new THREE.Color();
        for (let index = 0; index < vertices.count; index++) {
          const x = (vertices.getX(index) - center[0]) / size[0];
          const y = (vertices.getY(index) - center[1]) / size[1];
          const radius = Math.sqrt(x * x + y * y);
          const edge = 1 - THREE.MathUtils.smoothstep(radius, 0.86, 1);
          color.copy(dark).lerp(warm, edge * (0.48 + 0.46 * Math.max(0, -y)));
          colors.set([color.r, color.g, color.b], index * 3);
        }
        surface.setAttribute("color", new THREE.BufferAttribute(colors, 3));
      }
      return mesh(eye, surface, finish, name);
    }
    eyeSurface("Eye fine outline", [0, 0, 0.012], [0.301, 0.331, 0.085], eyeOutline);
    eyeSurface("Ivory eye", [0, -0.002, 0.024], [0.29, 0.317, 0.093], white);
    eyeSurface("Warm brown iris", [-side * 0.024, -0.032, 0.089], [0.226, 0.251, 0.086], iris);
    eyeSurface("Dark round pupil", [-side * 0.024, 0.027, 0.15], [0.169, 0.181, 0.049], pupil);
    eyeSurface("Bright eye catchlight", [0.065 - side * 0.024, 0.105, 0.2], [0.068, 0.073, 0.008], glint);
    eyeSurface("Small eye catchlight", [-0.063 - side * 0.024, -0.096, 0.192], [0.024, 0.026, 0.008], glint);
    eye.traverse((part) => {
      if (part instanceof THREE.Mesh) {
        part.castShadow = false;
        part.receiveShadow = false;
      }
    });
    eyes.push(eye);

    const squintPoints: Point[] = Array.from({ length: 19 }, (_, index) => {
      const progress = index / 18;
      const x = side * 0.5 + (progress - 0.5) * 0.43;
      const y = -0.035 + Math.sin(progress * Math.PI) * 0.125;
      return [x, y, faceZ(x, y, 0.036)];
    });
    const happyEye = curve(head, "Happy closed eye", squintPoints, 0.034, eyeOutline, false, 32);
    happyEye.visible = false;
    happyEyes.push(happyEye);

    const browPoints: Point[] = Array.from({ length: 9 }, (_, index) => {
      const p = index / 8;
      const x = side * (0.365 + p * 0.23);
      const y = 0.59 + Math.sin(p * Math.PI) * 0.035 - p * 0.025;
      return [x, y, faceZ(x, y, 0.016)];
    });
    curve(head, "Friendly eyebrow", browPoints, 0.029, eyeOutline, false, 24);
    oval(head, "Soft inner brow tip", browPoints[0], [0.029, 0.029, 0.022], eyeOutline);
    oval(head, "Soft outer brow tip", browPoints[browPoints.length - 1], [0.029, 0.029, 0.022], eyeOutline);
    const cheek = oval(head, "Rosy cheek", [side * 0.76, -0.285, faceZ(side * 0.76, -0.285, -0.012)], [0.174, 0.114, 0.037], blush);
    cheek.rotation.y = side * 0.55;
    cheek.rotation.z = -side * 0.1;
    cheek.castShadow = false;
    cheek.receiveShadow = false;
  }

  const mouthParts: THREE.Mesh[] = [];
  function faceShape(name: string, shape: THREE.Shape, finish: THREE.Material, originY: number, offset: number) {
    const outline = new THREE.ShapeGeometry(shape, 28);
    const positions = outline.getAttribute("position");
    const indices = outline.getIndex();
    const vertices: number[] = [];

    // Subdivide before bending onto the cheek. Flat, boundary-only triangles
    // would cut through the curved head and hide the middle of the smile.
    function triangle(a: THREE.Vector2, b: THREE.Vector2, c: THREE.Vector2, depth: number) {
      if (depth > 0) {
        const ab = a.clone().lerp(b, 0.5);
        const bc = b.clone().lerp(c, 0.5);
        const ca = c.clone().lerp(a, 0.5);
        triangle(a, ab, ca, depth - 1);
        triangle(ab, b, bc, depth - 1);
        triangle(ca, bc, c, depth - 1);
        triangle(ab, bc, ca, depth - 1);
      } else {
        for (const point of [a, b, c]) {
          const y = point.y + originY;
          vertices.push(point.x, y, faceZ(point.x, y, offset));
        }
      }
    }

    const vertexCount = indices?.count ?? positions.count;
    for (let index = 0; index < vertexCount; index += 3) {
      const points = [0, 1, 2].map((corner) => {
        const vertex = indices ? indices.getX(index + corner) : index + corner;
        return new THREE.Vector2(positions.getX(vertex), positions.getY(vertex));
      });
      triangle(points[0], points[1], points[2], 3);
    }
    outline.dispose();
    const shapeGeometry = geometry(new THREE.BufferGeometry());
    // Reproject both mouth poses onto the round face so the animated smile
    // stays on the surface instead of clipping through the cheeks.
    const poseVertices = (open: number) => vertices.map((value, index) => {
      const base = index - index % 3;
      const x = vertices[base] * (0.94 + 0.18 * open);
      const y = originY + (vertices[base + 1] - originY) * (0.66 + 0.52 * open);
      return index % 3 === 0 ? x : index % 3 === 1 ? y : faceZ(x, y, offset + 0.01);
    });
    shapeGeometry.setAttribute("position", new THREE.Float32BufferAttribute(poseVertices(0), 3));
    shapeGeometry.computeVertexNormals();
    const openGeometry = new THREE.BufferGeometry();
    openGeometry.setAttribute("position", new THREE.Float32BufferAttribute(poseVertices(1), 3));
    openGeometry.computeVertexNormals();
    shapeGeometry.morphAttributes.position = [openGeometry.getAttribute("position").clone()];
    shapeGeometry.morphAttributes.normal = [openGeometry.getAttribute("normal").clone()];
    openGeometry.dispose();
    const object = mesh(head, shapeGeometry, finish, name);
    object.castShadow = false;
    object.receiveShadow = false;
    mouthParts.push(object);
    return object;
  }

  const smile = new THREE.Shape();
  smile.moveTo(-0.262, 0.07);
  smile.quadraticCurveTo(0, -0.065, 0.262, 0.07);
  smile.bezierCurveTo(0.22, -0.175, 0.125, -0.3, 0, -0.305);
  smile.bezierCurveTo(-0.125, -0.3, -0.22, -0.175, -0.262, 0.07);
  faceShape("Open happy smile", smile, mouthColor, -0.255, 0.016);

  const tongue = new THREE.Shape();
  tongue.moveTo(-0.129, -0.22);
  tongue.quadraticCurveTo(0, -0.112, 0.129, -0.22);
  tongue.quadraticCurveTo(0.09, -0.281, 0, -0.287);
  tongue.quadraticCurveTo(-0.09, -0.281, -0.129, -0.22);
  faceShape("Little pink tongue", tongue, tongueColor, -0.255, 0.023);

  const antennae: THREE.Group[] = [];
  for (const side of [-1, 1]) {
    const antenna = new THREE.Group();
    antenna.name = "Springy antenna";
    antenna.position.set(side * 0.21, 0.865, -0.055);
    head.add(antenna);
    const antennaPoints: Point[] = side < 0 ? [
      [0, 0, 0],
      [-0.135, 0.36, -0.015],
      [-0.47, 0.76, -0.02],
      [-0.85, 0.84, 0.015],
      [-1.2, 0.65, 0.048],
      [-1.27, 0.2, 0.07],
    ] : [
      [0, 0, 0],
      [0.025, 0.25, -0.015],
      [0.12, 0.5, -0.01],
      [0.25, 0.59, 0.015],
      [0.35, 0.56, 0.04],
    ];
    curve(antenna, "Curled antenna", antennaPoints, 0.054, antennaColor, false, 48);
    oval(antenna, "Rounded antenna tip", antennaPoints[antennaPoints.length - 1], [0.054, 0.054, 0.054], antennaColor);
    antennae.push(antenna);
  }
  curve(head, "Center tuft", [
    [0.023, 0.893, -0.03], [0.009, 1.048, -0.021], [-0.072, 1.125, 0], [-0.154, 1.111, 0.03],
  ], 0.032, antennaColor, false, 24);
  oval(head, "Tuft tip", [-0.154, 1.111, 0.03], [0.032, 0.032, 0.032], antennaColor);

  function pose(seconds: number, reducedMotion: boolean) {
    const pose = sampleCelebration(seconds, reducedMotion);
    const { time: t, squash, armRaise: raise, happy, crouch, lean, perk } = pose;
    const phase = t / CELEBRATION_SECONDS * Math.PI * 2;
    const air = THREE.MathUtils.clamp(pose.rootY / 0.28, 0, 1);
    const sxz = Math.pow(1 / squash, 0.62);
    root.position.y = pose.rootY * SOURCE_SCALE;
    root.rotation.set(0, 0.15, 0);
    bodyPivot.scale.set(sxz, squash, sxz);
    bodyPivot.rotation.set(lean, 0, 0.02 * Math.sin(phase));
    head.scale.set(Math.pow(1 / sxz, 0.5), Math.pow(1 / squash, 0.5), Math.pow(1 / sxz, 0.5));
    head.rotation.set(-lean * 0.55 + 0.08 * happy - 0.05 * air, 0.035 * Math.sin(phase + 1.1), 0.03 * Math.sin(phase * 2 + 0.4));

    for (const [index, arm] of arms.entries()) {
      const side = index === 0 ? -1 : 1;
      const handBias = 0.35 * Math.sin(t * 9) * Math.max(0, raise) * (raise > 0.9 ? 1 : 0) * side;
      // The supplied rig's arms point up before rotation; this mesh rests down.
      // Offset its neutral pose while preserving the source's 2.2-radian lift.
      arm.rotation.set(0.1 - 0.26 * raise + handBias * 0.06, -side * 0.2 * raise, side * (0.12 + 2.2 * raise));
      arm.scale.y = 1 + 0.24 * Math.max(0, raise);
      wrists[index].rotation.set(0.08 + 0.14 * Math.max(0, raise), 0, side * (0.2 - 0.4 * raise) + handBias * 0.16);
      legs[index].position.y = 0.36 - Math.min(0, root.position.y);
      legs[index].rotation.set(-crouch * 0.26 - air * 0.06, 0, -side * (0.04 + crouch * 0.04));
    }
    pendant.rotation.set(air * 0.12, 0, Math.sin(phase * 2) * happy * 0.035);
    for (const [index, antenna] of antennae.entries()) {
      const side = index === 0 ? -1 : 1;
      antenna.rotation.set(sampleAntennaSpring(t) - 0.06 * perk, 0, -side * 0.12 * perk + 0.008 * Math.sin(t * 2.3 + index));
    }
    const bump = (center: number) => {
      const distance = Math.abs(t - center) / 0.14;
      return distance >= 1 ? 0 : Math.cos(distance * Math.PI / 2) ** 2;
    };
    const blink = 1 - 0.92 * Math.max(bump(0.3), bump(3.46));
    for (const [index, eye] of eyes.entries()) {
      eye.visible = happy < 0.5;
      eye.scale.set(pose.eyeWide, pose.eyeWide * blink, pose.eyeWide);
      happyEyes[index].visible = happy >= 0.5;
    }
    for (const part of mouthParts) if (part.morphTargetInfluences) part.morphTargetInfluences[0] = pose.mouth;
  }

  pose(0, true);

  return {
    root,
    pose,
    dispose() {
      for (const shape of geometries) shape.dispose();
      for (const finish of materials) finish.dispose();
      geometries.clear();
      materials.clear();
      root.clear();
    },
  };
}
