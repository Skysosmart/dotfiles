import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects

// Standalone desktop audio visualizer: a smooth ring around the BlackArch logo whose
// radius pulses with the audio (mirrored spectrum, so it stays symmetric). Driven by
// cava. Above the wallpaper, below windows, fully click-through.
ShellRoot {
    id: root

    property color accent: "#89b4fa"
    property color accent2: "#fab387"
    function af(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    readonly property int barCount: 120
    property var levels: []

    // ring colour uses the SAME source as the BlackArch logo: matugen's primary (c.blue)
    // from qs_colors.json, so the ring and the logo always share one accent.
    Process {
        id: themeReader
        command: ["cat", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/qs_colors.json"]
        stdout: StdioCollector { onStreamFinished: { try { let c = JSON.parse(this.text.trim()); if (c.blue) root.accent = c.blue; } catch (e) {} } }
    }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: themeReader.running = true }

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
                readonly property real baseR:  win.height * 0.195   // ring radius, sits around the logo
                readonly property real ampMax: win.height * 0.030   // ripple depth

                // Smooth pulsing ring: a circle around the logo whose radius is modulated by the
                // audio. The spectrum is mirrored low->high->low across the vertical axis so the
                // ring stays symmetric and seamless. Trivial + robust: no tracing, no self-overlap.
                function buildWave() {
                    var cx = win.width / 2, cy = win.height / 2;

                    var n = root.levels.length || 1;
                    if (win.sm.length !== n) { win.sm = []; for (var s = 0; s < n; s++) win.sm[s] = 0; }
                    for (var z = 0; z < n; z++) win.sm[z] += ((root.levels[z] || 0) - win.sm[z]) * 0.22;  // calm ease

                    var M = 360, pts = [], R = win.baseR, A = win.ampMax;
                    for (var i = 0; i <= M; i++) {
                        var t = i / M;
                        var bf = (t < 0.5 ? t * 2 : (1 - t) * 2) * (n - 1);   // mirror so halves match
                        var bi = Math.floor(bf), bn = Math.min(bi + 1, n - 1), fr = bf - bi;
                        var amp = ((win.sm[bi] * (1 - fr) + win.sm[bn] * fr) / 100) * A;
                        var ang = -Math.PI / 2 + t * 2 * Math.PI;             // start at top, go around
                        var r = R + amp;
                        pts.push(Qt.point(cx + Math.cos(ang) * r, cy + Math.sin(ang) * r));
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
                    layer.effect: Glow { radius: 22; samples: 29; spread: 0.5; color: root.accent }

                    ShapePath {
                        strokeColor: "white"
                        strokeWidth: win.height * 0.0034
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
