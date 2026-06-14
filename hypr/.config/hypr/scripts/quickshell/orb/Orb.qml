import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Standalone desktop centerpiece: a pulsing ring with a rotating gradient glow.
// Sits above the wallpaper but below normal windows, and is fully click-through.
// Colors are pulled live from the same theme file the rest of the shell uses.
ShellRoot {
    id: root

    // Live theme colors (fallbacks match the current matugen palette).
    property color cBlue:     "#adc6ff"
    property color cPeach:    "#debcdf"
    property color cSapphire: "#2b4678"
    property color cRed:      "#ffb4ab"
    property color cBase:     "#0c0e13"

    function af(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    Process {
        id: themeReader
        command: ["cat", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/qs_colors.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let c = JSON.parse(this.text.trim());
                    if (c.blue)     root.cBlue     = c.blue;
                    if (c.peach)    root.cPeach    = c.peach;
                    if (c.sapphire) root.cSapphire = c.sapphire;
                    if (c.red)      root.cRed      = c.red;
                    if (c.base)     root.cBase     = c.base;
                } catch (e) {}
            }
        }
    }
    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: themeReader.running = true
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: win
                required property var modelData
                screen: modelData

                WlrLayershell.namespace: "desk-orb"
                WlrLayershell.layer: WlrLayer.Bottom
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"

                anchors { top: true; bottom: true; left: true; right: true }

                // Only the emblem itself catches the pointer; the rest of the
                // screen stays click-through to the desktop.
                mask: Region { item: hitArea }

                // ---- sizing, all relative to screen height -------------------
                readonly property real ringOuter: Math.round(win.height * 0.090)
                readonly property real ringInner: Math.round(win.height * 0.072)
                readonly property real glowR:     Math.round(win.height * 0.150)
                readonly property real coreR:     Math.round(win.height * 0.058)

                // The whole assembly lives in one centered, slowly "breathing" item.
                Item {
                    id: assembly
                    anchors.centerIn: parent
                    width: win.glowR * 2
                    height: win.glowR * 2

                    SequentialAnimation on scale {
                        running: true
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.97; to: 1.03; duration: 4000; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.03; to: 0.97; duration: 4000; easing.type: Easing.InOutSine }
                    }

                    // ---- ambient glow disc (soft radial halo) ----------------
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeWidth: 0
                            fillGradient: RadialGradient {
                                centerX: win.glowR; centerY: win.glowR
                                centerRadius: win.glowR
                                focalX: win.glowR; focalY: win.glowR
                                GradientStop { position: 0.0; color: root.af(root.cBlue, 0.28) }
                                GradientStop { position: 0.55; color: root.af(root.cPeach, 0.10) }
                                GradientStop { position: 1.0; color: root.af(root.cBlue, 0.0) }
                            }
                            startX: win.glowR * 2; startY: win.glowR
                            PathAngleArc {
                                centerX: win.glowR; centerY: win.glowR
                                radiusX: win.glowR; radiusY: win.glowR
                                startAngle: 0; sweepAngle: 360
                            }
                        }
                    }

                    // ---- frosted liquid-glass medallion the emblem rests on ----
                    Rectangle {
                        id: glassDisc
                        anchors.centerIn: parent
                        width: win.ringOuter * 2.7
                        height: width
                        radius: width / 2
                        antialiasing: true
                        color: root.af(root.cBase, 0.28)        // translucent tint over the (blurred) wallpaper
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.18)    // refractive rim

                        // specular sheen across the top of the glass
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            antialiasing: true
                            gradient: Gradient {
                                GradientStop { position: 0.0;  color: Qt.rgba(1, 1, 1, 0.16) }
                                GradientStop { position: 0.40; color: Qt.rgba(1, 1, 1, 0.0) }
                                GradientStop { position: 1.0;  color: Qt.rgba(0, 0, 0, 0.06) }
                            }
                        }
                    }

                    // ---- the rotating gradient ring (an annulus) -------------
                    Shape {
                        id: ring
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        property real spin: 0
                        NumberAnimation on spin {
                            running: true; loops: Animation.Infinite
                            from: 0; to: 360; duration: 9000
                        }

                        ShapePath {
                            strokeWidth: 0
                            fillRule: ShapePath.OddEvenFill
                            fillGradient: ConicalGradient {
                                centerX: win.glowR; centerY: win.glowR
                                angle: ring.spin
                                GradientStop { position: 0.00; color: root.cBlue }
                                GradientStop { position: 0.25; color: root.cPeach }
                                GradientStop { position: 0.50; color: root.cRed }
                                GradientStop { position: 0.75; color: root.cSapphire }
                                GradientStop { position: 1.00; color: root.cBlue }
                            }
                            // outer circle (CW)
                            startX: win.glowR + win.ringOuter; startY: win.glowR
                            PathAngleArc {
                                centerX: win.glowR; centerY: win.glowR
                                radiusX: win.ringOuter; radiusY: win.ringOuter
                                startAngle: 0; sweepAngle: 360
                            }
                            // inner circle (CCW) -> even-odd carves the hole
                            PathMove { x: win.glowR + win.ringInner; y: win.glowR }
                            PathAngleArc {
                                centerX: win.glowR; centerY: win.glowR
                                radiusX: win.ringInner; radiusY: win.ringInner
                                startAngle: 0; sweepAngle: -360
                            }
                        }
                    }

                    // ---- pulsing core orb ------------------------------------
                    Shape {
                        id: core
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        SequentialAnimation on opacity {
                            running: true; loops: Animation.Infinite
                            NumberAnimation { from: 0.55; to: 0.95; duration: 2600; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.95; to: 0.55; duration: 2600; easing.type: Easing.InOutSine }
                        }

                        ShapePath {
                            strokeWidth: 0
                            fillGradient: RadialGradient {
                                centerX: win.glowR; centerY: win.glowR
                                centerRadius: win.coreR
                                focalX: win.glowR; focalY: win.glowR
                                GradientStop { position: 0.0; color: root.af(root.cBlue, 0.45) }
                                GradientStop { position: 0.6; color: root.af(root.cPeach, 0.18) }
                                GradientStop { position: 1.0; color: root.af(root.cBlue, 0.0) }
                            }
                            startX: win.glowR + win.coreR; startY: win.glowR
                            PathAngleArc {
                                centerX: win.glowR; centerY: win.glowR
                                radiusX: win.coreR; radiusY: win.coreR
                                startAngle: 0; sweepAngle: 360
                            }
                        }
                    }

                    // ---- venomous serpent emblem (theme-reactive, interactive) ----
                    Canvas {
                        id: serpent
                        anchors.fill: parent
                        antialiasing: true
                        renderTarget: Canvas.FramebufferObject

                        readonly property real maxR:  win.ringInner * 0.82
                        readonly property real baseW: Math.max(2, win.height * 0.0090)

                        // Interaction state (driven by the MouseArea below).
                        // sway: head turns toward the cursor. arousal: 0 calm -> 1 alert.
                        // strike: brief lunge on click.
                        property real sway: 0
                        property real arousal: hovered ? 1 : 0
                        property real strike: 0
                        property bool hovered: false

                        rotation: sway
                        scale: 1 + strike + (hovered ? 0.05 : 0)
                        transformOrigin: Item.Center

                        Behavior on sway    { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
                        Behavior on arousal { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                        Behavior on scale   { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                        onArousalChanged: requestPaint()

                        // Quick strike lunge on click.
                        SequentialAnimation {
                            id: strikeAnim
                            NumberAnimation { target: serpent; property: "strike"; from: 0; to: 0.22; duration: 90; easing.type: Easing.OutQuad }
                            NumberAnimation { target: serpent; property: "strike"; to: 0; duration: 300; easing.type: Easing.OutBack }
                        }

                        // Repaint whenever the wallpaper-driven palette updates.
                        Connections {
                            target: root
                            function onCBlueChanged()     { serpent.requestPaint() }
                            function onCPeachChanged()    { serpent.requestPaint() }
                            function onCSapphireChanged()  { serpent.requestPaint() }
                            function onCRedChanged()       { serpent.requestPaint() }
                            function onCBaseChanged()      { serpent.requestPaint() }
                        }

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var cx = width / 2, cy = height / 2;
                            var turns = 2.6, steps = 260, maxR = serpent.maxR;
                            var bw = serpent.baseW;
                            var arous = serpent.arousal;

                            // Spiral spine: t=0 tail (center) -> t=1 head (outer edge).
                            var pts = [];
                            for (var i = 0; i <= steps; i++) {
                                var t = i / steps;
                                var ang = t * turns * 2 * Math.PI;
                                var r = maxR * (0.04 + 0.96 * t);
                                pts.push({ x: cx + r * Math.cos(ang), y: cy + r * Math.sin(ang), t: t });
                            }
                            function bodyW(t) { return bw * (0.18 + 1.7 * t); }   // thin tail -> thick neck

                            ctx.lineCap = "round";
                            ctx.lineJoin = "round";

                            // 1) Danger glow halo (single pass, blurred shadow). Intensifies when alert.
                            ctx.save();
                            ctx.shadowColor = String(root.cRed);
                            ctx.shadowBlur = bw * (3.5 + 7 * arous);
                            ctx.strokeStyle = root.af(root.cRed, 0.45 + 0.3 * arous);
                            ctx.lineWidth = bw * 1.3;
                            ctx.beginPath();
                            ctx.moveTo(pts[0].x, pts[0].y);
                            for (var h = 1; h <= steps; h++) ctx.lineTo(pts[h].x, pts[h].y);
                            ctx.stroke();
                            ctx.restore();

                            // 2) Tapered body, deep gradient (dark -> sapphire -> blue -> peach -> venom red).
                            var g = ctx.createLinearGradient(cx - maxR, cy - maxR, cx + maxR, cy + maxR);
                            g.addColorStop(0.00, root.cBase);
                            g.addColorStop(0.18, root.cSapphire);
                            g.addColorStop(0.50, root.cBlue);
                            g.addColorStop(0.78, root.cPeach);
                            g.addColorStop(1.00, root.cRed);
                            ctx.strokeStyle = g;
                            for (var k = 1; k <= steps; k++) {
                                ctx.lineWidth = bodyW(pts[k].t);
                                ctx.beginPath();
                                ctx.moveTo(pts[k - 1].x, pts[k - 1].y);
                                ctx.lineTo(pts[k].x, pts[k].y);
                                ctx.stroke();
                            }

                            // 3) Glossy spine highlight running down the back (gives a lacquered sheen).
                            ctx.strokeStyle = "rgba(255,255,255,0.22)";
                            for (var s = 1; s <= steps; s++) {
                                ctx.lineWidth = Math.max(0.6, bodyW(pts[s].t) * 0.28);
                                ctx.beginPath();
                                ctx.moveTo(pts[s - 1].x, pts[s - 1].y);
                                ctx.lineTo(pts[s].x, pts[s].y);
                                ctx.stroke();
                            }

                            // ---- Head: an angular viper wedge facing along the tangent. ----
                            var head = pts[steps], back = pts[steps - 9];
                            var dx = head.x - back.x, dy = head.y - back.y;
                            var len = Math.hypot(dx, dy) || 1; dx /= len; dy /= len;
                            var px = -dy, py = dx;                       // perpendicular
                            var hw = bw * 2.0 * (1 + 0.12 * arous);
                            var nose = bw * (3.0 + 1.4 * arous);         // snout length, longer when striking

                            var tip = { x: head.x + dx * nose,            y: head.y + dy * nose };
                            var jL  = { x: head.x - dx * hw * 0.3 + px * hw * 1.25, y: head.y - dy * hw * 0.3 + py * hw * 1.25 };
                            var jR  = { x: head.x - dx * hw * 0.3 - px * hw * 1.25, y: head.y - dy * hw * 0.3 - py * hw * 1.25 };
                            var nape= { x: head.x - dx * hw * 1.1,        y: head.y - dy * hw * 1.1 };

                            var hg = ctx.createLinearGradient(nape.x, nape.y, tip.x, tip.y);
                            hg.addColorStop(0.0, root.cSapphire);
                            hg.addColorStop(0.6, root.cPeach);
                            hg.addColorStop(1.0, root.cRed);
                            ctx.fillStyle = hg;
                            ctx.beginPath();
                            ctx.moveTo(tip.x, tip.y);
                            ctx.lineTo(jL.x, jL.y);
                            ctx.quadraticCurveTo(nape.x, nape.y, jR.x, jR.y);
                            ctx.closePath();
                            ctx.fill();
                            ctx.strokeStyle = root.af(root.cBase, 0.85);
                            ctx.lineWidth = Math.max(0.8, bw * 0.28);
                            ctx.stroke();

                            // Fangs: two pale daggers under the snout.
                            ctx.fillStyle = "rgba(255,255,255,0.92)";
                            var fb = bw * 0.85;
                            var m  = { x: head.x + dx * nose * 0.55, y: head.y + dy * nose * 0.55 };
                            for (var f = -1; f <= 1; f += 2) {
                                var fx = m.x + px * fb * 0.5 * f, fy = m.y + py * fb * 0.5 * f;
                                ctx.beginPath();
                                ctx.moveTo(fx + px * fb * 0.35 * f, fy + py * fb * 0.35 * f);
                                ctx.lineTo(fx - px * fb * 0.35 * f, fy - py * fb * 0.35 * f);
                                ctx.lineTo(fx + dx * fb * 1.6,       fy + dy * fb * 1.6);
                                ctx.closePath();
                                ctx.fill();
                            }

                            // Eyes: glowing slit pupils, brighter when alert.
                            var eang = Math.atan2(dy, dx);
                            var ecx = head.x + dx * hw * 0.15, ecy = head.y + dy * hw * 0.15;
                            ctx.save();
                            ctx.shadowColor = String(root.cRed);
                            ctx.shadowBlur = bw * (1.5 + 3.5 * arous);
                            for (var e = -1; e <= 1; e += 2) {
                                var ex = ecx + px * hw * 0.62 * e, ey = ecy + py * hw * 0.62 * e;
                                ctx.fillStyle = "rgba(255,196,77," + (0.85 + 0.15 * arous) + ")";
                                ctx.beginPath();
                                ctx.ellipse(ex, ey, hw * 0.52, hw * 0.20, eang, 0, 2 * Math.PI);
                                ctx.fill();
                                ctx.fillStyle = String(root.cBase);          // vertical slit pupil
                                ctx.beginPath();
                                ctx.ellipse(ex, ey, hw * 0.40, hw * 0.07, eang, 0, 2 * Math.PI);
                                ctx.fill();
                            }
                            ctx.restore();

                            // Forked tongue: flicks out further the more alert it is.
                            var tlen = nose * (0.7 + 1.6 * arous);
                            ctx.save();
                            ctx.shadowColor = String(root.cRed);
                            ctx.shadowBlur = bw * (1.0 + 2.0 * arous);
                            ctx.strokeStyle = String(root.cRed);
                            ctx.lineWidth = Math.max(1, bw * 0.42);
                            var fork = { x: tip.x + dx * tlen, y: tip.y + dy * tlen };
                            ctx.beginPath(); ctx.moveTo(tip.x, tip.y); ctx.lineTo(fork.x, fork.y); ctx.stroke();
                            ctx.beginPath();
                            ctx.moveTo(fork.x, fork.y); ctx.lineTo(fork.x + dx * nose * 0.5 + px * hw * 0.7, fork.y + dy * nose * 0.5 + py * hw * 0.7);
                            ctx.moveTo(fork.x, fork.y); ctx.lineTo(fork.x + dx * nose * 0.5 - px * hw * 0.7, fork.y + dy * nose * 0.5 - py * hw * 0.7);
                            ctx.stroke();
                            ctx.restore();
                        }
                    }
                }

                // Pointer catcher over the emblem (drives the serpent's reactions).
                Item {
                    id: hitArea
                    anchors.centerIn: parent
                    width: win.ringOuter * 2.2
                    height: win.ringOuter * 2.2

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton

                        onEntered: serpent.hovered = true
                        onExited: { serpent.hovered = false; serpent.sway = 0; }
                        onPositionChanged: function (mouse) {
                            // Turn the head toward the cursor (clamped lean).
                            var off = (mouse.x - width / 2) / (width / 2);
                            serpent.sway = Math.max(-28, Math.min(28, off * 28));
                        }
                        onPressed: strikeAnim.restart()
                    }
                }
            }
        }
    }
}
