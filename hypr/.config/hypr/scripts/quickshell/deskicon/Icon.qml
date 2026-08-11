import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects

// Desktop BlackArch emblem (katana+chevron silhouette filled with a live wallpaper
// gradient + accent glow). Click it to open the "world" launcher: a large rotating
// wireframe earth with apps pinned to its surface, linked by a network of artificial
// lines, over a Matrix (cmatrix) rain backdrop.
ShellRoot {
    id: root

    property color accent: "#89b4fa"
    property bool launcherOpen: false
    property var apps: []
    property string lastAppsRaw: ""   // skip refreshes when the app list is unchanged

    function launch(execStr) {
        Quickshell.execDetached(["bash", "-c", "source \"$HOME/.config/hypr/scripts/compositor.sh\" && comp_dispatch_exec \"$1\"", "_", execStr]);
        root.launcherOpen = false;
    }

    Process {
        id: themeReader
        command: ["cat", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/qs_colors.json"]
        stdout: StdioCollector { onStreamFinished: { try { let c = JSON.parse(this.text.trim()); if (c.blue) root.accent = c.blue; } catch (e) {} } }
    }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: themeReader.running = true }

    Process {
        id: appFetcher
        running: true
        command: ["bash", "-c", "python3 " + Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/applauncher/app_fetcher.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var raw = this.text ? this.text.trim() : "";
                    if (!raw.length) return;
                    if (raw === root.lastAppsRaw) return;   // nothing changed -> don't reshuffle the globe
                    root.lastAppsRaw = raw;
                    var list = JSON.parse(raw);
                    if (list.length > 120) {
                        var step = list.length / 120, out = [];
                        for (var i = 0; i < 120; i++) out.push(list[Math.floor(i * step)]);
                        list = out;
                    }
                    root.apps = list;
                } catch (e) {}
            }
        }
    }

    // ---- live updates: re-fetch when an app is installed/removed ----
    Process {
        id: appWatcher
        running: true
        command: ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/applauncher/app_watch.sh"]
        stdout: SplitParser {
            onRead: function (line) {
                if (line.indexOf(".desktop") !== -1) appRefreshDebounce.restart();
            }
        }
    }
    // a single install can write many .desktop files; wait for the dust to settle, then refresh once
    Timer {
        id: appRefreshDebounce
        interval: 1200
        repeat: false
        onTriggered: appFetcher.running = true
    }

    // ---------------------------------------------------------------- the logo
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: logoWin
                required property var modelData
                screen: modelData
                WlrLayershell.namespace: "desk-icon"
                WlrLayershell.layer: WlrLayer.Bottom
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                anchors { top: true; bottom: true; left: true; right: true }

                property int glyphSize: Math.round(logoWin.height * 0.34)
                mask: Region { item: clickZone }

                property real breathe: 0.9
                SequentialAnimation on breathe {
                    running: true; loops: Animation.Infinite
                    NumberAnimation { from: 0.82; to: 1.0; duration: 3500; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.0; to: 0.82; duration: 3500; easing.type: Easing.InOutSine }
                }

                // faint enlarged accent wash behind the emblem (same as the old bg glyph)
                ColorOverlay {
                    anchors.centerIn: parent
                    width: baBody.width; height: baBody.height
                    source: baBody; color: root.accent
                    scale: 1.14; opacity: logoWin.breathe * 0.28; z: -2
                }
                // single-accent glow halo
                Glow {
                    anchors.fill: baBody; source: baBody; color: root.accent
                    radius: Math.round(logoWin.glyphSize * 0.10); samples: 33; spread: 0.25
                    opacity: logoWin.breathe; z: -1
                }
                // solid-filled BlackArch emblem, white body — same single-accent treatment
                // the old Arch glyph used (white fill + accent glow).
                Image {
                    id: baBody
                    anchors.centerIn: parent
                    source: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/deskicon/blackarch-solid.png"
                    width: logoWin.glyphSize; height: logoWin.glyphSize
                    sourceSize.width: logoWin.glyphSize; sourceSize.height: logoWin.glyphSize
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    opacity: logoWin.breathe
                }
                Item {
                    id: clickZone; anchors.centerIn: parent
                    width: logoWin.glyphSize * 0.62; height: logoWin.glyphSize
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.launcherOpen = true }
                }
            }
        }
    }

    // ------------------------------------------------------- the world launcher
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: gWin
                required property var modelData
                screen: modelData
                WlrLayershell.namespace: "desk-globe"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: root.launcherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                exclusionMode: ExclusionMode.Ignore
                focusable: root.launcherOpen
                color: "transparent"
                anchors { top: true; bottom: true; left: true; right: true }
                visible: true

                Item { id: fullArea; anchors.fill: parent }
                Item { id: noArea; width: 0; height: 0 }
                mask: Region { item: root.launcherOpen ? fullArea : noArea }

                property real cx: width / 2
                property real cy: height / 2
                property real globeR: height * 0.24      // bigger world
                property real tilt: 0.40                 // pitch; now fully draggable (see backdrop drag)
                property real baseIcon: height * 0.044
                property int count: root.apps.length
                property int hoverCount: 0
                property real yaw: 0

                // ---- search state ----
                property string query: ""
                property int selCursor: 0
                // indices of root.apps matching `query`, ranked: name-prefix, then name-substr, then exec-substr
                property var matchList: {
                    var q = gWin.query, apps = root.apps;
                    if (q === "") return [];
                    var starts = [], incl = [], ex = [];
                    for (var i = 0; i < apps.length; i++) {
                        var n = (apps[i].name || "").toLowerCase();
                        var e = (apps[i].exec || "").toLowerCase();
                        if (n.indexOf(q) === 0) starts.push(i);
                        else if (n.indexOf(q) !== -1) incl.push(i);
                        else if (e.indexOf(q) !== -1) ex.push(i);
                    }
                    return starts.concat(incl).concat(ex);
                }
                property int bestIndex: matchList.length > 0
                    ? matchList[Math.max(0, Math.min(selCursor, matchList.length - 1))] : -1
                function appMatches(app) {
                    if (gWin.query === "") return true;
                    var n = (app.name || "").toLowerCase(), e = (app.exec || "").toLowerCase();
                    return n.indexOf(gWin.query) !== -1 || e.indexOf(gWin.query) !== -1;
                }

                // spin + pitch the globe so app `i` lands dead-center, facing the viewer
                function flyTo(i) {
                    var N = Math.max(root.apps.length, 1);
                    var phi = Math.acos(1 - 2 * (i + 0.5) / N), th = 2.399963229728653 * i;
                    var ux = Math.sin(phi) * Math.cos(th), uy = Math.cos(phi), uz = Math.sin(phi) * Math.sin(th);
                    var magh = Math.sqrt(ux * ux + uz * uz);
                    var yawTarget = Math.atan2(uz, ux) - Math.PI / 2;   // brings longitude to front meridian
                    var tiltTarget = Math.atan2(uy, magh);              // brings latitude to center, depth = 1
                    var twoPi = 2 * Math.PI;
                    var d = yawTarget - gWin.yaw;
                    d = d - twoPi * Math.floor((d + Math.PI) / twoPi);   // shortest way round
                    yawAnim.stop(); tiltAnim.stop();
                    yawAnim.from = gWin.yaw; yawAnim.to = gWin.yaw + d; yawAnim.start();
                    tiltAnim.from = gWin.tilt; tiltAnim.to = tiltTarget; tiltAnim.start();
                }
                onBestIndexChanged: if (bestIndex >= 0) flyTo(bestIndex);

                NumberAnimation { id: yawAnim;  target: gWin; property: "yaw";  duration: 620; easing.type: Easing.OutCubic }
                NumberAnimation { id: tiltAnim; target: gWin; property: "tilt"; duration: 620; easing.type: Easing.OutCubic }

                property real reveal: root.launcherOpen ? 1 : 0
                Behavior on reveal { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                // slow auto-rotation; pauses while hovering, searching, or flying to a result
                FrameAnimation {
                    running: gWin.reveal > 0.01 && gWin.hoverCount === 0 && gWin.query === "" && !yawAnim.running
                    onTriggered: gWin.yaw += frameTime * 0.16
                }

                // grab the keyboard the moment the world opens; reset search each time
                Connections {
                    target: root
                    function onLauncherOpenChanged() {
                        if (root.launcherOpen) {
                            searchInput.text = ""; gWin.query = ""; gWin.selCursor = 0;
                            gWin.tilt = 0.40;
                            focusGrab.restart();
                        }
                    }
                }
                Timer { id: focusGrab; interval: 40; repeat: false; onTriggered: searchInput.forceActiveFocus() }

                // surface point for app i -> screen pos + depth (front when depth>0)
                // yaw and n are passed in so bindings that call this track them as deps.
                function surf(i, yaw, n) {
                    var N = Math.max(n, 1);
                    var phi = Math.acos(1 - 2 * (i + 0.5) / N);
                    var th = 2.399963229728653 * i;
                    var ux = Math.sin(phi) * Math.cos(th);
                    var uy = Math.cos(phi);
                    var uz = Math.sin(phi) * Math.sin(th);
                    var rx = ux * Math.cos(yaw) + uz * Math.sin(yaw);
                    var rz = -ux * Math.sin(yaw) + uz * Math.cos(yaw);
                    var sy = uy * Math.cos(gWin.tilt) - rz * Math.sin(gWin.tilt);
                    var depth = uy * Math.sin(gWin.tilt) + rz * Math.cos(gWin.tilt);
                    return { x: gWin.cx + gWin.globeR * rx, y: gWin.cy - gWin.globeR * sy, depth: depth };
                }

                // ---- deep-space backdrop: base + twinkling stars + edge vignette ----
                Rectangle { anchors.fill: parent; color: "#02030a"; opacity: gWin.reveal * 0.5; z: -100000 }
                Canvas {
                    id: starfield
                    anchors.fill: parent; z: -99999; opacity: gWin.reveal * 0.5
                    property var stars: []
                    property real twinkle: 0
                    onPaint: {
                        var ctx = getContext('2d'); ctx.reset();
                        if (stars.length === 0) {
                            for (var s = 0; s < 220; s++)
                                stars.push({ x: Math.random() * width, y: Math.random() * height,
                                             r: Math.random() * 1.4 + 0.2, p: Math.random() * 6.28, sp: 0.5 + Math.random() });
                        }
                        for (var i = 0; i < stars.length; i++) {
                            var st = stars[i];
                            var a = 0.12 + 0.4 * (0.5 + 0.5 * Math.sin(starfield.twinkle * st.sp + st.p));
                            ctx.beginPath(); ctx.arc(st.x, st.y, st.r, 0, 6.283);
                            ctx.fillStyle = Qt.alpha(i % 7 === 0 ? Qt.lighter(root.accent, 1.6) : "#ffffff", a);
                            ctx.fill();
                        }
                    }
                    Component.onCompleted: requestPaint()
                    Timer { interval: 90; running: gWin.reveal > 0.01; repeat: true; onTriggered: { starfield.twinkle += 0.09; starfield.requestPaint() } }
                }
                Canvas {
                    id: vignette
                    anchors.fill: parent; z: -99998; opacity: gWin.reveal
                    onPaint: {
                        var ctx = getContext('2d'); ctx.reset();
                        var g = ctx.createRadialGradient(width / 2, height / 2, Math.min(width, height) * 0.14,
                                                          width / 2, height / 2, Math.max(width, height) * 0.62);
                        g.addColorStop(0, "rgba(0,0,0,0)");
                        g.addColorStop(1, "rgba(0,0,3,0.7)");
                        ctx.fillStyle = g; ctx.fillRect(0, 0, width, height);
                    }
                    Component.onCompleted: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                }
                MouseArea {
                    anchors.fill: parent; z: -100000
                    property real lastX: 0
                    property real lastY: 0
                    property bool dragged: false
                    onPressed: function(m) { lastX = m.x; lastY = m.y; dragged = false; yawAnim.stop(); tiltAnim.stop() }
                    onPositionChanged: function(m) {
                        if (!pressed) return;
                        var dx = m.x - lastX, dy = m.y - lastY;
                        if (Math.abs(dx) > 2 || Math.abs(dy) > 2) dragged = true;
                        gWin.yaw -= dx * 0.006;                                              // spin (yaw, unlimited)
                        gWin.tilt = Math.max(-1.45, Math.min(1.45, gWin.tilt + dy * 0.006)); // pitch (clamped near poles)
                        lastX = m.x; lastY = m.y;
                    }
                    onReleased: function(m) { if (!dragged) root.launcherOpen = false }
                }

                // ---- the rotating earth: Matrix code inside, wireframe over it ----
                Item {
                    anchors.centerIn: parent
                    width: gWin.globeR * 3.0; height: gWin.globeR * 3.0
                    z: 0; opacity: gWin.reveal; scale: 0.9 + 0.1 * gWin.reveal
                    Glow { anchors.fill: sphere; source: sphere; color: root.accent; radius: 30; samples: 41; spread: 0.18 }

                    // atmospheric rim halo (fresnel-style glow hugging the globe edge)
                    Canvas {
                        id: atmosphere
                        anchors.fill: parent; z: -1
                        onPaint: {
                            var ctx = getContext('2d'); ctx.reset();
                            var R = gWin.globeR, ox = width / 2, oy = height / 2;
                            var g = ctx.createRadialGradient(ox, oy, R * 0.84, ox, oy, R * 1.24);
                            g.addColorStop(0.0, Qt.alpha(root.accent, 0.0));
                            g.addColorStop(0.5, Qt.alpha(root.accent, 0.30));
                            g.addColorStop(0.72, Qt.alpha(Qt.lighter(root.accent, 1.3), 0.18));
                            g.addColorStop(1.0, Qt.alpha(root.accent, 0.0));
                            ctx.beginPath(); ctx.arc(ox, oy, R * 1.24, 0, 6.283); ctx.fillStyle = g; ctx.fill();
                        }
                        Component.onCompleted: requestPaint()
                        Connections { target: root; function onAccentChanged() { atmosphere.requestPaint() } }
                    }

                    // living energy core: breathing glow + drifting motes + sweeping scan band (clipped to globe)
                    Canvas {
                        id: coreSphere
                        anchors.fill: parent
                        property var motes: []
                        property real t: 0
                        onPaint: {
                            var ctx = getContext('2d'); ctx.reset();
                            var R = gWin.globeR, ox = width / 2, oy = height / 2;
                            ctx.save();
                            ctx.beginPath(); ctx.arc(ox, oy, R - 2, 0, 2 * Math.PI); ctx.clip();

                            // faint deep fill
                            ctx.fillStyle = "rgba(2,4,12,0.45)";
                            ctx.fillRect(0, 0, width, height);

                            // breathing core glow
                            var pulse = 0.5 + 0.5 * Math.sin(coreSphere.t * 1.3);
                            var cg = ctx.createRadialGradient(ox, oy, 0, ox, oy, R * (0.55 + 0.12 * pulse));
                            cg.addColorStop(0, Qt.alpha(Qt.lighter(root.accent, 1.8), 0.55));
                            cg.addColorStop(0.5, Qt.alpha(root.accent, 0.22));
                            cg.addColorStop(1, Qt.alpha(root.accent, 0.0));
                            ctx.fillStyle = cg; ctx.fillRect(0, 0, width, height);

                            // drifting energy motes (squashed by pitch so they sit "inside" the sphere)
                            if (coreSphere.motes.length === 0) {
                                for (var m = 0; m < 36; m++) {
                                    var ang = Math.random() * 6.283, rr = Math.sqrt(Math.random()) * (R - 6);
                                    coreSphere.motes.push({ a: ang, r: rr, sz: Math.random() * 1.6 + 0.6,
                                                            sp: (Math.random() - 0.5) * 0.9, ph: Math.random() * 6.283 });
                                }
                            }
                            for (var i = 0; i < coreSphere.motes.length; i++) {
                                var p = coreSphere.motes[i];
                                var a2 = p.a + coreSphere.t * p.sp * 0.25;
                                var x = ox + Math.cos(a2) * p.r;
                                var y = oy + Math.sin(a2) * p.r * Math.cos(gWin.tilt);
                                var tw = 0.35 + 0.65 * (0.5 + 0.5 * Math.sin(coreSphere.t * 2 + p.ph));
                                ctx.beginPath(); ctx.arc(x, y, p.sz, 0, 6.283);
                                ctx.fillStyle = Qt.alpha(Qt.lighter(root.accent, 1.5), tw);
                                ctx.fill();
                            }

                            // sweeping scan band gliding up/down the globe
                            var sweep = oy + (R - 8) * Math.sin(coreSphere.t * 0.8);
                            var sg = ctx.createLinearGradient(0, sweep - 16, 0, sweep + 16);
                            sg.addColorStop(0, Qt.alpha(root.accent, 0.0));
                            sg.addColorStop(0.5, Qt.alpha(Qt.lighter(root.accent, 1.6), 0.30));
                            sg.addColorStop(1, Qt.alpha(root.accent, 0.0));
                            ctx.fillStyle = sg; ctx.fillRect(0, sweep - 16, width, 32);

                            ctx.restore();
                        }
                        Timer { interval: 55; running: gWin.reveal > 0.01; repeat: true; onTriggered: { coreSphere.t += 0.05; coreSphere.requestPaint() } }
                    }

                    Canvas {
                        id: sphere
                        anchors.fill: parent
                        onPaint: {
                            var ctx = getContext('2d'); ctx.reset();
                            var R = gWin.globeR, ox = width / 2, oy = height / 2;
                            // very faint edge shading so the code reads as a sphere
                            var g = ctx.createRadialGradient(ox - R * 0.4, oy - R * 0.45, R * 0.2, ox, oy, R);
                            g.addColorStop(0, Qt.alpha(Qt.lighter(root.accent, 1.5), 0.0));
                            g.addColorStop(0.75, Qt.alpha(root.accent, 0.0));
                            g.addColorStop(1, Qt.alpha(Qt.darker(root.accent, 2.0), 0.45));
                            ctx.beginPath(); ctx.arc(ox, oy, R, 0, 2 * Math.PI); ctx.fillStyle = g; ctx.fill();
                            for (var li = -2; li <= 2; li++) {
                                var lat = li * (Math.PI / 6);
                                var py = oy - R * Math.sin(lat) * Math.cos(gWin.tilt);
                                var pr = R * Math.cos(lat);
                                ctx.beginPath(); ctx.ellipse(ox - pr, py - pr * Math.sin(gWin.tilt), pr * 2, pr * 2 * Math.sin(gWin.tilt));
                                ctx.lineWidth = 1.1; ctx.strokeStyle = Qt.alpha(root.accent, 0.30); ctx.stroke();
                            }
                            for (var mi = 0; mi < 6; mi++) {
                                var phi = gWin.yaw + mi * (Math.PI / 6);
                                var rx = Math.abs(R * Math.cos(phi));
                                ctx.beginPath(); ctx.ellipse(ox - rx, oy - R, rx * 2, R * 2);
                                ctx.lineWidth = 1.1; ctx.strokeStyle = Qt.alpha("white", 0.08 + 0.22 * Math.abs(Math.sin(phi))); ctx.stroke();
                            }
                            ctx.beginPath(); ctx.arc(ox, oy, R, 0, 2 * Math.PI);
                            ctx.lineWidth = 1.6; ctx.strokeStyle = Qt.alpha("white", 0.5); ctx.stroke();
                        }
                        Connections { target: gWin; function onYawChanged() { sphere.requestPaint() } function onTiltChanged() { sphere.requestPaint() } }
                        Connections { target: root; function onAccentChanged() { sphere.requestPaint() } }
                    }
                }

                // ---- artificial network lines between surface apps ----
                Canvas {
                    id: links
                    anchors.fill: parent; z: 400; opacity: gWin.reveal
                    onPaint: {
                        var ctx = getContext('2d'); ctx.reset();
                        var N = gWin.count; if (N < 2) return;
                        var P = [];
                        for (var i = 0; i < N; i++) {
                            var phi = Math.acos(1 - 2 * (i + 0.5) / N), th = 2.399963229728653 * i;
                            var ux = Math.sin(phi) * Math.cos(th), uy = Math.cos(phi), uz = Math.sin(phi) * Math.sin(th);
                            var s = gWin.surf(i, gWin.yaw, gWin.count);
                            P.push({ x: s.x, y: s.y, d: s.depth, ux: ux, uy: uy, uz: uz });
                        }
                        for (var a = 0; a < N; a++) for (var b = a + 1; b < N; b++) {
                            var dot = P[a].ux * P[b].ux + P[a].uy * P[b].uy + P[a].uz * P[b].uz;
                            if (dot > 0.62 && P[a].d > -0.1 && P[b].d > -0.1) {
                                var al = 0.45 * ((dot - 0.62) / 0.38) * Math.max(0, Math.min(1, (P[a].d + P[b].d) / 2 + 0.3));
                                if (al <= 0.01) continue;
                                ctx.strokeStyle = Qt.alpha(root.accent, Math.min(0.5, al));
                                ctx.lineWidth = 1.0;
                                ctx.beginPath(); ctx.moveTo(P[a].x, P[a].y); ctx.lineTo(P[b].x, P[b].y); ctx.stroke();
                            }
                        }
                    }
                    Connections { target: gWin; function onYawChanged() { links.requestPaint() } function onTiltChanged() { links.requestPaint() } }
                }

                // ---- apps pinned to the earth surface ----
                Repeater {
                    model: root.apps
                    delegate: Item {
                        id: node
                        required property var modelData
                        required property int index
                        // depend on apps.length + reveal + yaw + tilt so it always recomputes
                        property var pos: { root.apps.length; gWin.reveal; gWin.yaw; gWin.tilt; return gWin.surf(node.index, gWin.yaw, root.apps.length); }
                        property real f: (node.pos.depth + 1) / 2
                        property bool hovered: hov.containsMouse
                        property bool isMatch: gWin.appMatches(node.modelData)
                        property bool isBest: gWin.query !== "" && node.index === gWin.bestIndex
                        property real matchDim: gWin.query === "" ? 1.0 : (node.isMatch ? 1.0 : 0.10)

                        width: gWin.baseIcon; height: gWin.baseIcon
                        x: node.pos.x - width / 2
                        y: node.pos.y - height / 2
                        z: Math.round(node.pos.depth * 1000) + (node.hovered ? 5000 : 0) + (node.isBest ? 9000 : 0)
                        scale: (0.55 + 0.5 * node.f) * (node.hovered ? 1.45 : 1.0) * (node.isBest ? 1.5 : 1.0) * gWin.reveal
                        opacity: (node.pos.depth > -0.05 ? (0.35 + 0.65 * node.f) : 0.0) * gWin.reveal * node.matchDim

                        property string iconName: node.modelData.icon || ""
                        // resolve up front; Quickshell.iconPath(name, true) returns "" when the
                        // icon is missing, so we can use a clean tile instead of a magenta placeholder
                        property string resolved: node.iconName === "" ? ""
                            : (node.iconName.charAt(0) === "/" ? "file://" + node.iconName
                               : Quickshell.iconPath(node.iconName, true))
                        property bool broken: node.resolved === ""

                        // frosted glass backing behind every themed icon (cohesion + legibility)
                        Rectangle {
                            anchors.fill: parent; radius: width * 0.26; z: -2
                            visible: !node.broken
                            color: Qt.rgba(0.10, 0.12, 0.18, 0.5)
                            border.width: Math.max(1, width * 0.03); border.color: Qt.alpha(root.accent, 0.25)
                        }

                        // pulsing ring around the active search result
                        Rectangle {
                            visible: node.isBest; anchors.centerIn: parent; z: -1
                            width: parent.width * 1.7; height: width; radius: width / 2
                            color: "transparent"
                            border.width: Math.max(2, parent.width * 0.06); border.color: root.accent
                            SequentialAnimation on scale {
                                running: node.isBest; loops: Animation.Infinite
                                NumberAnimation { from: 0.85; to: 1.12; duration: 700; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 1.12; to: 0.85; duration: 700; easing.type: Easing.InOutSine }
                            }
                        }
                        Image {
                            id: ico
                            anchors.fill: parent; visible: !node.broken
                            asynchronous: true; fillMode: Image.PreserveAspectFit
                            sourceSize.width: 80; sourceSize.height: 80
                            source: node.resolved
                            onStatusChanged: if (status === Image.Error) node.broken = true
                            layer.enabled: node.hovered
                            layer.effect: Glow { color: root.accent; radius: 16; samples: 21; spread: 0.4 }
                        }
                        // clean monogram tile for apps that have no themed icon
                        Rectangle {
                            anchors.fill: parent; visible: node.broken; radius: width * 0.26
                            color: Qt.rgba(0.09, 0.10, 0.14, 0.94)
                            border.width: Math.max(1, width * 0.04)
                            border.color: Qt.alpha(root.accent, 0.65)
                            Text {
                                anchors.centerIn: parent
                                text: (node.modelData.name || "?").charAt(0).toUpperCase()
                                color: Qt.lighter(root.accent, 1.5); font.bold: true
                                font.family: "JetBrains Mono"; font.pixelSize: parent.width * 0.52
                            }
                        }
                        // atmospheric fog: side/back icons recede into the dark
                        Rectangle {
                            anchors.fill: parent; radius: width * 0.26; z: 5
                            color: "#02030a"
                            opacity: Math.max(0, 1 - node.f) * 0.7
                        }

                        Rectangle {
                            visible: node.hovered || node.isBest; z: 10
                            anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.bottom; anchors.topMargin: 6
                            radius: 6; color: Qt.alpha("#000000", 0.8)
                            implicitWidth: lbl.implicitWidth + 16; implicitHeight: lbl.implicitHeight + 8
                            Text { id: lbl; anchors.centerIn: parent; text: node.modelData.name || ""; color: "white"; font.family: "JetBrains Mono"; font.pixelSize: 13 }
                        }
                        MouseArea {
                            id: hov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: gWin.hoverCount++
                            onExited: gWin.hoverCount--
                            onClicked: root.launch(node.modelData.exec)
                        }
                    }
                }

                // ---- search field: type a program, the world flies to it, Enter launches ----
                Rectangle {
                    id: searchBar
                    z: 600; opacity: gWin.reveal
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: Math.round(gWin.height * 0.055)
                    width: Math.round(gWin.width * 0.26); height: Math.round(gWin.height * 0.045)
                    radius: height / 2
                    color: Qt.alpha("#070b16", 0.80)
                    border.width: 1.5; border.color: Qt.alpha(root.accent, gWin.query === "" ? 0.6 : 1.0)

                    Text {
                        id: searchGlyph
                        anchors.left: parent.left; anchors.leftMargin: parent.height * 0.42
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""; font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: parent.height * 0.36; color: root.accent
                        layer.enabled: true
                        layer.effect: Glow { color: root.accent; radius: 7; samples: 15; spread: 0.3 }
                    }
                    Text {
                        id: countLabel
                        anchors.right: parent.right; anchors.rightMargin: parent.height * 0.5
                        anchors.verticalCenter: parent.verticalCenter
                        visible: gWin.query !== ""
                        text: gWin.matchList.length > 0
                            ? ((gWin.selCursor + 1) + "/" + gWin.matchList.length) : "no match"
                        color: gWin.matchList.length > 0 ? Qt.alpha(root.accent, 0.9) : Qt.alpha("#ff6b6b", 0.9)
                        font.family: "JetBrains Mono"; font.pixelSize: parent.height * 0.34
                    }
                    TextInput {
                        id: searchInput
                        anchors.left: searchGlyph.right; anchors.leftMargin: parent.height * 0.36
                        anchors.right: countLabel.left; anchors.rightMargin: parent.height * 0.3
                        anchors.verticalCenter: parent.verticalCenter
                        color: "white"; clip: true; selectByMouse: true
                        font.family: "JetBrains Mono"; font.pixelSize: parent.height * 0.40
                        onTextChanged: { gWin.query = text.trim().toLowerCase(); gWin.selCursor = 0 }
                        Keys.onPressed: function (e) {
                            if (e.key === Qt.Key_Escape) { root.launcherOpen = false; e.accepted = true; }
                            else if (e.key === Qt.Key_Down) { if (gWin.matchList.length > 0) gWin.selCursor = (gWin.selCursor + 1) % gWin.matchList.length; e.accepted = true; }
                            else if (e.key === Qt.Key_Up) { if (gWin.matchList.length > 0) gWin.selCursor = (gWin.selCursor - 1 + gWin.matchList.length) % gWin.matchList.length; e.accepted = true; }
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (gWin.bestIndex >= 0) root.launch(root.apps[gWin.bestIndex].exec); e.accepted = true; }
                        }
                        Text {
                            anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                            visible: searchInput.text === ""
                            text: "Search programs…"; color: Qt.alpha("white", 0.4); font: searchInput.font
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: searchBar.top; anchors.bottomMargin: Math.round(gWin.height * 0.018)
                    text: "type to search  ·  ↑↓ to pick  ·  ↵ to launch  ·  drag to rotate (any direction)  ·  esc / click empty to close"
                    color: Qt.alpha(root.accent, 0.85); opacity: gWin.reveal * 0.7
                    font.family: "JetBrains Mono"; font.pixelSize: 13
                }
            }
        }
    }
}
