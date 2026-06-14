import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import QtQuick.Window
import "../"

// BlackArch arsenal browser — "Cyberpunk Neon" look: wallpaper-toned glass,
// dramatic CRT power-on intro, dual red+cyan glow, animated scanlines + sweep,
// glitching title, neon-outlined controls, and a right-side category HUD rail.
// Data comes from blackarch_fetcher.py.
Item {
    id: window
    focus: true

    // injected by Main.qml's executeSwitch (declared so the props assign cleanly)
    property int layoutWidth: 0
    property int layoutHeight: 0
    property var notifModel
    property var liveNotifs

    Caching { id: paths }
    Scaler { id: scaler; currentWidth: Screen.width; currentHeight: Screen.height }
    readonly property real sf: scaler.baseScale
    function s(v) { return Math.round(v * window.sf); }

    MatugenColors { id: th }
    // neon dual-tone: wallpaper red + electric cyan. green stays for installed/launch.
    readonly property color neon: th.red
    readonly property color neon2: "#ff2f48"       // bright crimson — black + red theme
    readonly property color accent: th.red
    readonly property color cardBg: "#150406"      // dark red-black for cards / fields / rows
    readonly property color glassBorder: Qt.alpha(neon, 0.22)

    // -------------------------------------------------------------- data
    property var categories: []
    property int selectedCat: 0
    property string query: ""
    property bool loading: true

    readonly property var curCat: window.categories.length
        ? window.categories[Math.min(window.selectedCat, window.categories.length - 1)] : null

    property var toolsView: {
        window.categories; window.selectedCat; window.query;
        if (!window.curCat) return [];
        var q = window.query.trim().toLowerCase();
        if (!q) return window.curCat.tools;
        return window.curCat.tools.filter(function (t) { return t.name.toLowerCase().indexOf(q) !== -1; });
    }

    // map a blackarch category name → a Nerd Font glyph (FontAwesome range, very stable)
    function iconFor(name) {
        var n = (name || "").toLowerCase();
        var map = [
            ["anti-forensic",""], ["forensic",""], ["recon",""], ["scan",""],
            ["webapp",""], ["web",""], ["proxy",""], ["tunnel",""],
            ["fuzz",""], ["exploit",""], ["dos",""], ["crack",""],
            ["crypto",""], ["sniff",""], ["spoof",""], ["fingerprint",""],
            ["wireless",""], ["wifi",""], ["radio",""], ["nfc",""],
            ["bluetooth",""], ["mobile",""], ["malware",""], ["backdoor",""],
            ["keylog",""], ["social",""], ["defensive",""], ["ids",""],
            ["binary",""], ["hardware",""], ["gpu",""], ["reversing",""],
            ["disasm",""], ["decompiler",""], ["debugger",""], ["code",""],
            ["networking",""], ["database",""], ["dns",""], ["voip",""],
            ["windows",""], ["honeypot",""], ["stego",""], ["automation",""],
            ["packer",""], ["unpacker",""], ["scada",""], ["drone",""],
            ["automobile",""], ["car",""]
        ];
        for (var i = 0; i < map.length; i++) if (n.indexOf(map[i][0]) !== -1) return map[i][1];
        return ""; // default: shield
    }

    Process {
        id: fetcher
        running: true
        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/blackarch/blackarch_fetcher.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text);
                    if (d && d.categories) window.categories = d.categories;
                } catch (e) {}
                window.loading = false;
            }
        }
    }

    function refresh() { window.loading = true; fetcher.running = true; }
    onVisibleChanged: if (visible) { refresh(); bootAnim.restart(); }

    function install(tool) {
        Quickshell.execDetached(["kitty", "--hold", "sudo", "pacman", "-S", "--needed", "blackarch/" + tool]);
    }
    function launch(tool) {
        Quickshell.execDetached(["kitty", "--hold", "bash", "-lc", tool]);
    }
    function closePage() {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
    }

    // ---- reusable neon glow (border halo that lifts on hover/selection) -----
    component NeonGlow : MultiEffect {
        property color glow: window.neon2
        shadowEnabled: true
        shadowColor: glow
        shadowBlur: 1.0
        blurMax: 40
        shadowVerticalOffset: 0
        shadowHorizontalOffset: 0
        autoPaddingEnabled: true
    }

    // ---- dramatic CRT "power-on" intro ----
    property real intro: 0      // content fade-in
    property real reveal: 0     // vertical CRT open (0 = thin line, 1 = full height)
    property real flash: 0      // cyan power-on flash
    property real pop: 1.0      // overshoot scale
    Component.onCompleted: bootAnim.start()
    ParallelAnimation {
        id: bootAnim
        NumberAnimation { target: window; property: "reveal"; from: 0;    to: 1;   duration: 480; easing.type: Easing.OutExpo }
        NumberAnimation { target: window; property: "flash";  from: 1.0;  to: 0;   duration: 560; easing.type: Easing.OutCubic }
        NumberAnimation { target: window; property: "pop";    from: 1.06; to: 1.0; duration: 560; easing.type: Easing.OutBack }
        SequentialAnimation {
            PauseAnimation { duration: 150 }
            NumberAnimation { target: window; property: "intro"; from: 0; to: 1; duration: 300; easing.type: Easing.OutCubic }
        }
    }

    // slow "breathing" neon pulse (drives both auras, in counter-phase)
    property real pulse: 0.18
    SequentialAnimation on pulse {
        loops: Animation.Infinite; running: true
        NumberAnimation { to: 0.40; duration: 1700; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.18; duration: 1700; easing.type: Easing.InOutSine }
    }

    // -------------------------------------------------------------- dual neon aura (behind panel)
    Rectangle { id: auraSrc; anchors.fill: frame; radius: frame.radius; color: window.neon; visible: false }
    MultiEffect {
        source: auraSrc; anchors.fill: auraSrc
        blurEnabled: true; blur: 1.0; blurMax: 90; autoPaddingEnabled: true
        opacity: window.reveal * window.pulse; z: -2
    }
    Rectangle { id: auraSrc2; anchors.fill: frame; radius: frame.radius; color: window.neon2; visible: false }
    MultiEffect {
        source: auraSrc2; anchors.fill: auraSrc2
        blurEnabled: true; blur: 1.0; blurMax: 70; autoPaddingEnabled: true
        opacity: window.reveal * (0.58 - window.pulse); z: -1
    }

    // -------------------------------------------------------------- frame (wallpaper-toned glass)
    Rectangle {
        id: frame
        anchors.fill: parent
        radius: window.s(22)
        clip: true

        // background = deep black with a red tint up top (BlackArch black+red identity)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha("#1c050a", 0.96) }
            GradientStop { position: 1.0; color: Qt.alpha("#000000", 0.985) }
        }
        border.color: Qt.rgba(1, 1, 1, 0.16)
        border.width: 1

        // CRT power-on: open vertically from a line, with a slight overshoot
        transform: Scale {
            origin.x: frame.width / 2; origin.y: frame.height / 2
            xScale: window.pop
            yScale: Math.max(0.02, window.reveal) * window.pop
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.alpha("black", 0.85)
            shadowBlur: 1.0
            blurMax: 64
            shadowVerticalOffset: window.s(18)
            autoPaddingEnabled: true
        }

        // specular sheen — liquid-glass refractive highlight (non-interactive, behind content)
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            antialiasing: true
            gradient: Gradient {
                GradientStop { position: 0.0;  color: Qt.rgba(1, 1, 1, 0.18) }
                GradientStop { position: 0.30; color: Qt.rgba(1, 1, 1, 0.0) }
                GradientStop { position: 1.0;  color: Qt.rgba(0, 0, 0, 0.05) }
            }
        }

        // top neon edge — red→cyan electric line
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.margins: window.s(2)
            height: window.s(2); radius: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.alpha(window.neon, 0.0) }
                GradientStop { position: 0.3; color: window.neon }
                GradientStop { position: 0.7; color: window.neon2 }
                GradientStop { position: 1.0; color: Qt.alpha(window.neon2, 0.0) }
            }
        }

        // top sheen
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: parent.height * 0.4; radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(window.neon2, 0.05) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: window.s(18)
            spacing: window.s(16)
            opacity: window.intro   // content fades in after the panel snaps open

            // ============================ SIDEBAR (glass card)
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: window.s(238)
                radius: window.s(16)
                color: Qt.alpha(window.cardBg, 0.55)
                border.color: window.glassBorder
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: window.s(14)
                    spacing: window.s(12)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: window.s(11)
                        Rectangle {
                            width: window.s(36); height: window.s(36); radius: window.s(11)
                            color: Qt.alpha(window.neon, 0.16)
                            border.color: Qt.alpha(window.neon, 0.45); border.width: 1
                            layer.enabled: true
                            layer.effect: NeonGlow { glow: window.neon }
                            Text { anchors.centerIn: parent; text: "󰣚"; font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(19); color: window.neon }
                        }
                        ColumnLayout {
                            spacing: window.s(1)
                            Item {
                                id: glitch
                                property real off: 0
                                implicitWidth: gBase.implicitWidth
                                implicitHeight: gBase.implicitHeight
                                Text { text: "BlackArch"; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: window.s(16); color: window.neon2; x: -glitch.off - 1; y: -1; opacity: 0.65 }
                                Text { text: "BlackArch"; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: window.s(16); color: window.neon;  x:  glitch.off + 1; y:  1; opacity: 0.55 }
                                Text { id: gBase; text: "BlackArch"; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: window.s(16); color: th.text }
                                Timer {
                                    running: window.visible; repeat: true; interval: 110
                                    onTriggered: glitch.off = (Math.random() < 0.22) ? (Math.random() * window.s(4)) : 0
                                }
                            }
                            Text { text: "› " + window.categories.length + " categories"; font.family: "JetBrains Mono"; font.pixelSize: window.s(10); color: window.neon2 }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: window.glassBorder }

                    ListView {
                        id: catList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: window.categories
                        spacing: window.s(4)
                        currentIndex: window.selectedCat
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: catList.width - window.s(8)
                            height: window.s(42)

                            Rectangle {
                                id: catCard
                                anchors.fill: parent
                                anchors.margins: window.s(1)
                                radius: window.s(11)
                                property bool sel: index === window.selectedCat
                                color: sel ? Qt.alpha(window.neon, 0.16)
                                            : (cma.containsMouse ? Qt.alpha(window.neon2, 0.08) : "transparent")
                                border.color: sel ? Qt.alpha(window.neon, 0.55)
                                                  : (cma.containsMouse ? Qt.alpha(window.neon2, 0.35) : "transparent")
                                border.width: 1
                                scale: cma.containsMouse && !sel ? 1.01 : 1.0
                                Behavior on color { ColorAnimation { duration: 130 } }
                                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutQuad } }

                                layer.enabled: catCard.sel
                                layer.effect: NeonGlow { glow: window.neon }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left; anchors.leftMargin: window.s(6)
                                    width: window.s(3); height: parent.height * 0.5; radius: window.s(2)
                                    color: window.neon; visible: catCard.sel
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: window.s(16); anchors.rightMargin: window.s(12)
                                    spacing: window.s(8)
                                    Text {
                                        text: (window.iconFor(modelData.name)) + "  " + modelData.name
                                        font.family: "Iosevka Nerd Font"
                                        font.weight: catCard.sel ? Font.Bold : Font.Medium
                                        font.pixelSize: window.s(12)
                                        color: catCard.sel ? th.text : th.subtext0
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                    }
                                    Text {
                                        text: (modelData.installed > 0 ? modelData.installed + "/" : "") + modelData.total
                                        font.family: "JetBrains Mono"; font.pixelSize: window.s(10)
                                        color: modelData.installed > 0 ? th.green : th.overlay0
                                    }
                                }
                                MouseArea {
                                    id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { window.selectedCat = index; window.query = ""; }
                                }
                            }
                        }
                    }
                }
            }

            // ============================ CONTENT
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: window.s(14)

                // header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: window.s(12)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Item {
                            id: catTitle
                            property string label: window.curCat ? window.curCat.name : "loading…"
                            implicitWidth: ctBase.implicitWidth
                            implicitHeight: ctBase.implicitHeight
                            Text { text: catTitle.label; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: window.s(28); color: window.neon2; x: -2; y: -1; opacity: 0.5 }
                            Text { text: catTitle.label; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: window.s(28); color: window.neon;  x:  2; y:  1; opacity: 0.4 }
                            Text { id: ctBase; text: catTitle.label; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: window.s(28); color: th.text }
                        }
                        Text {
                            text: "▸ " + window.toolsView.length + " tools" + (window.query ? "  ·  filtered" : "")
                            font.family: "JetBrains Mono"; font.pixelSize: window.s(12); color: window.neon2
                        }
                    }
                    // refresh
                    Rectangle {
                        width: window.s(42); height: window.s(42); radius: window.s(13)
                        color: rma.containsMouse ? Qt.alpha(window.neon2, 0.16) : Qt.alpha(window.cardBg, 0.5)
                        border.color: rma.containsMouse ? Qt.alpha(window.neon2, 0.7) : window.glassBorder; border.width: 1
                        scale: rma.containsMouse ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: 130 } }
                        layer.enabled: rma.containsMouse
                        layer.effect: NeonGlow { glow: window.neon2 }
                        Text {
                            anchors.centerIn: parent; text: "󰑐"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(18)
                            color: window.loading ? th.yellow : (rma.containsMouse ? window.neon2 : th.subtext0)
                            RotationAnimation on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: window.loading }
                        }
                        MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: window.refresh() }
                    }
                    // close
                    Rectangle {
                        width: window.s(42); height: window.s(42); radius: window.s(13)
                        color: xma.containsMouse ? Qt.alpha(window.neon, 0.16) : Qt.alpha(window.cardBg, 0.5)
                        border.color: xma.containsMouse ? Qt.alpha(window.neon, 0.7) : window.glassBorder; border.width: 1
                        scale: xma.containsMouse ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: 130 } }
                        layer.enabled: xma.containsMouse
                        layer.effect: NeonGlow { glow: window.neon }
                        Text { anchors.centerIn: parent; text: "󰅖"; font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(17); color: xma.containsMouse ? window.neon : th.subtext0 }
                        MouseArea { id: xma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: window.closePage() }
                    }
                }

                // search (glass field)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.s(46)
                    radius: window.s(14)
                    color: Qt.alpha(window.cardBg, 0.5)
                    border.color: searchInput.activeFocus ? Qt.alpha(window.neon2, 0.8) : window.glassBorder
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    layer.enabled: searchInput.activeFocus
                    layer.effect: NeonGlow { glow: window.neon2 }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: window.s(16); anchors.rightMargin: window.s(16)
                        spacing: window.s(10)
                        Text { text: "󰍉"; font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(16); color: searchInput.activeFocus ? window.neon2 : th.subtext0 }
                        TextField {
                            id: searchInput
                            Layout.fillWidth: true
                            placeholderText: "search tools in this category…"
                            color: th.text
                            placeholderTextColor: th.overlay0
                            font.family: "JetBrains Mono"; font.pixelSize: window.s(13)
                            background: null
                            onTextChanged: window.query = text
                            Keys.onEscapePressed: { if (text.length) text = ""; else window.closePage(); }
                        }
                    }
                }

                // ---- list + right-side category HUD rail ----
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: window.s(14)

                    // tool list (glass card)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: window.s(16)
                        color: Qt.alpha("#0a0103", 0.5)
                        border.color: window.glassBorder; border.width: 1
                        clip: true

                        ListView {
                            id: toolList
                            anchors.fill: parent
                            anchors.margins: window.s(10)
                            clip: true
                            model: window.toolsView
                            spacing: window.s(7)
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                            delegate: Item {
                                required property var modelData
                                width: toolList.width - window.s(6)
                                height: window.s(54)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: window.s(12)
                                    color: tma.containsMouse ? Qt.alpha(window.neon2, 0.10) : Qt.alpha(window.cardBg, 0.45)
                                    border.color: modelData.installed ? Qt.alpha(th.green, 0.45)
                                                  : (tma.containsMouse ? Qt.alpha(window.neon2, 0.4) : window.glassBorder)
                                    border.width: 1
                                    scale: tma.containsMouse ? 1.008 : 1.0
                                    Behavior on color { ColorAnimation { duration: 130 } }
                                    Behavior on border.color { ColorAnimation { duration: 130 } }
                                    Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutQuad } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: window.s(16); anchors.rightMargin: window.s(12)
                                        spacing: window.s(12)

                                        Rectangle {
                                            width: window.s(30); height: window.s(30); radius: window.s(9)
                                            color: modelData.installed ? Qt.alpha(th.green, 0.16) : Qt.alpha(window.neon2, 0.06)
                                            border.color: modelData.installed ? Qt.alpha(th.green, 0.4) : Qt.alpha(window.neon2, 0.2)
                                            border.width: 1
                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.installed ? "" : "󰏖"
                                                font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(15)
                                                color: modelData.installed ? th.green : window.neon2
                                            }
                                        }
                                        Text {
                                            text: modelData.name
                                            font.family: "JetBrains Mono"; font.weight: Font.Medium; font.pixelSize: window.s(13)
                                            color: th.text; Layout.fillWidth: true; elide: Text.ElideRight
                                        }

                                        // LAUNCH (installed)
                                        Rectangle {
                                            visible: modelData.installed
                                            width: window.s(98); height: window.s(36); radius: window.s(11)
                                            color: lma.containsMouse ? Qt.alpha(th.green, 0.28) : Qt.alpha(th.green, 0.12)
                                            border.color: Qt.alpha(th.green, lma.containsMouse ? 0.8 : 0.55); border.width: 1
                                            scale: lma.containsMouse ? 1.04 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }
                                            Behavior on color { ColorAnimation { duration: 130 } }
                                            layer.enabled: lma.containsMouse
                                            layer.effect: NeonGlow { glow: th.green }
                                            RowLayout { anchors.centerIn: parent; spacing: window.s(6)
                                                Text { text: "󰐊"; font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(14); color: th.green }
                                                Text { text: "Launch"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: window.s(11); color: th.green }
                                            }
                                            MouseArea { id: lma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: window.launch(modelData.name) }
                                        }
                                        // INSTALL (not installed)
                                        Rectangle {
                                            visible: !modelData.installed
                                            width: window.s(98); height: window.s(36); radius: window.s(11)
                                            color: ima.containsMouse ? Qt.alpha(window.neon2, 0.22) : Qt.alpha(window.neon2, 0.06)
                                            border.color: ima.containsMouse ? Qt.alpha(window.neon2, 0.8) : Qt.alpha(window.neon2, 0.35); border.width: 1
                                            scale: ima.containsMouse ? 1.04 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }
                                            Behavior on color { ColorAnimation { duration: 130 } }
                                            layer.enabled: ima.containsMouse
                                            layer.effect: NeonGlow { glow: window.neon2 }
                                            RowLayout { anchors.centerIn: parent; spacing: window.s(6)
                                                Text { text: "󰇚"; font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(14); color: ima.containsMouse ? window.neon2 : th.subtext0 }
                                                Text { text: "Install"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: window.s(11); color: ima.containsMouse ? window.neon2 : th.subtext0 }
                                            }
                                            MouseArea { id: ima; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: window.install(modelData.name) }
                                        }
                                    }
                                    MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: window.toolsView.length === 0
                            text: window.loading ? "loading arsenal…" : "no tools match"
                            font.family: "JetBrains Mono"; font.pixelSize: window.s(14); color: th.subtext0
                        }
                    }

                    // ============================ CATEGORY HUD RAIL (right)
                    Rectangle {
                        Layout.preferredWidth: window.s(168)
                        Layout.fillHeight: true
                        radius: window.s(16)
                        color: Qt.alpha(window.cardBg, 0.55)
                        border.color: window.glassBorder; border.width: 1
                        clip: true

                        // faint neon backdrop glow
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 1.1; height: parent.width * 1.1; radius: width / 2
                            color: Qt.alpha(window.neon2, 0.05)
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: window.s(16)
                            spacing: window.s(10)

                            Item { Layout.fillHeight: true }

                            // big animated category glyph
                            Text {
                                id: railIcon
                                Layout.alignment: Qt.AlignHCenter
                                property string label: window.curCat ? window.curCat.name : ""
                                text: window.iconFor(label)
                                font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(80)
                                color: window.neon2
                                layer.enabled: true
                                layer.effect: NeonGlow { glow: window.neon2 }
                                transform: Scale { id: railScale; origin.x: railIcon.width / 2; origin.y: railIcon.height / 2 }
                                onLabelChanged: railPop.restart()
                                SequentialAnimation {
                                    id: railPop
                                    ParallelAnimation {
                                        NumberAnimation { target: railIcon; property: "opacity"; to: 0.15; duration: 110 }
                                        NumberAnimation { target: railScale; property: "xScale"; to: 0.8; duration: 110 }
                                        NumberAnimation { target: railScale; property: "yScale"; to: 0.8; duration: 110 }
                                    }
                                    ParallelAnimation {
                                        NumberAnimation { target: railIcon; property: "opacity"; to: 1.0; duration: 380; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: railScale; property: "xScale"; to: 1.0; duration: 440; easing.type: Easing.OutBack }
                                        NumberAnimation { target: railScale; property: "yScale"; to: 1.0; duration: 440; easing.type: Easing.OutBack }
                                    }
                                }
                            }

                            // category name
                            Text {
                                Layout.fillWidth: true
                                text: (railIcon.label || "—").toUpperCase()
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: window.s(15); color: th.text
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: window.glassBorder }

                            // counts
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: window.s(2)
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: (window.curCat ? window.curCat.total : 0) + " tools"
                                    font.family: "JetBrains Mono"; font.pixelSize: window.s(12); color: window.neon2
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "󰄬 " + (window.curCat ? window.curCat.installed : 0) + " installed"
                                    font.family: "JetBrains Mono"; font.pixelSize: window.s(11); color: th.green
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------- CRT overlay (visual only)
        Canvas {
            id: scan
            anchors.fill: parent
            opacity: 0.06; z: 90
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.strokeStyle = "#ffffff"; ctx.lineWidth = 1;
                for (var y = 0; y < height; y += window.s(3)) {
                    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
                }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }
        // moving CRT sweep bar
        Rectangle {
            id: sweep
            width: parent.width; height: window.s(90); z: 91; opacity: 0.5
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.alpha(window.neon2, 0.10) }
                GradientStop { position: 1.0; color: "transparent" }
            }
            NumberAnimation on y {
                from: -window.s(90); to: frame.height
                duration: 3800; loops: Animation.Infinite; running: window.visible
                easing.type: Easing.Linear
            }
        }
        // power-on flash + horizontal scan line
        Rectangle {
            anchors.fill: parent; z: 95
            opacity: window.flash * 0.55
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha("white", 0.6) }
                GradientStop { position: 1.0; color: window.neon2 }
            }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.97; height: window.s(2); z: 96
            color: "white"; opacity: window.flash
        }
    }
}
