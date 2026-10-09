import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

// RAM check + task manager. Data comes from procs.py, which only runs while
// this window is visible. End task is two-click and limited to the user's own,
// non-essential processes.
Item {
    id: root
    visible: false
    focus: true

    function s(val) {
        return Scaler.s(val);
    }

    // Killing any of these takes the desktop session down with it.
    readonly property var protectedNames: [
        "quickshell", "Hyprland", "Xwayland", "Xorg", "systemd", "(sd-pam)",
        "dbus-broker", "dbus-broker-lau", "dbus-daemon", "pipewire", "pipewire-pulse",
        "wireplumber", "sddm", "sddm-helper", "serpantinumd", "xdg-desktop-por",
        "xdg-document-po", "xdg-permission-"
    ]

    property real memTotal: 0
    property real memUsed: 0
    property real memCached: 0
    property real swapTotal: 0
    property real swapUsed: 0
    property real cpuPct: 0
    property int procCount: 0
    property var lastProcs: []

    property string sortKey: "rss"   // "rss" | "cpu"
    property string filterText: ""
    property int confirmPid: -1

    property real introBase: 0.0

    function fmtBytes(b) {
        if (b >= 1073741824) return (b / 1073741824).toFixed(1) + " GB";
        if (b >= 1048576) return Math.round(b / 1048576) + " MB";
        return Math.round(b / 1024) + " KB";
    }

    function isProtected(p) {
        return !p.mine || root.protectedNames.indexOf(p.name) !== -1;
    }

    function rebuildModel() {
        let q = root.filterText.trim().toLowerCase();
        let rows = root.lastProcs.filter(p => q === "" || p.name.toLowerCase().indexOf(q) !== -1
                                               || p.cmd.toLowerCase().indexOf(q) !== -1
                                               || String(p.pid) === q);
        let key = root.sortKey;
        rows.sort((a, b) => (b[key] - a[key]) || (b.rss - a.rss));

        // Update in place so the list keeps its scroll position between ticks.
        for (let i = 0; i < rows.length; i++) {
            let r = rows[i];
            let obj = { pid: r.pid, name: r.name, cmd: r.cmd, rss: r.rss, cpu: r.cpu, locked: root.isProtected(r) };
            if (i < procModel.count) procModel.set(i, obj);
            else procModel.append(obj);
        }
        if (procModel.count > rows.length) procModel.remove(rows.length, procModel.count - rows.length);
    }

    onSortKeyChanged: { rebuildModel(); procList.positionViewAtBeginning(); }
    onFilterTextChanged: { rebuildModel(); procList.positionViewAtBeginning(); }

    ListModel { id: procModel }

    Process {
        id: feed
        running: root.visible
        command: ["python3", Caching.serpantinumDir + "/quickshell/taskmanager/procs.py", "1.5"]
        stdout: SplitParser {
            onRead: (line) => {
                let d;
                try { d = JSON.parse(line); } catch (e) { return; }
                root.memTotal = d.memTotal;
                root.memUsed = d.memUsed;
                root.memCached = d.memCached;
                root.swapTotal = d.swapTotal;
                root.swapUsed = d.swapUsed;
                root.cpuPct = d.cpu;
                root.procCount = d.procs.length;
                root.lastProcs = d.procs;
                root.rebuildModel();
            }
        }
    }

    Process {
        id: killer
        property int target: -1
        command: ["kill", "-TERM", String(target)]
    }

    function endTask(pid) {
        killer.target = pid;
        killer.running = true;
        root.confirmPid = -1;
    }

    Timer {
        id: confirmReset
        interval: 3000
        onTriggered: root.confirmPid = -1
    }

    NumberAnimation {
        id: introAnim
        target: root; property: "introBase"
        from: 0.0; to: 1.0; duration: 350; easing.type: Easing.OutQuint
    }

    SequentialAnimation {
        id: closeSequence
        NumberAnimation { target: root; property: "introBase"; to: 0.0; duration: 200; easing.type: Easing.InQuart }
        ScriptAction { script: Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "close"]) }
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: filterInput.forceActiveFocus()
    }

    onVisibleChanged: {
        if (visible) {
            focusTimer.restart();
            introAnim.restart();
        } else {
            introAnim.stop();
            introBase = 0.0;
            filterText = "";
            filterInput.text = "";
            confirmPid = -1;
        }
    }

    Component.onCompleted: {
        if (visible) {
            focusTimer.restart();
            introAnim.restart();
        }
    }

    Keys.onEscapePressed: (event) => { closeSequence.start(); event.accepted = true; }

    component UsageBar: Rectangle {
        id: bar
        property string label
        property string valueText
        property real fraction: 0
        property color accent: ThemeBackend.mauve
        property real secondaryFraction: 0   // e.g. cache, drawn faintly behind

        Layout.fillWidth: true
        Layout.preferredHeight: root.s(58)
        radius: ThemeBackend.borderRadius
        color: Qt.alpha(ThemeBackend.surface0, 0.6)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.s(12)
            spacing: root.s(8)

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: bar.label
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(13)
                    font.weight: Font.Bold
                    color: ThemeBackend.text
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: bar.valueText
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(12)
                    color: ThemeBackend.subtext0
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.s(8)
                radius: height / 2
                color: ThemeBackend.surface1

                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: parent.width * Math.min(1, bar.fraction + bar.secondaryFraction)
                    color: Qt.alpha(bar.accent, 0.3)
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
                }
                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: parent.width * Math.min(1, bar.fraction)
                    color: bar.fraction > 0.85 ? ThemeBackend.red : bar.accent
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        opacity: root.introBase
        scale: 0.95 + (0.05 * root.introBase)

        Rectangle {
            anchors.fill: parent
            radius: ThemeBackend.clampedBorderRadius
            color: ThemeBackend.base
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.s(16)
            spacing: root.s(10)

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Task Manager"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(16)
                    font.weight: Font.Bold
                    color: ThemeBackend.text
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.procCount + " processes"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(12)
                    color: ThemeBackend.subtext0
                }
            }

            UsageBar {
                label: "RAM"
                fraction: root.memTotal > 0 ? root.memUsed / root.memTotal : 0
                secondaryFraction: root.memTotal > 0 ? root.memCached / root.memTotal : 0
                valueText: root.fmtBytes(root.memUsed) + " / " + root.fmtBytes(root.memTotal)
                           + "  ·  " + root.fmtBytes(root.memCached) + " cache"
                accent: ThemeBackend.mauve
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(10)
                UsageBar {
                    label: "CPU"
                    fraction: root.cpuPct / 100
                    valueText: root.cpuPct.toFixed(0) + "%"
                    accent: ThemeBackend.blue
                }
                UsageBar {
                    label: "Swap"
                    fraction: root.swapTotal > 0 ? root.swapUsed / root.swapTotal : 0
                    valueText: root.fmtBytes(root.swapUsed) + " / " + root.fmtBytes(root.swapTotal)
                    accent: ThemeBackend.peach
                }
            }

            // Filter + sort
            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(8)

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(36)
                    radius: ThemeBackend.borderRadius
                    color: Qt.alpha(ThemeBackend.surface0, 0.6)
                    border.width: filterInput.activeFocus ? 1 : 0
                    border.color: ThemeBackend.mauve

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: root.s(12)
                        verticalAlignment: Text.AlignVCenter
                        visible: filterInput.text.length === 0
                        text: "Filter by name, command or PID"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(12)
                        color: ThemeBackend.overlay0
                    }

                    TextInput {
                        id: filterInput
                        anchors.fill: parent
                        anchors.leftMargin: root.s(12)
                        anchors.rightMargin: root.s(12)
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(12)
                        color: ThemeBackend.text
                        selectionColor: Qt.alpha(ThemeBackend.mauve, 0.4)
                        clip: true
                        onTextChanged: root.filterText = text
                        Keys.onEscapePressed: (event) => {
                            if (text.length > 0) { text = ""; event.accepted = true; }
                            else { closeSequence.start(); event.accepted = true; }
                        }
                    }
                }

                Repeater {
                    model: [ { key: "rss", label: "Memory" }, { key: "cpu", label: "CPU" } ]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool active: root.sortKey === modelData.key
                        Layout.preferredWidth: root.s(84)
                        Layout.preferredHeight: root.s(36)
                        radius: ThemeBackend.borderRadius
                        color: active ? ThemeBackend.mauve
                                      : (sortMa.containsMouse ? ThemeBackend.surface1 : Qt.alpha(ThemeBackend.surface0, 0.6))
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(12)
                            font.weight: parent.active ? Font.Bold : Font.Medium
                            color: parent.active ? ThemeBackend.crust : ThemeBackend.subtext0
                        }
                        MouseArea {
                            id: sortMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.sortKey = modelData.key
                        }
                    }
                }
            }

            // Column header
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: root.s(12)
                Layout.rightMargin: root.s(12)
                spacing: root.s(10)
                Text { text: "Name"; Layout.fillWidth: true; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(11); color: ThemeBackend.overlay1 }
                Text { text: "PID"; Layout.preferredWidth: root.s(60); horizontalAlignment: Text.AlignRight; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(11); color: ThemeBackend.overlay1 }
                Text { text: "Memory"; Layout.preferredWidth: root.s(80); horizontalAlignment: Text.AlignRight; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(11); color: root.sortKey === "rss" ? ThemeBackend.mauve : ThemeBackend.overlay1 }
                Text { text: "CPU"; Layout.preferredWidth: root.s(56); horizontalAlignment: Text.AlignRight; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(11); color: root.sortKey === "cpu" ? ThemeBackend.mauve : ThemeBackend.overlay1 }
                Item { Layout.preferredWidth: root.s(78) }
            }

            ListView {
                id: procList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: root.s(4)
                model: procModel
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: row
                    required property int index
                    required property int pid
                    required property string name
                    required property string cmd
                    required property real rss
                    required property real cpu
                    required property bool locked
                    readonly property bool confirming: root.confirmPid === pid

                    width: procList.width
                    height: root.s(44)
                    radius: ThemeBackend.borderRadius
                    color: rowMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.6) : Qt.alpha(ThemeBackend.surface0, 0.35)

                    MouseArea { id: rowMa; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: root.s(12)
                        anchors.rightMargin: root.s(8)
                        spacing: root.s(10)

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: row.name
                                elide: Text.ElideRight
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(13)
                                font.weight: Font.Medium
                                color: ThemeBackend.text
                            }
                            Text {
                                Layout.fillWidth: true
                                text: row.cmd
                                visible: row.cmd.length > 0
                                elide: Text.ElideMiddle
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(10)
                                color: ThemeBackend.overlay0
                            }
                        }
                        Text {
                            Layout.preferredWidth: root.s(60)
                            horizontalAlignment: Text.AlignRight
                            text: row.pid
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(11)
                            color: ThemeBackend.subtext0
                        }
                        Text {
                            Layout.preferredWidth: root.s(80)
                            horizontalAlignment: Text.AlignRight
                            text: root.fmtBytes(row.rss)
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(12)
                            font.weight: Font.Bold
                            color: row.rss > 1073741824 ? ThemeBackend.peach : ThemeBackend.text
                        }
                        Text {
                            Layout.preferredWidth: root.s(56)
                            horizontalAlignment: Text.AlignRight
                            text: row.cpu.toFixed(1) + "%"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(12)
                            color: row.cpu > 25 ? ThemeBackend.peach : ThemeBackend.subtext0
                        }

                        Rectangle {
                            Layout.preferredWidth: root.s(78)
                            Layout.preferredHeight: root.s(28)
                            radius: ThemeBackend.borderRadius
                            opacity: row.locked ? 0.35 : 1.0
                            color: row.confirming ? ThemeBackend.red
                                 : (endMa.containsMouse && !row.locked ? Qt.alpha(ThemeBackend.red, 0.18) : "transparent")
                            border.width: 1
                            border.color: row.locked ? ThemeBackend.surface2 : Qt.alpha(ThemeBackend.red, 0.6)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: row.locked ? "System" : (row.confirming ? "Confirm" : "End task")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(11)
                                font.weight: Font.Bold
                                color: row.confirming ? ThemeBackend.crust : (row.locked ? ThemeBackend.overlay0 : ThemeBackend.red)
                            }
                            MouseArea {
                                id: endMa
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !row.locked
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (row.confirming) {
                                        root.endTask(row.pid);
                                    } else {
                                        root.confirmPid = row.pid;
                                        confirmReset.restart();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
