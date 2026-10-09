import QtQuick
import QtQuick.Layouts
import Quickshell
import "../"

// Browser picker (Super+F). Lists every installed app whose .desktop file is in
// the WebBrowser category, so newly installed browsers show up on their own.
// Keys: ←/→ or Tab to move, Enter/Space to open, 1-9 to open directly, Esc to close.
Item {
    id: root
    visible: false
    focus: true

    function s(val) {
        return Scaler.s(val);
    }

    property var browsers: []
    property int selected: 0
    property real introBase: 0.0

    function refresh() {
        let list = [];
        if (typeof DesktopEntries !== "undefined" && DesktopEntries.applications) {
            let all = DesktopEntries.applications.values;
            for (let i = 0; i < all.length; i++) {
                let e = all[i];
                if (!e || e.noDisplay) continue;
                let cats = e.categories || [];
                if (cats.indexOf("WebBrowser") !== -1) list.push(e);
            }
        }
        list.sort((a, b) => a.name.localeCompare(b.name));
        root.browsers = list;
        if (root.selected >= list.length) root.selected = 0;
    }

    function iconFor(entry) {
        if (!entry || !entry.icon) return "";
        return Quickshell.iconPath(entry.icon, true) || "";
    }

    function launch(index) {
        let e = root.browsers[index];
        if (!e) return;
        e.execute();
        closeSequence.start();
    }

    Connections {
        target: (typeof DesktopEntries !== "undefined" && DesktopEntries.applications) ? DesktopEntries.applications : null
        ignoreUnknownSignals: true
        function onValuesChanged() { root.refresh(); }
    }

    NumberAnimation {
        id: introAnim
        target: root; property: "introBase"
        from: 0.0; to: 1.0; duration: 300; easing.type: Easing.OutQuint
    }

    SequentialAnimation {
        id: closeSequence
        NumberAnimation { target: root; property: "introBase"; to: 0.0; duration: 160; easing.type: Easing.InQuart }
        ScriptAction { script: Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "close"]) }
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: root.forceActiveFocus()
    }

    onVisibleChanged: {
        if (visible) {
            refresh();
            selected = 0;
            forceActiveFocus();
            focusTimer.restart();
            introAnim.restart();
        } else {
            introAnim.stop();
            introBase = 0.0;
        }
    }

    Component.onCompleted: {
        refresh();
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            introAnim.restart();
        }
    }

    Keys.onPressed: (event) => {
        let n = root.browsers.length;
        if (event.key === Qt.Key_Escape) {
            closeSequence.start();
        } else if (n === 0) {
            return;
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab || event.key === Qt.Key_L) {
            root.selected = (root.selected + 1) % n;
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab || event.key === Qt.Key_H) {
            root.selected = (root.selected - 1 + n) % n;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.launch(root.selected);
        } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            let idx = event.key - Qt.Key_1;
            if (idx < n) root.launch(idx);
        } else {
            return;
        }
        event.accepted = true;
    }

    Item {
        anchors.fill: parent
        opacity: root.introBase
        scale: 0.94 + (0.06 * root.introBase)

        Rectangle {
            anchors.fill: parent
            radius: ThemeBackend.clampedBorderRadius
            color: ThemeBackend.base
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.s(16)
            spacing: root.s(12)

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Open a browser"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(15)
                    font.weight: Font.Bold
                    color: ThemeBackend.text
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "←/→ select · Enter open · 1-" + Math.max(1, root.browsers.length) + " quick pick"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(11)
                    color: ThemeBackend.overlay0
                }
            }

            Text {
                visible: root.browsers.length === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "No browsers found"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(13)
                color: ThemeBackend.subtext0
            }

            RowLayout {
                visible: root.browsers.length > 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: root.s(12)

                Repeater {
                    model: root.browsers
                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        required property int index
                        readonly property bool active: root.selected === index

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: ThemeBackend.borderRadius
                        color: active ? Qt.alpha(ThemeBackend.mauve, 0.16)
                                      : (cardMa.containsMouse ? ThemeBackend.surface1 : Qt.alpha(ThemeBackend.surface0, 0.6))
                        border.width: active ? 2 : 0
                        border.color: ThemeBackend.mauve
                        scale: cardMa.pressed ? 0.97 : (active ? 1.0 : 0.98)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }

                        Text {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: root.s(10)
                            text: card.index + 1
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(11)
                            font.weight: Font.Bold
                            color: card.active ? ThemeBackend.mauve : ThemeBackend.overlay0
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: root.s(10)

                            Image {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: root.s(64)
                                Layout.preferredHeight: root.s(64)
                                sourceSize.width: root.s(128)
                                sourceSize.height: root.s(128)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                source: root.iconFor(card.modelData)
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.maximumWidth: card.width - root.s(20)
                                text: card.modelData.name
                                elide: Text.ElideRight
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(13)
                                font.weight: card.active ? Font.Bold : Font.Medium
                                color: ThemeBackend.text
                            }
                        }

                        MouseArea {
                            id: cardMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selected = card.index
                            onClicked: root.launch(card.index)
                        }
                    }
                }
            }
        }
    }
}
