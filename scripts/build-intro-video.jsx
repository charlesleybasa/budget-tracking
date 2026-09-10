/**
 * Pesolita — "Every peso gets a home" intro video
 * ================================================
 * Builds a 1920x1080, 30fps, 32s montage entirely from the app's real brand
 * assets and design tokens (see app/brand/page.tsx and app/globals.css) —
 * no placeholder graphics.
 *
 * HOW TO RUN
 *   In After Effects: File > Scripts > Run Script File... and pick this file.
 *   (Leave this file inside the repo's scripts/ folder — it locates the
 *   image assets relative to its own location, so it doesn't matter whose
 *   machine or which absolute path the repo lives at.)
 *
 * WHAT YOU GET
 *   A composition named "Pesolita — Intro" with nine scenes cut back-to-back:
 *   hero logo scale-in, wordmark + tagline, mascot hello, "every pocket, one
 *   wallet" pills, card/logging beat, privacy + celebrate mascot, insights
 *   bars, promo art, final lockup + fade to black. Everything is real AE
 *   layers with real keyframes — scrub it, retime it, swap colors, whatever.
 *
 * WHAT'S NOT INCLUDED
 *   No audio track (no source music was provided). No voiceover. The Outfit
 *   font ships in this repo at ios/Pesolita/Pesolita/Resources/Fonts/ —
 *   install it in Font Book first if you want exact typography; otherwise
 *   AE will substitute a system font automatically.
 */

