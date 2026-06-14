import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects

// Standalone desktop audio visualizer: a continuous wave that traces the Arch
// logo's triangular silhouette (with a little gap), pulsing live with cava.
// Above the wallpaper, below windows, fully click-through.
ShellRoot {
    id: root

    property color accent: "#89b4fa"
    property color accent2: "#fab387"
    function af(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    readonly property int barCount: 120
    property var levels: []

    Process {
        id: themeReader
        command: ["cat", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/qs_colors.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let c = JSON.parse(this.text.trim());
                    if (c.blue)  root.accent  = c.blue;
                    if (c.peach) root.accent2 = c.peach;
                } catch (e) {}
            }
        }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: themeReader.running = true }

    Process {
        id: cava
        running: true
        command: ["cava", "-p", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/audioviz/cava.conf"]
        stdout: SplitParser {
            onRead: function (line) {
                if (!line) return;
                var parts = line.split(";");
                var out = [];
                for (var i = 0; i < root.barCount && i < parts.length; i++) {
                    var v = parseInt(parts[i]);
                    out.push(isNaN(v) ? 0 : v);
                }
                if (out.length) root.levels = out;
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: win
                required property var modelData
                screen: modelData

                WlrLayershell.namespace: "desk-audioviz"
                WlrLayershell.layer: WlrLayer.Bottom
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                anchors { top: true; bottom: true; left: true; right: true }
                mask: Region {}                       // click-through

                // smoothed levels, so the wave glides instead of jittering
                property var sm: []
                readonly property real ampMax: win.height * 0.085

                // Arch-logo triangle (relative to centre), sized to hug the glyph + a little gap
                function corners() {
                    var S = win.height;
                    return [
                        { x: 0,           y: -S * 0.150 },   // apex
                        { x: -S * 0.140,  y:  S * 0.112 },   // bottom-left
                        { x:  S * 0.140,  y:  S * 0.112 }    // bottom-right
                    ];
                }

                function buildWave() {
                    var cx = win.width / 2, cy = win.height / 2;
                    var c = corners();
                    var edges = [[c[0], c[1]], [c[1], c[2]], [c[2], c[0]]];
                    var lens = [];
                    var total = 0;
                    for (var k = 0; k < 3; k++) {
                        lens[k] = Math.hypot(edges[k][1].x - edges[k][0].x, edges[k][1].y - edges[k][0].y);
                        total += lens[k];
                    }
                    var n = root.levels.length || 1;
                    if (win.sm.length !== n) { win.sm = []; for (var s = 0; s < n; s++) win.sm[s] = 0; }
                    for (var z = 0; z < n; z++) win.sm[z] += ((root.levels[z] || 0) - win.sm[z]) * 0.38;  // ease

                    var M = 264, pts = [];
                    for (var i = 0; i <= M; i++) {
                        var t = (i % M) / M;
                        var dist = t * total, ei = 0, acc = 0;
                        while (ei < 2 && dist > acc + lens[ei]) { acc += lens[ei]; ei++; }
                        var loc = lens[ei] > 0 ? (dist - acc) / lens[ei] : 0;
                        var e = edges[ei];
                        var px = e[0].x + (e[1].x - e[0].x) * loc;
                        var py = e[0].y + (e[1].y - e[0].y) * loc;
                        var dx = e[1].x - e[0].x, dy = e[1].y - e[0].y;
                        var nx = dy, ny = -dx, nl = Math.hypot(nx, ny) || 1; nx /= nl; ny /= nl;
                        if (nx * px + ny * py < 0) { nx = -nx; ny = -ny; }      // outward
                        var fb = t * n, bi = Math.floor(fb) % n, bn = (bi + 1) % n, fr = fb - Math.floor(fb);
                        var amp = ((win.sm[bi] * (1 - fr) + win.sm[bn] * fr) / 100) * win.ampMax;
                        pts.push(Qt.point(cx + px + nx * amp, cy + py + ny * amp));
                    }
                    wave.pts = pts;
                }

                Timer { interval: 33; running: true; repeat: true; onTriggered: win.buildWave() }

                Shape {
                    id: wave
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    property var pts: []

                    layer.enabled: true
                    layer.effect: Glow { radius: 14; samples: 19; spread: 0.3; color: root.accent }

                    ShapePath {
                        strokeColor: root.af(root.accent, 0.95)
                        strokeWidth: win.height * 0.0032
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        PathPolyline { path: wave.pts }
                    }
                }
            }
        }
    }
}
