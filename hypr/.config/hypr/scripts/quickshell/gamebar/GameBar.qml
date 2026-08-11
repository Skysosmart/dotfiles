import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import "../"

// Capture HUD styled after the Windows 11 Xbox Game Bar "Capture" widget:
//   a small dark themed-acrylic window with a header (drag grip · "Capture"
//   title · close button) over a row of flat Fluent capture buttons.
//   Surfaces/text/accents follow the live matugen palette (recolors w/ wallpaper).
// Buttons drive ~/.config/hypr/scripts/screenshot.sh (the existing backend):
//   region shot · fullscreen shot · shot+edit · record toggle · open folder.
// Recording state is polled live so the REC button reflects reality.
Item {
    id: window
    focus: true

    // injected by Main.qml's executeSwitch
    property int layoutWidth: 0
    property int layoutHeight: 0
    property var notifModel
    property var liveNotifs

    Scaler { id: scaler; currentWidth: Screen.width; currentHeight: Screen.height }
    readonly property real sf: scaler.baseScale
    function s(v) { return Math.round(v * window.sf); }

    MatugenColors { id: th }

    // -------------------------------------------------------------- palette
    // Themed acrylic: surfaces + text track the live matugen palette
    // (qs_colors.json, hot-reloaded). Each capture button lights up in its
    // own accent on hover; the REC / close states use the theme red.
    readonly property color winFillTop:  Qt.alpha(th.surface0, 0.85)
    readonly property color winFillBot:  Qt.alpha(th.crust,    0.85)
    readonly property color headerFill:  Qt.alpha(th.text, 0.04)
    readonly property color hairline:    Qt.alpha(th.text, 0.10)
    readonly property color divider:     Qt.alpha(th.text, 0.07)
    readonly property color icon:        Qt.alpha(th.text, 0.85)
    readonly property color iconBright:  th.text
    readonly property color label:       th.subtext0
    readonly property color title:       th.text
    readonly property color grip:        Qt.alpha(th.overlay1, 0.9)
    readonly property color recRed:      th.red
    readonly property color closeRed:    th.red

    readonly property string sans: "Noto Sans"

    readonly property string home: Quickshell.env("HOME")
    readonly property string shot: home + "/.config/hypr/scripts/screenshot.sh"
    readonly property string qm:   home + "/.config/hypr/scripts/qs_manager.sh"

    // -------------------------------------------------------------- state
    property bool recording: false

    function closeBar() {
        Quickshell.execDetached(["bash", window.qm, "close"]);
    }

    // close the HUD first (so it isn't captured), then run the backend
    function runThenCapture(arg) {
        Quickshell.execDetached(["bash", "-c",
            "bash '" + window.qm + "' close; sleep 0.20; '" + window.shot + "' " + arg]);
    }

    function fire(action) {
        if (action === "region")      runThenCapture("");
        else if (action === "full")   runThenCapture("--full");
        else if (action === "edit")   runThenCapture("--edit");
        else if (action === "folder") {
            Quickshell.execDetached(["bash", "-c",
                "xdg-open \"${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots\" >/dev/null 2>&1"]);
        } else if (action === "close") {
            window.closeBar();
        } else if (action === "record") {
            // screenshot.sh is a self-contained smart-toggle: ONE call starts if idle,
            // stops & saves if already recording. We always defer to it (never decide
            // start/stop from our own state — that caused double-starts). Close the HUD
            // first so a *starting* recording is clean; harmless when stopping.
            Quickshell.execDetached(["bash", "-c",
                "bash '" + window.qm + "' close; sleep 0.25; '" + window.shot + "' --full --record"]);
        }
    }

    // -------------------------------------------------------------- recording poll
    Process {
        id: recPoll
        // authoritative: screenshot.sh creates rec_pid while recording, removes it on stop
        command: ["bash", "-c", "[ -f \"$HOME/.cache/quickshell/recording/rec_pid\" ] && echo REC || echo IDLE"]
        stdout: StdioCollector {
            onStreamFinished: window.recording = (this.text.trim() === "REC")
        }
    }
    Timer {
        interval: 700; repeat: true; running: true; triggeredOnStart: true
        onTriggered: { recPoll.running = false; recPoll.running = true; }
    }
    onVisibleChanged: if (visible) { recPoll.running = false; recPoll.running = true; }

    // -------------------------------------------------------------- intro
    property real intro: 0
    NumberAnimation on intro { from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic; running: true }

    // gentle pulse — used ONLY for the recording dot (no neon border breathing)
    property real pulse: 0.5
    SequentialAnimation on pulse {
        loops: Animation.Infinite; running: true
        NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.4; duration: 900; easing.type: Easing.InOutSine }
    }

    // -------------------------------------------------------------- button model
    // glyphs are MDI Nerd Font codepoints, rendered via String.fromCodePoint.
    // 'close' lives in the header, so it's not part of this row.
    property var actions: [
        { id: "region", type: "icon", cp: 0xF019E, caption: "Region", clr: th.blue     }, // crop
        { id: "full",   type: "icon", cp: 0xF0379, caption: "Screen", clr: th.sapphire }, // monitor
        { id: "edit",   type: "icon", cp: 0xF03EB, caption: "Edit",   clr: th.mauve    }, // pencil
        { id: "record", type: "rec",  cp: 0,       caption: "Record", clr: th.red      },
        { id: "folder", type: "icon", cp: 0xF024B, caption: "Files",  clr: th.peach    }  // folder
    ]

    Keys.onEscapePressed: { window.closeBar(); event.accepted = true; }

    // ============================================================== widget window
    Item {
        anchors.fill: parent
        opacity: window.intro
        transform: Translate { y: (1 - window.intro) * window.s(8) }

        Rectangle {
            id: card
            anchors.centerIn: parent

            readonly property real headerH: window.s(38)
            readonly property real bodyH:   window.s(78)
            readonly property real bodyPad: window.s(14)

            width: bodyRow.implicitWidth + bodyPad * 2
            height: headerH + window.s(1) + bodyH
            radius: window.s(10)
            antialiasing: true

            gradient: Gradient {
                GradientStop { position: 0.0; color: window.winFillTop }
                GradientStop { position: 1.0; color: window.winFillBot }
            }
            border.width: window.s(1)
            border.color: window.hairline

            // soft ambient lift, like a floating Windows widget
            layer.enabled: true
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: window.s(8)
                radius: window.s(30)
                samples: 25
                color: Qt.rgba(0, 0, 0, 0.45)
                transparentBorder: true
            }

            // ---------------------------------------------------- header bar
            Item {
                id: header
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: card.headerH

                // faint header tint + rounded top corners (clipped by card radius)
                Rectangle {
                    anchors.fill: parent
                    color: window.headerFill
                    radius: card.radius
                    // square off the bottom so it meets the divider cleanly
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: parent.radius
                        color: parent.color
                    }
                }

                // drag-grip dots (decorative — reads as a movable window)
                Grid {
                    id: gripDots
                    anchors { left: parent.left; leftMargin: window.s(13); verticalCenter: parent.verticalCenter }
                    columns: 2
                    rowSpacing: window.s(3)
                    columnSpacing: window.s(3)
                    Repeater {
                        model: 6
                        delegate: Rectangle {
                            width: window.s(2); height: window.s(2); radius: width / 2
                            color: window.grip
                        }
                    }
                }

                Text {
                    id: titleText
                    anchors { left: gripDots.right; leftMargin: window.s(11); verticalCenter: parent.verticalCenter }
                    text: "Capture"
                    color: window.title
                    font.family: window.sans
                    font.weight: Font.DemiBold
                    font.pixelSize: window.s(13)
                }

                // live recording chip (right beside the title)
                Row {
                    anchors { left: titleText.right; leftMargin: window.s(10); verticalCenter: parent.verticalCenter }
                    spacing: window.s(5)
                    visible: window.recording
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: window.s(8); height: window.s(8); radius: width / 2
                        color: window.recRed
                        opacity: 0.45 + 0.55 * window.pulse
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "REC"
                        color: window.recRed
                        font.family: window.sans
                        font.weight: Font.Bold
                        font.pixelSize: window.s(10)
                        font.letterSpacing: window.s(1)
                    }
                }

                // close button — Windows titlebar style (red fill on hover)
                Rectangle {
                    id: closeBtn
                    anchors { right: parent.right; rightMargin: window.s(6); verticalCenter: parent.verticalCenter }
                    width: window.s(34); height: window.s(26)
                    radius: window.s(6)
                    color: closeMa.containsMouse
                           ? (closeMa.pressed ? Qt.darker(window.closeRed, 1.2) : window.closeRed)
                           : "transparent"
                    Behavior on color { ColorAnimation { duration: 110 } }

                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(0xF0156) // close ✕
                        font.family: "Iosevka NF"
                        font.pixelSize: window.s(15)
                        color: closeMa.containsMouse ? "white" : window.icon
                    }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.closeBar()
                    }
                }
            }

            // ---------------------------------------------------- divider
            Rectangle {
                id: hr
                anchors { top: header.bottom; left: parent.left; right: parent.right }
                height: window.s(1)
                color: window.divider
            }

            // ---------------------------------------------------- body (capture buttons)
            Item {
                anchors { top: hr.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }

                RowLayout {
                    id: bodyRow
                    anchors.centerIn: parent
                    spacing: window.s(4)

                    Repeater {
                        model: window.actions
                        delegate: Item {
                            id: btn
                            required property var modelData
                            Layout.alignment: Qt.AlignVCenter
                            width: window.s(78); height: window.s(64)

                            property bool isRec: modelData.type === "rec"
                            property bool active: isRec && window.recording
                            property color accent: modelData.clr
                            property color glyphClr: btn.active
                                ? window.recRed
                                : (ma.containsMouse ? btn.accent : window.icon)

                            // flat Fluent hover/press fill — tinted with this button's accent
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: window.s(3)
                                radius: window.s(7)
                                color: btn.active
                                       ? Qt.alpha(window.recRed, 0.18)
                                       : (ma.pressed ? Qt.alpha(btn.accent, 0.26)
                                          : (ma.containsMouse ? Qt.alpha(btn.accent, 0.15) : "transparent"))
                                border.width: (ma.containsMouse || btn.active) ? window.s(1) : 0
                                border.color: Qt.alpha(btn.active ? window.recRed : btn.accent, 0.45)
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: window.s(4)

                                // icon area
                                Item {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: window.s(24); height: window.s(24)

                                    // standard glyph icon
                                    Text {
                                        visible: !btn.isRec
                                        anchors.centerIn: parent
                                        text: btn.isRec ? "" : String.fromCodePoint(btn.modelData.cp)
                                        // NOTE: use "Iosevka NF" (full font). "Iosevka Nerd Font"
                                        // resolves to an OLD ttf lacking newer MDI icons → tofu.
                                        font.family: "Iosevka NF"
                                        font.pixelSize: window.s(20)
                                        color: btn.glyphClr
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }

                                    // record indicator: filled circle that morphs into a stop square
                                    Rectangle {
                                        visible: btn.isRec
                                        anchors.centerIn: parent
                                        width: window.s(16); height: window.s(16)
                                        radius: btn.active ? window.s(3) : width / 2
                                        color: window.recRed
                                        Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        // pulsing ring while recording
                                        Rectangle {
                                            anchors.centerIn: parent
                                            visible: btn.active
                                            width: parent.width + window.s(8) * window.pulse + window.s(4)
                                            height: width; radius: width / 2
                                            color: "transparent"
                                            border.width: window.s(2)
                                            border.color: Qt.rgba(window.recRed.r, window.recRed.g,
                                                                  window.recRed.b, 0.7 - 0.5 * window.pulse)
                                        }
                                    }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: btn.active ? "Stop" : btn.modelData.caption
                                    font.family: window.sans
                                    font.weight: Font.Medium
                                    font.pixelSize: window.s(10)
                                    color: btn.active ? window.recRed
                                           : (ma.containsMouse ? btn.accent : window.label)
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                            }

                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.fire(btn.modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