(function () {
  app.beginUndoGroup("Build Pesolita Intro Video");

  try {
    // ---------------------------------------------------------------
    // Setup
    // ---------------------------------------------------------------
    var FPS = 30;
    var W = 1920;
    var H = 1080;
    var CX = W / 2;
    var CY = H / 2;

    function f(frames) { return frames / FPS; } // frames -> seconds

    var DURATION_FRAMES = 960; // 32s

    // Brand colours (0-1 floats), from app/globals.css / app/brand/page.tsx
    var GOLD = [1.0, 0.7922, 0.1569];   // Peso Gold #FFCA28
    var INK = [0.0431, 0.0431, 0.0471]; // Pocket Ink #0B0B0C
    var PAPER = [1, 1, 1];              // Paper #FFFFFF
    var BLUE = [0.1137, 0.4353, 0.9490]; // Signal Blue #1D6FF2
    var GREEN = [0.4706, 0.7373, 0.5451]; // Leaf Strap #78BC8B
    var CORAL = [0.9059, 0.6039, 0.5294]; // Cheek Coral #E79A87

    // Locate the repo root relative to this script (scripts/<this file>)
    var scriptFile = new File($.fileName);
    var repoRoot = scriptFile.parent.parent.fsName;

    function assetPath(rel) {
      return repoRoot + "/" + rel;
    }

    function importImage(rel, label) {
      var file = new File(assetPath(rel));
      if (!file.exists) {
        throw new Error("Missing asset: " + file.fsName);
      }
      var options = new ImportOptions(file);
      var item = app.project.importFile(options);
      item.name = label;
      return item;
    }

    // ---------------------------------------------------------------
    // Import brand assets
    // ---------------------------------------------------------------
    var iconFootage = importImage("app/icon.png", "Pesolita Icon (512)");
    var celebrateFootage = importImage("public/celebrate.png", "Kuya Ipis — Celebrate Sheet");
    var peekabooFootage = importImage("public/peekaboo.png", "Kuya Ipis — Peekaboo Sheet");
    var promoFootage = importImage("public/pesolita-promo-square.png", "Promo Art");

    // ---------------------------------------------------------------
    // Composition
    // ---------------------------------------------------------------
    var comp = app.project.items.addComp(
      "Pesolita — Intro",
      W,
      H,
      1,
      f(DURATION_FRAMES),
      FPS
    );
    comp.bgColor = INK;
    comp.openInViewer();

    // ---------------------------------------------------------------
    // Small helpers
    // ---------------------------------------------------------------

    function trim(layer, inF, outF) {
      layer.startTime = 0;
      layer.inPoint = f(inF);
      layer.outPoint = f(outF);
    }

    // Applies a smooth ease to every keyframe on a property. AE's
    // setTemporalEaseAtKey wants one KeyframeEase per dimension of the
    // property's value EXCEPT spatial properties (Position, and Anchor
    // Point when spatial) which always require exactly 3, even on a 2D
    // layer whose value only has 2 components. Try the natural dimension
    // first and fall back to 3 (spatial) if AE rejects it.
    function easeAllKeys(prop) {
      var ease = new KeyframeEase(0, 75);
      var dim = 1;
      try {
        var v = prop.value;
        if (v && v.length) dim = v.length;
      } catch (e) {}
      var easeArr = [];
      for (var d = 0; d < dim; d++) easeArr.push(ease);
      var easeArr3 = [ease, ease, ease];
      for (var k = 1; k <= prop.numKeys; k++) {
        try {
          prop.setTemporalEaseAtKey(k, easeArr, easeArr);
        } catch (err) {
          prop.setTemporalEaseAtKey(k, easeArr3, easeArr3);
        }
      }
    }

    // Opacity fade in at [inA,inB], fade out at [outA,outB] (frame numbers)
    function fadeInOut(layer, inA, inB, outA, outB) {
      var op = layer.property("Opacity");
      op.setValueAtTime(f(inA), 0);
      op.setValueAtTime(f(inB), 100);
      if (outA != null) {
        op.setValueAtTime(f(outA), 100);
        op.setValueAtTime(f(outB), 0);
      }
      easeAllKeys(op);
    }

    // Scale bounce: 0 at start, overshoot at peak, settle at target — frames
    function bounceScale(layer, startF, peakF, settleF, overshootVal, settleValArr) {
      var sc = layer.property("Scale");
      var settle = settleValArr || [overshootVal, overshootVal];
      sc.setValueAtTime(f(startF), [0, 0]);
      sc.setValueAtTime(f(peakF), [overshootVal, overshootVal]);
      sc.setValueAtTime(f(settleF), settle);
      easeAllKeys(sc);
    }

    function slidePosition(layer, fromXY, toXY, startF, endF) {
      var pos = layer.property("Position");
      pos.setValueAtTime(f(startF), fromXY);
      pos.setValueAtTime(f(endF), toXY);
      easeAllKeys(pos);
    }

    function addImageLayer(footageItem, name, inF, outF, nativeW, nativeH) {
      var layer = comp.layers.add(footageItem);
      layer.name = name;
      layer.property("Anchor Point").setValue([nativeW / 2, nativeH / 2]);
      layer.property("Position").setValue([CX, CY]);
      trim(layer, inF, outF);
      return layer;
    }

    // Crop a single cell out of a sprite sheet using a rectangular mask,
    // and re-anchor the layer to that cell's centre so scale/position work
    // on the cropped subject rather than the full sheet.
    function addSpriteCrop(footageItem, name, cellX, cellY, cellW, cellH, inF, outF) {
      var layer = comp.layers.add(footageItem);
      layer.name = name;
      var mask = layer.Masks.addProperty("Mask");
      var shape = new Shape();
      shape.vertices = [
        [cellX, cellY],
        [cellX + cellW, cellY],
        [cellX + cellW, cellY + cellH],
        [cellX, cellY + cellH],
      ];
      shape.closed = true;
      mask.property("Mask Path").setValue(shape);
      layer.property("Anchor Point").setValue([cellX + cellW / 2, cellY + cellH / 2]);
      layer.property("Position").setValue([CX, CY]);
      trim(layer, inF, outF);
      return layer;
    }

    function addText(str, size, color, name, inF, outF, justification) {
      var layer = comp.layers.addText(str);
      layer.name = name;
      var td = layer.property("Source Text").value;
      td.fontSize = size;
      try { td.font = "Outfit-Bold"; } catch (e) {}
      td.fillColor = color;
      td.justification = justification || ParagraphJustification.CENTER_JUSTIFY;
      td.tracking = 0;
      layer.property("Source Text").setValue(td);
      layer.property("Position").setValue([CX, CY]);
      trim(layer, inF, outF);
      return layer;
    }

    // Two-tone wordmark: first `goldChars` characters coloured gold, the
    // rest paper-white — mirrors components/BrandWordmark.tsx.
    function addWordmark(size, name, inF, outF, position) {
      var layer = addText("Pesolita", size, PAPER, name, inF, outF);
      layer.property("Position").setValue(position);
      var animator = layer.property("Text").property("Animators").addProperty("ADBE Text Animator");
      animator.name = "Peso Gold";
      var fillProp = animator.property("Properties").addProperty("ADBE Text Fill Color");
      fillProp.setValue(GOLD);
      var rangeSel = animator.property("Selectors").addProperty("ADBE Text Selector");
      rangeSel.property("Start").setValue(0);
      rangeSel.property("End").setValue(4); // "Peso"
      return layer;
    }

    function addRoundRect(w, h, radius, color, name, inF, outF) {
      var layer = comp.layers.addShape();
      layer.name = name;
      var contents = layer.property("ADBE Root Vectors Group");
      var group = contents.addProperty("ADBE Vector Group");
      var groupContents = group.property("ADBE Vectors Group");
      var rect = groupContents.addProperty("ADBE Vector Shape - Rect");
      rect.property("ADBE Vector Rect Size").setValue([w, h]);
      rect.property("ADBE Vector Rect Roundness").setValue(radius);
      var fill = groupContents.addProperty("ADBE Vector Graphic - Fill");
      fill.property("ADBE Vector Fill Color").setValue(color);
      layer.property("Position").setValue([CX, CY]);
      trim(layer, inF, outF);
      return layer;
    }

    function addEllipse(w, h, color, name, inF, outF) {
      var layer = comp.layers.addShape();
      layer.name = name;
      var contents = layer.property("ADBE Root Vectors Group");
      var group = contents.addProperty("ADBE Vector Group");
      var groupContents = group.property("ADBE Vectors Group");
      var ell = groupContents.addProperty("ADBE Vector Shape - Ellipse");
      ell.property("ADBE Vector Ellipse Size").setValue([w, h]);
      var fill = groupContents.addProperty("ADBE Vector Graphic - Fill");
      fill.property("ADBE Vector Fill Color").setValue(color);
      layer.property("Position").setValue([CX, CY]);
      trim(layer, inF, outF);
      return layer;
    }

    // A bar that grows upward from a fixed baseline Y.
    function addGrowBar(w, h, color, baselineY, x, name, inF, outF) {
      var layer = comp.layers.addShape();
      layer.name = name;
      var contents = layer.property("ADBE Root Vectors Group");
      var group = contents.addProperty("ADBE Vector Group");
      var groupContents = group.property("ADBE Vectors Group");
      var rect = groupContents.addProperty("ADBE Vector Shape - Rect");
      rect.property("ADBE Vector Rect Size").setValue([w, h]);
      rect.property("ADBE Vector Rect Roundness").setValue(10);
      var fill = groupContents.addProperty("ADBE Vector Graphic - Fill");
      fill.property("ADBE Vector Fill Color").setValue(color);
      layer.property("Anchor Point").setValue([0, h / 2]); // bottom-centre
      layer.property("Position").setValue([x, baselineY]);
      trim(layer, inF, outF);
      return layer;
    }

    // ---------------------------------------------------------------
    // Global background (spans the whole comp)
    // ---------------------------------------------------------------
    var bg = comp.layers.addSolid(INK, "BG — Pocket Ink", W, H, 1, f(DURATION_FRAMES));
    bg.moveToEnd();

    // =================================================================
    // SCENE 1 — Hero logo scale-in                            f0 - f90
    // =================================================================
    var heroIcon = addImageLayer(iconFootage, "S1 · Icon Hero", 0, 90, 512, 512);
    bounceScale(heroIcon, 0, 24, 36, 70, [62, 62]);
    fadeInOut(heroIcon, 0, 6, 82, 90);
    var rot = heroIcon.property("Rotation");
    rot.setValueAtTime(f(0), -8);
    rot.setValueAtTime(f(30), 0);
    easeAllKeys(rot);

    // =================================================================
    // SCENE 2 — Wordmark + tagline                          f90 - f210
    // =================================================================
    var wordmark2 = addWordmark(150, "S2 · Wordmark", 90, 210, [CX, 480]);
    bounceScale(wordmark2, 90, 114, 126, 112, [100, 100]);
    fadeInOut(wordmark2, 90, 96, 200, 210);

    var tagline2 = addText(
      "Every peso gets a home.",
      50,
      PAPER,
      "S2 · Tagline",
      90,
      210
    );
    slidePosition(tagline2, [CX, 590], [CX, 560], 150, 168);
    fadeInOut(tagline2, 150, 168, 200, 210);

    // =================================================================
    // SCENE 3 — Meet Kuya Ipis (peekaboo)                  f210 - f300
    // =================================================================
    // PEEKABOO sheet: cols 9, rows 6, cell 280x246, stillFrame 30 -> col3 row3
    var peekaboo3 = addSpriteCrop(
      peekabooFootage,
      "S3 · Kuya Ipis Peekaboo",
      3 * 280, 3 * 246, 280, 246,
      210, 300
    );
    peekaboo3.property("Position").setValue([700, 540]);
    bounceScale(peekaboo3, 210, 228, 240, 290, [260, 260]);
    fadeInOut(peekaboo3, 210, 216, 288, 300);

    var caption3 = addText(
      "Say hi to\rKuya Ipis.",
      54,
      PAPER,
      "S3 · Caption",
      210,
      300,
      ParagraphJustification.LEFT_JUSTIFY
    );
    slidePosition(caption3, [1450, 540], [1280, 540], 228, 252);
    fadeInOut(caption3, 228, 252, 288, 300);

    // =================================================================
    // SCENE 4 — Every pocket, one wallet                    f300 - f420
    // =================================================================
    var pillDefs = [
      { label: "Cash", color: GREEN, x: 640 },
      { label: "Bank", color: BLUE, x: 960 },
      { label: "E-Wallet", color: CORAL, x: 1280 },
    ];
    for (var i = 0; i < pillDefs.length; i++) {
      var def = pillDefs[i];
      var startF = 300 + i * 18;
      var peakF = startF + 18;
      var settleF = startF + 30;

      var pill = addRoundRect(280, 90, 45, def.color, "S4 · Pill " + def.label, 300, 420);
      pill.property("Position").setValue([def.x, 500]);
      bounceScale(pill, startF, peakF, settleF, 112, [100, 100]);
      fadeInOut(pill, startF, startF + 4, 405, 420);

      var pillLabel = addText(def.label, 34, INK, "S4 · Label " + def.label, 300, 420);
      pillLabel.property("Position").setValue([def.x, 500]);
      bounceScale(pillLabel, startF, peakF, settleF, 112, [100, 100]);
      fadeInOut(pillLabel, startF, startF + 4, 405, 420);
    }

    var caption4 = addText(
      "Every pocket. One wallet.",
      50,
      PAPER,
      "S4 · Caption",
      300,
      420
    );
    caption4.property("Position").setValue([CX, 650]);
    fadeInOut(caption4, 372, 390, 405, 420);

    // =================================================================
    // SCENE 5 — Log it in seconds                           f420 - f510
    // =================================================================
    var card5 = addRoundRect(420, 260, 28, GOLD, "S5 · Card", 420, 510);
    card5.property("Position").setValue([700, 600]);
    bounceScale(card5, 420, 438, 450, 112, [100, 100]);
    slidePosition(card5, [700, 660], [700, 540], 420, 450);
    fadeInOut(card5, 420, 426, 495, 510);

    var pesoSign5 = addText("₱", 130, INK, "S5 · Peso Sign", 420, 510);
    pesoSign5.property("Position").setValue([700, 550]);
    bounceScale(pesoSign5, 420, 438, 450, 112, [100, 100]);
    fadeInOut(pesoSign5, 426, 434, 495, 510);

    var caption5 = addText(
      "Log it in\rseconds.",
      54,
      PAPER,
      "S5 · Caption",
      420,
      510,
      ParagraphJustification.LEFT_JUSTIFY
    );
    slidePosition(caption5, [1500, 540], [1330, 540], 438, 462);
    fadeInOut(caption5, 438, 462, 495, 510);

    // =================================================================
    // SCENE 6 — Private + celebrate                         f510 - f630
    // =================================================================
    // CELEBRATE sheet: cols 8, rows 4, cell 300x372, stillFrame 19 -> col3 row2
    var celebrate6 = addSpriteCrop(
      celebrateFootage,
      "S6 · Kuya Ipis Celebrate",
      3 * 300, 2 * 372, 300, 372,
      510, 630
    );
    celebrate6.property("Position").setValue([650, 560]);
    bounceScale(celebrate6, 510, 528, 540, 250, [220, 220]);
    fadeInOut(celebrate6, 510, 516, 612, 630);

    var confettiColors = [GOLD, BLUE, GREEN, CORAL];
    var confettiOffsets = [
      [-60, -220], [140, -260], [260, -60], [-180, -60]
    ];
    for (var c = 0; c < confettiColors.length; c++) {
      var cStart = 528 + c * 6;
      var dot = addEllipse(30, 30, confettiColors[c], "S6 · Confetti " + c, 510, 630);
      dot.property("Position").setValue([650 + confettiOffsets[c][0], 560 + confettiOffsets[c][1]]);
      bounceScale(dot, cStart, cStart + 10, cStart + 16, 130, [100, 100]);
      fadeInOut(dot, cStart, cStart + 4, 600, 618);
    }

    var caption6 = addText(
      "No bank connection.\rEverything stays yours.",
      42,
      PAPER,
      "S6 · Caption",
      510,
      630,
      ParagraphJustification.LEFT_JUSTIFY
    );
    slidePosition(caption6, [1500, 540], [1330, 540], 534, 558);
    fadeInOut(caption6, 534, 558, 612, 630);

    // =================================================================
    // SCENE 7 — Insights at a glance                        f630 - f720
    // =================================================================
    var barHeights = [120, 190, 150, 230];
    var barStartX = 775;
    var barGap = 100;
    var barBaselineY = 620;
    for (var b = 0; b < barHeights.length; b++) {
      var bStart = 630 + b * 12;
      var bar = addGrowBar(
        70, barHeights[b], GOLD, barBaselineY,
        barStartX + b * barGap, "S7 · Bar " + b, 630, 720
      );
      var barScale = bar.property("Scale");
      barScale.setValueAtTime(f(bStart), [100, 1]);
      barScale.setValueAtTime(f(bStart + 24), [100, 100]);
      easeAllKeys(barScale);
      fadeInOut(bar, bStart, bStart + 4, 705, 720);
    }

    var caption7 = addText(
      "See your pacing\rat a glance.",
      50,
      PAPER,
      "S7 · Caption",
      630,
      720
    );
    caption7.property("Position").setValue([CX, 760]);
    fadeInOut(caption7, 654, 672, 705, 720);

    // =================================================================
    // SCENE 8 — Promo art reveal                            f720 - f810
    // =================================================================
    var promo8 = addImageLayer(promoFootage, "S8 · Promo Art", 720, 810, 1254, 1254);
    var promoScale = promo8.property("Scale");
    promoScale.setValueAtTime(f(720), [78, 78]);
    promoScale.setValueAtTime(f(810), [84, 84]);
    easeAllKeys(promoScale);
    fadeInOut(promo8, 720, 732, 795, 810);

    // =================================================================
    // SCENE 9 — Final lockup + fade to black                f810 - f960
    // =================================================================
    var glow9 = addEllipse(1000, 1000, GOLD, "S9 · Glow", 810, 960);
    glow9.property("Position").setValue([CX, 480]);
    glow9.property("Opacity").expression =
      "Math.sin(time*3)*6+18";
    glow9.moveToEnd(); // just above BG, everything else sits on top

    var icon9 = addImageLayer(iconFootage, "S9 · Icon Lockup", 810, 960, 512, 512);
    icon9.property("Position").setValue([CX, 400]);
    bounceScale(icon9, 810, 828, 840, 70, [60, 60]);
    fadeInOut(icon9, 810, 816, 942, 960);

    var wordmark9 = addWordmark(110, "S9 · Wordmark Lockup", 810, 960, [CX, 560]);
    bounceScale(wordmark9, 822, 840, 852, 112, [100, 100]);
    fadeInOut(wordmark9, 822, 828, 942, 960);

    var tagline9 = addText(
      "Every peso gets a home.",
      42,
      PAPER,
      "S9 · Tagline Lockup",
      810,
      960
    );
    tagline9.property("Position").setValue([CX, 650]);
    fadeInOut(tagline9, 852, 870, 942, 960);

    var outroFade = comp.layers.addSolid([0, 0, 0], "Outro Fade to Black", W, H, 1, f(DURATION_FRAMES));
    outroFade.property("Opacity").setValueAtTime(f(930), 0);
    outroFade.property("Opacity").setValueAtTime(f(960), 100);
    outroFade.moveToBeginning();

    comp.time = 0;

    alert(
      "Pesolita intro built.\n\n" +
      "Composition: \"Pesolita — Intro\" — 1920x1080, 30fps, 32s.\n" +
      "Scenes: hero logo, wordmark + tagline, Kuya Ipis hello, pocket pills, " +
      "card/logging, privacy + celebrate, insights bars, promo art, final lockup.\n\n" +
      "No audio was added. Install the Outfit font from " +
      "ios/Pesolita/Pesolita/Resources/Fonts/ for exact typography."
    );
  } catch (err) {
    alert("Pesolita intro build failed:\n" + err.toString());
  } finally {
    app.endUndoGroup();
  }
})();
