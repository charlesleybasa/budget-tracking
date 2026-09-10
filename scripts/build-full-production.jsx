/**
 * Pesolita — full production intro/showcase video
 * =================================================
 * After Effects ExtendScript / JSX
 *
 * 1920x1080 / 30fps / 37 seconds
 *
 * FIXED:
 * - Correctly captures the layer returned by precompose()
 * - Does not assume precomp is comp.layer(1)
 * - Uses modern setTrackMatte() when available
 * - Correctly colors "Peso" using Index-based text selection
 * - Safer font fallback
 * - Better missing-asset diagnostics
 * - Safer sprite-sheet masking
 * - More reliable layer duration handling
 */

(function () {

    app.beginUndoGroup("Build Pesolita Full Production");

    try {

        // =============================================================
        // SETUP
        // =============================================================

        var FPS = 30;
        var W = 1920;
        var H = 1080;
        var CX = W / 2;
        var CY = H / 2;

        var DURATION_FRAMES = 1110; // 37 seconds
        var DURATION = DURATION_FRAMES / FPS;

        function f(frames) {
            return frames / FPS;
        }

        // =============================================================
        // BRAND COLORS
        // =============================================================

        var GOLD  = [1.0000, 0.7922, 0.1569]; // #FFCA28
        var INK   = [0.0431, 0.0431, 0.0471]; // #0B0B0C
        var PAPER = [1.0000, 1.0000, 1.0000]; // #FFFFFF
        var BLUE  = [0.1137, 0.4353, 0.9490]; // #1D6FF2
        var GREEN = [0.4706, 0.7373, 0.5451]; // #78BC8B
        var CORAL = [0.9059, 0.6039, 0.5294]; // #E79A87
        var BEZEL = [0.1100, 0.1100, 0.1200];

        // =============================================================
        // REPO PATH
        // =============================================================

        var scriptFile = new File($.fileName);
        var scriptFolder = scriptFile.parent;
        var repoRoot = scriptFolder.parent;

        function assetPath(rel) {
            return repoRoot.fsName + "/" + rel;
        }

        function requireFile(rel) {
            var file = new File(assetPath(rel));

            if (!file.exists) {
                throw new Error(
                    "Missing asset:\n\n" +
                    file.fsName +
                    "\n\nExpected relative path:\n" +
                    rel
                );
            }

            return file;
        }

        function importImage(rel, label) {
            var file = requireFile(rel);

            var options = new ImportOptions(file);

            if (!options.canImportAs(ImportAsType.FOOTAGE)) {
                throw new Error(
                    "After Effects cannot import this file as footage:\n" +
                    file.fsName
                );
            }

            options.importAs = ImportAsType.FOOTAGE;

            var item = app.project.importFile(options);
            item.name = label;

            return item;
        }

        // =============================================================
        // IMPORT ASSETS
        // =============================================================

        var iconFootage =
            importImage(
                "app/icon.png",
                "Pesolita Icon (512)"
            );

        var celebrateFootage =
            importImage(
                "public/celebrate.png",
                "Kuya Ipis — Celebrate Sheet"
            );

        var peekabooFootage =
            importImage(
                "public/peekaboo.png",
                "Kuya Ipis — Peekaboo Sheet"
            );

        var promoFootage =
            importImage(
                "public/pesolita-promo-square.png",
                "Promo Art"
            );

        var homeFootage =
            importImage(
                "scripts/render-assets/home.png",
                "Screenshot — Home"
            );

        var templatesFootage =
            importImage(
                "scripts/render-assets/templates.png",
                "Screenshot — Templates"
            );

        var guardFootage =
            importImage(
                "scripts/render-assets/guard.png",
                "Screenshot — Guard"
            );

        var loggedFootage =
            importImage(
                "scripts/render-assets/logged.png",
                "Screenshot — Logged"
            );

        // =============================================================
        // CREATE MAIN COMP
        // =============================================================

        var comp = app.project.items.addComp(
            "Pesolita — Full Production",
            W,
            H,
            1,
            DURATION,
            FPS
        );

        comp.bgColor = INK;
        comp.openInViewer();

        // =============================================================
        // HELPERS
        // =============================================================

        function trim(layer, inF, outF) {

            layer.startTime = 0;

            var inTime = f(inF);
            var outTime = f(outF);

            if (inTime < 0) {
                inTime = 0;
            }

            if (outTime > comp.duration) {
                outTime = comp.duration;
            }

            layer.inPoint = inTime;
            layer.outPoint = outTime;
        }

        function easeAllKeys(prop) {

            if (!prop || prop.numKeys < 1) {
                return;
            }

            var ease = new KeyframeEase(0, 75);

            var dim = 1;

            try {

                var value = prop.value;

                if (value instanceof Array) {
                    dim = value.length;
                }

            } catch (e) {
                dim = 1;
            }

            var easeArr = [];

            for (var d = 0; d < dim; d++) {
                easeArr.push(ease);
            }

            var ease3 = [ease, ease, ease];

            for (var k = 1; k <= prop.numKeys; k++) {

                try {

                    prop.setTemporalEaseAtKey(
                        k,
                        easeArr,
                        easeArr
                    );

                } catch (err) {

                    try {

                        prop.setTemporalEaseAtKey(
                            k,
                            ease3,
                            ease3
                        );

                    } catch (ignore) {}

                }
            }
        }

        function fadeInOut(
            layer,
            inA,
            inB,
            outA,
            outB
        ) {

            var op = layer.property("Opacity");

            op.setValueAtTime(f(inA), 0);
            op.setValueAtTime(f(inB), 100);

            if (outA !== null && outB !== null) {

                op.setValueAtTime(f(outA), 100);
                op.setValueAtTime(f(outB), 0);

            }

            easeAllKeys(op);
        }

        function bounceScale(
            layer,
            startF,
            peakF,
            settleF,
            overshootVal,
            settleValArr
        ) {

            var sc = layer.property("Scale");

            var settle =
                settleValArr ||
                [overshootVal, overshootVal];

            sc.setValueAtTime(
                f(startF),
                [0, 0]
            );

            sc.setValueAtTime(
                f(peakF),
                [overshootVal, overshootVal]
            );

            sc.setValueAtTime(
                f(settleF),
                settle
            );

            easeAllKeys(sc);
        }

        function slidePosition(
            layer,
            fromXY,
            toXY,
            startF,
            endF
        ) {

            var pos = layer.property("Position");

            pos.setValueAtTime(
                f(startF),
                fromXY
            );

            pos.setValueAtTime(
                f(endF),
                toXY
            );

            easeAllKeys(pos);
        }

        function addImageLayer(
            footageItem,
            name,
            inF,
            outF,
            nativeW,
            nativeH
        ) {

            var layer = comp.layers.add(footageItem);

            layer.name = name;

            layer.property("Anchor Point")
                .setValue([
                    nativeW / 2,
                    nativeH / 2
                ]);

            layer.property("Position")
                .setValue([
                    CX,
                    CY
                ]);

            trim(layer, inF, outF);

            return layer;
        }

        // =============================================================
        // SPRITE CROP
        // =============================================================

        function addSpriteCrop(
            footageItem,
            name,
            cellX,
            cellY,
            cellW,
            cellH,
            inF,
            outF
        ) {

            var layer = comp.layers.add(footageItem);

            layer.name = name;

            var mask = layer.Masks.addProperty("Mask");

            var shape = new Shape();

            shape.vertices = [
                [cellX, cellY],
                [cellX + cellW, cellY],
                [cellX + cellW, cellY + cellH],
                [cellX, cellY + cellH]
            ];

            shape.inTangents = [
                [0, 0],
                [0, 0],
                [0, 0],
                [0, 0]
            ];

            shape.outTangents = [
                [0, 0],
                [0, 0],
                [0, 0],
                [0, 0]
            ];

            shape.closed = true;

            mask.property("Mask Path")
                .setValue(shape);

            layer.property("Anchor Point")
                .setValue([
                    cellX + cellW / 2,
                    cellY + cellH / 2
                ]);

            layer.property("Position")
                .setValue([
                    CX,
                    CY
                ]);

            trim(layer, inF, outF);

            return layer;
        }

        // =============================================================
        // TEXT
        // =============================================================

        function addText(
            str,
            size,
            color,
            name,
            inF,
            outF,
            justification
        ) {

            var layer = comp.layers.addText(str);

            layer.name = name;

            var sourceText =
                layer.property("Source Text");

            var td = sourceText.value;

            td.fontSize = size;
            td.fillColor = color;

            try {
                td.font = "Outfit-Bold";
            } catch (fontErr) {
                // Font unavailable — AE will use current/default font.
            }

            td.justification =
                justification ||
                ParagraphJustification.CENTER_JUSTIFY;

            try {
                td.tracking = 0;
            } catch (trackingErr) {}

            sourceText.setValue(td);

            layer.property("Position")
                .setValue([
                    CX,
                    CY
                ]);

            trim(layer, inF, outF);

            return layer;
        }

        // =============================================================
        // WORDMARK
        // =============================================================
        //
        // IMPORTANT FIX:
        // Range Selector defaults to Percentage.
        // End = 4 therefore meant 4%, NOT characters 1–4.
        //
        // We explicitly switch the selector to Index units first.
        // =============================================================

        function addWordmark(
            size,
            name,
            inF,
            outF,
            position
        ) {

            var layer =
                addText(
                    "Pesolita",
                    size,
                    PAPER,
                    name,
                    inF,
                    outF,
                    ParagraphJustification.CENTER_JUSTIFY
                );

            layer.property("Position")
                .setValue(position);

            var textProps =
                layer.property("ADBE Text Properties");

            var animators =
                textProps.property("ADBE Text Animators");

            var animator =
                animators.addProperty("ADBE Text Animator");

            animator.name = "Peso Gold";

            var animatorProps =
                animator.property(
                    "ADBE Text Animator Properties"
                );

            animatorProps.addProperty(
                "ADBE Text Fill Color"
            ).setValue(GOLD);

            var selectors =
                animator.property(
                    "ADBE Text Selectors"
                );

            var selector =
                selectors.addProperty(
                    "ADBE Text Selector"
                );

            var advanced =
                selector.property(
                    "ADBE Text Range Advanced"
                );

            // 2 = Index units.
            advanced.property(
                "ADBE Text Range Units"
            ).setValue(2);

            // Select first 4 characters: "Peso".
            selector.property(
                "ADBE Text Index Start"
            ).setValue(0);

            selector.property(
                "ADBE Text Index End"
            ).setValue(4);

            return layer;
        }

        // =============================================================
        // SHAPE HELPERS
        // =============================================================

        function addRoundRect(
            w,
            h,
            radius,
            color,
            name,
            inF,
            outF
        ) {

            var layer =
                comp.layers.addShape();

            layer.name = name;

            var contents =
                layer.property(
                    "ADBE Root Vectors Group"
                );

            var group =
                contents.addProperty(
                    "ADBE Vector Group"
                );

            var groupContents =
                group.property(
                    "ADBE Vectors Group"
                );

            var rect =
                groupContents.addProperty(
                    "ADBE Vector Shape - Rect"
                );

            rect.property(
                "ADBE Vector Rect Size"
            ).setValue([
                w,
                h
            ]);

            rect.property(
                "ADBE Vector Rect Roundness"
            ).setValue(radius);

            var fill =
                groupContents.addProperty(
                    "ADBE Vector Graphic - Fill"
                );

            fill.property(
                "ADBE Vector Fill Color"
            ).setValue(color);

            layer.property("Position")
                .setValue([
                    CX,
                    CY
                ]);

            trim(layer, inF, outF);

            return layer;
        }

        function addEllipse(
            w,
            h,
            color,
            name,
            inF,
            outF
        ) {

            var layer =
                comp.layers.addShape();

            layer.name = name;

            var contents =
                layer.property(
                    "ADBE Root Vectors Group"
                );

            var group =
                contents.addProperty(
                    "ADBE Vector Group"
                );

            var groupContents =
                group.property(
                    "ADBE Vectors Group"
                );

            var ell =
                groupContents.addProperty(
                    "ADBE Vector Shape - Ellipse"
                );

            ell.property(
                "ADBE Vector Ellipse Size"
            ).setValue([
                w,
                h
            ]);

            var fill =
                groupContents.addProperty(
                    "ADBE Vector Graphic - Fill"
                );

            fill.property(
                "ADBE Vector Fill Color"
            ).setValue(color);

            layer.property("Position")
                .setValue([
                    CX,
                    CY
                ]);

            trim(layer, inF, outF);

            return layer;
        }

        // =============================================================
        // PHONE MOCKUP
        // =============================================================
        //
        // IMPORTANT FIX:
        // precompose() returns a CompItem.
        // The original script incorrectly assumed the replacement layer
        // was always comp.layer(1).
        // =============================================================

        function addPhoneMockup(
            footageItem,
            nativeW,
            nativeH,
            name,
            cx,
            cy,
            inF,
            outF
        ) {

            var pad = 36;

            var bezel =
                addRoundRect(
                    nativeW + pad * 2,
                    nativeH + pad * 2,
                    90,
                    BEZEL,
                    name + " · Bezel",
                    inF,
                    outF
                );

            bezel.property("Position")
                .setValue([
                    cx,
                    cy
                ]);

            var screenshot =
                addImageLayer(
                    footageItem,
                    name + " · Screenshot",
                    inF,
                    outF,
                    nativeW,
                    nativeH
                );

            screenshot.property("Position")
                .setValue([
                    cx,
                    cy
                ]);

            var matte =
                addRoundRect(
                    nativeW,
                    nativeH,
                    64,
                    PAPER,
                    name + " · Matte",
                    inF,
                    outF
                );

            matte.property("Position")
                .setValue([
                    cx,
                    cy
                ]);

            // Put matte above screenshot.
            matte.moveBefore(screenshot);

            // AE 23+ has the explicit setTrackMatte API.
            // Older AE versions use trackMatteType.
            if (
                typeof screenshot.setTrackMatte === "function"
            ) {

                screenshot.setTrackMatte(
                    matte,
                    TrackMatteType.ALPHA
                );

            } else {

                screenshot.trackMatteType =
                    TrackMatteType.ALPHA;
            }

            var notch =
                addRoundRect(
                    140,
                    34,
                    17,
                    [0, 0, 0],
                    name + " · Notch",
                    inF,
                    outF
                );

            notch.property("Position")
                .setValue([
                    cx,
                    cy - (nativeH / 2 - 40)
                ]);

            // Make sure notch is above everything.
            notch.moveToBeginning();

            var indices = [
                notch.index,
                matte.index,
                screenshot.index,
                bezel.index
            ];

            // Remove duplicate indices defensively.
            var uniqueIndices = [];
            var seen = {};

            for (var i = 0; i < indices.length; i++) {

                var idx = indices[i];

                if (!seen[idx]) {
                    seen[idx] = true;
                    uniqueIndices.push(idx);
                }
            }

            var nestedComp =
                comp.layers.precompose(
                    uniqueIndices,
                    name,
                    true
                );

            // =========================================================
            // IMPORTANT:
            // Find the actual replacement layer instead of assuming
            // comp.layer(1).
            // =========================================================

            var precompLayer = null;

            for (
                var l = 1;
                l <= comp.numLayers;
                l++
            ) {

                var candidate = comp.layer(l);

                if (
                    candidate.source === nestedComp
                ) {

                    precompLayer = candidate;
                    break;
                }
            }

            if (!precompLayer) {

                throw new Error(
                    "Could not find generated phone precomp layer: " +
                    name
                );
            }

            precompLayer.name = name;

            // After precompose, the nested comp's layer dimensions
            // are used. Put the transform origin in the center.
            precompLayer.property("Anchor Point")
                .setValue([
                    nestedComp.width / 2,
                    nestedComp.height / 2
                ]);

            precompLayer.property("Position")
                .setValue([
                    cx,
                    cy
                ]);

            trim(
                precompLayer,
                inF,
                outF
            );

            return precompLayer;
        }

        // =============================================================
        // STREAK WIPE
        // =============================================================

        function addStreakWipe(
            atFrame,
            name
        ) {

            var streak =
                addRoundRect(
                    2600,
                    140,
                    0,
                    GOLD,
                    name,
                    atFrame - 5,
                    atFrame + 8
                );

            streak.property("Rotation")
                .setValue(-18);

            try {
                streak.blendingMode =
                    BlendingMode.ADD;
            } catch (blendErr) {}

            var pos =
                streak.property("Position");

            pos.setValueAtTime(
                f(atFrame - 5),
                [-800, CY]
            );

            pos.setValueAtTime(
                f(atFrame + 3),
                [CX, CY]
            );

            pos.setValueAtTime(
                f(atFrame + 8),
                [2720, CY]
            );

            easeAllKeys(pos);

            var op =
                streak.property("Opacity");

            op.setValueAtTime(
                f(atFrame - 5),
                0
            );

            op.setValueAtTime(
                f(atFrame - 1),
                55
            );

            op.setValueAtTime(
                f(atFrame + 8),
                0
            );

            easeAllKeys(op);
        }

        // =============================================================
        // BACKGROUND
        // =============================================================

        var bg =
            comp.layers.addSolid(
                INK,
                "BG — Pocket Ink",
                W,
                H,
                1,
                DURATION
            );

        bg.moveToEnd();

        // =============================================================
        // SCENE 1 — HERO
        // 0 - 90
        // =============================================================

        var heroIcon =
            addImageLayer(
                iconFootage,
                "S1 · Icon Hero",
                0,
                90,
                512,
                512
            );

        bounceScale(
            heroIcon,
            0,
            24,
            36,
            70,
            [62, 62]
        );

        fadeInOut(
            heroIcon,
            0,
            6,
            82,
            90
        );

        var rot =
            heroIcon.property("Rotation");

        rot.setValueAtTime(
            f(0),
            -8
        );

        rot.setValueAtTime(
            f(30),
            0
        );

        easeAllKeys(rot);

        // =============================================================
        // SCENE 2 — WORDMARK
        // 90 - 210
        // =============================================================

        var wordmark2 =
            addWordmark(
                150,
                "S2 · Wordmark",
                90,
                210,
                [CX, 480]
            );

        bounceScale(
            wordmark2,
            90,
            114,
            126,
            112,
            [100, 100]
        );

        fadeInOut(
            wordmark2,
            90,
            96,
            200,
            210
        );

        var tagline2 =
            addText(
                "Every peso gets a home.",
                50,
                PAPER,
                "S2 · Tagline",
                90,
                210
            );

        slidePosition(
            tagline2,
            [CX, 590],
            [CX, 560],
            150,
            168
        );

        fadeInOut(
            tagline2,
            150,
            168,
            200,
            210
        );

        // =============================================================
        // SCENE 3 — KUYA IPIS
        // 210 - 300
        // =============================================================

        var peekaboo3 =
            addSpriteCrop(
                peekabooFootage,
                "S3 · Kuya Ipis Peekaboo",
                3 * 280,
                3 * 246,
                280,
                246,
                210,
                300
            );

        peekaboo3.property("Position")
            .setValue([
                700,
                540
            ]);

        bounceScale(
            peekaboo3,
            210,
            228,
            240,
            290,
            [260, 260]
        );

        fadeInOut(
            peekaboo3,
            210,
            216,
            288,
            300
        );

        var caption3 =
            addText(
                "Say hi to\rKuya Ipis.",
                54,
                PAPER,
                "S3 · Caption",
                210,
                300,
                ParagraphJustification.LEFT_JUSTIFY
            );

        slidePosition(
            caption3,
            [1450, 540],
            [1280, 540],
            228,
            252
        );

        fadeInOut(
            caption3,
            228,
            252,
            288,
            300
        );

        addStreakWipe(
            300,
            "Wipe A"
        );

        // =============================================================
        // SCENE 4 — HOME
        // 300 - 420
        // =============================================================

        var mockup4 =
            addPhoneMockup(
                homeFootage,
                620,
                1347,
                "S4 · Home Mockup",
                620,
                560,
                300,
                420
            );

        bounceScale(
            mockup4,
            300,
            324,
            340,
            62,
            [54, 54]
        );

        fadeInOut(
            mockup4,
            300,
            308,
            405,
            420
        );

        var caption4 =
            addText(
                "Every pocket.\rOne wallet.",
                50,
                PAPER,
                "S4 · Caption",
                300,
                420,
                ParagraphJustification.LEFT_JUSTIFY
            );

        slidePosition(
            caption4,
            [1480, 540],
            [1330, 540],
            320,
            344
        );

        fadeInOut(
            caption4,
            320,
            344,
            405,
            420
        );

        addStreakWipe(
            420,
            "Wipe B"
        );

        // =============================================================
        // SCENE 5 — TEMPLATES
        // 420 - 540
        // =============================================================

        var mockup5 =
            addPhoneMockup(
                templatesFootage,
                620,
                1347,
                "S5 · Templates Mockup",
                1300,
                560,
                420,
                540
            );

        bounceScale(
            mockup5,
            420,
            444,
            460,
            62,
            [54, 54]
        );

        fadeInOut(
            mockup5,
            420,
            428,
            525,
            540
        );

        var caption5 =
            addText(
                "Pick a card that\rfeels like yours.",
                50,
                PAPER,
                "S5 · Caption",
                420,
                540,
                ParagraphJustification.RIGHT_JUSTIFY
            );

        slidePosition(
            caption5,
            [440, 540],
            [590, 540],
            440,
            464
        );

        fadeInOut(
            caption5,
            440,
            464,
            525,
            540
        );

        addStreakWipe(
            540,
            "Wipe C"
        );

        // =============================================================
        // SCENE 6 — GUARD
        // 540 - 660
        // =============================================================

        var mockup6 =
            addPhoneMockup(
                guardFootage,
                620,
                1347,
                "S6 · Guard Mockup",
                620,
                560,
                540,
                660
            );

        bounceScale(
            mockup6,
            540,
            564,
            580,
            62,
            [54, 54]
        );

        fadeInOut(
            mockup6,
            540,
            548,
            645,
            660
        );

        var caption6 =
            addText(
                "Know before\ryou overspend.",
                50,
                PAPER,
                "S6 · Caption",
                540,
                660,
                ParagraphJustification.LEFT_JUSTIFY
            );

        slidePosition(
            caption6,
            [1480, 540],
            [1330, 540],
            560,
            584
        );

        fadeInOut(
            caption6,
            560,
            584,
            645,
            660
        );

        addStreakWipe(
            660,
            "Wipe D"
        );

        // =============================================================
        // SCENE 7 — CELEBRATE
        // 660 - 750
        // =============================================================

        var celebrate7 =
            addSpriteCrop(
                celebrateFootage,
                "S7 · Kuya Ipis Celebrate",
                3 * 300,
                2 * 372,
                300,
                372,
                660,
                750
            );

        celebrate7.property("Position")
            .setValue([
                650,
                560
            ]);

        bounceScale(
            celebrate7,
            660,
            678,
            690,
            250,
            [220, 220]
        );

        fadeInOut(
            celebrate7,
            660,
            666,
            732,
            750
        );

        var confettiColors = [
            GOLD,
            BLUE,
            GREEN,
            CORAL
        ];

        var confettiOffsets = [
            [-60, -220],
            [140, -260],
            [260, -60],
            [-180, -60]
        ];

        for (
            var c = 0;
            c < confettiColors.length;
            c++
        ) {

            var cStart =
                678 + c * 6;

            var dot =
                addEllipse(
                    30,
                    30,
                    confettiColors[c],
                    "S7 · Confetti " + c,
                    660,
                    750
                );

            dot.property("Position")
                .setValue([
                    650 + confettiOffsets[c][0],
                    560 + confettiOffsets[c][1]
                ]);

            bounceScale(
                dot,
                cStart,
                cStart + 10,
                cStart + 16,
                130,
                [100, 100]
            );

            fadeInOut(
                dot,
                cStart,
                cStart + 4,
                720,
                738
            );
        }

        var caption7 =
            addText(
                "No bank connection.\rEverything stays yours.",
                42,
                PAPER,
                "S7 · Caption",
                660,
                750,
                ParagraphJustification.LEFT_JUSTIFY
            );

        slidePosition(
            caption7,
            [1500, 540],
            [1330, 540],
            684,
            708
        );

        fadeInOut(
            caption7,
            684,
            708,
            732,
            750
        );

        // =============================================================
        // SCENE 8 — LOGGED
        // 750 - 870
        // =============================================================

        var mockup8 =
            addPhoneMockup(
                loggedFootage,
                620,
                1347,
                "S8 · Logged Mockup",
                1300,
                560,
                750,
                870
            );

        bounceScale(
            mockup8,
            750,
            774,
            790,
            62,
            [54, 54]
        );

        fadeInOut(
            mockup8,
            750,
            758,
            855,
            870
        );

        var caption8 =
            addText(
                "Every log gets a\rlittle celebration.",
                50,
                PAPER,
                "S8 · Caption",
                750,
                870,
                ParagraphJustification.RIGHT_JUSTIFY
            );

        slidePosition(
            caption8,
            [440, 540],
            [590, 540],
            770,
            794
        );

        fadeInOut(
            caption8,
            770,
            794,
            855,
            870
        );

        // =============================================================
        // SCENE 9 — PROMO ART
        // 870 - 960
        // =============================================================

        var promo9 =
            addImageLayer(
                promoFootage,
                "S9 · Promo Art",
                870,
                960,
                1254,
                1254
            );

        var promoScale =
            promo9.property("Scale");

        promoScale.setValueAtTime(
            f(870),
            [78, 78]
        );

        promoScale.setValueAtTime(
            f(960),
            [84, 84]
        );

        easeAllKeys(promoScale);

        fadeInOut(
            promo9,
            870,
            882,
            945,
            960
        );

        // =============================================================
        // SCENE 10 — FINAL LOCKUP
        // 960 - 1110
        // =============================================================

        var glow10 =
            addEllipse(
                1000,
                1000,
                GOLD,
                "S10 · Glow",
                960,
                1110
            );

        glow10.property("Position")
            .setValue([
                CX,
                480
            ]);

        try {

            glow10.property("Opacity")
                .expression =
                "Math.sin(time*3)*6+18";

        } catch (expressionErr) {

            glow10.property("Opacity")
                .setValue(18);
        }

        glow10.moveToEnd();

        var icon10 =
            addImageLayer(
                iconFootage,
                "S10 · Icon Lockup",
                960,
                1110,
                512,
                512
            );

        icon10.property("Position")
            .setValue([
                CX,
                400
            ]);

        bounceScale(
            icon10,
            960,
            978,
            990,
            70,
            [60, 60]
        );

        fadeInOut(
            icon10,
            960,
            966,
            1092,
            1110
        );

        var wordmark10 =
            addWordmark(
                110,
                "S10 · Wordmark Lockup",
                960,
                1110,
                [CX, 560]
            );

        bounceScale(
            wordmark10,
            972,
            990,
            1002,
            112,
            [100, 100]
        );

        fadeInOut(
            wordmark10,
            972,
            978,
            1092,
            1110
        );

        var tagline10 =
            addText(
                "Every peso gets a home.",
                42,
                PAPER,
                "S10 · Tagline Lockup",
                960,
                1110
            );

        tagline10.property("Position")
            .setValue([
                CX,
                650
            ]);

        fadeInOut(
            tagline10,
            1002,
            1020,
            1092,
            1110
        );

        // =============================================================
        // OUTRO FADE
        // =============================================================

        var outroFade =
            comp.layers.addSolid(
                [0, 0, 0],
                "Outro Fade to Black",
                W,
                H,
                1,
                DURATION
            );

        var outroOpacity =
            outroFade.property("Opacity");

        outroOpacity.setValueAtTime(
            f(1095),
            0
        );

        outroOpacity.setValueAtTime(
            f(1110),
            100
        );

        easeAllKeys(outroOpacity);

        outroFade.moveToBeginning();

        // =============================================================
        // SET START TIME
        // =============================================================

        comp.time = 0;

        // =============================================================
        // SUCCESS
        // =============================================================

        alert(
            "Pesolita production built successfully!\n\n" +

            "Composition:\n" +
            "Pesolita — Full Production\n\n" +

            "1920 x 1080\n" +
            "30 fps\n" +
            "37 seconds\n\n" +

            "Scenes:\n" +
            "1. Hero logo\n" +
            "2. Wordmark + tagline\n" +
            "3. Kuya Ipis hello\n" +
            "4. Home mockup\n" +
            "5. Templates mockup\n" +
            "6. Guard mockup\n" +
            "7. Privacy + celebration\n" +
            "8. Logged mockup\n" +
            "9. Promo art\n" +
            "10. Final lockup\n\n" +

            "No audio was added.\n\n" +

            "IMPORTANT:\n" +
            "Make sure the Outfit font is installed if you want the\n" +
            "exact intended typography."
        );

    } catch (err) {

        var message =
            "Pesolita build FAILED.\n\n" +
            "Error:\n" +
            err.toString();

        try {

            if (err.line) {
                message +=
                    "\n\nLine: " +
                    err.line;
            }

        } catch (lineErr) {}

        alert(message);

    } finally {

        app.endUndoGroup();

    }

})();
