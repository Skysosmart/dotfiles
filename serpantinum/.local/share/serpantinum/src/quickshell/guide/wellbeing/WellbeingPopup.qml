import QtQuick
import Quickshell
import "../../"

// Standalone Digital Wellbeing window (split out of the Settings guide).
// Hosts DigitalWellbeingTab, which only needs rootObj.s / appPaths / currentTab.
Item {
    id: root
    visible: false
    focus: true

    property var appPaths: Caching
    property int currentTab: 0

    function s(val) {
        return Scaler.s(val);
    }

    property real introBase: 0.0

    NumberAnimation {
        id: introAnim
        target: root
        property: "introBase"
        from: 0.0
        to: 1.0
        duration: 350
        easing.type: Easing.OutQuint
    }

    SequentialAnimation {
        id: closeSequence
        NumberAnimation {
            target: root
            property: "introBase"
            to: 0.0
            duration: 200
            easing.type: Easing.InQuart
        }
        ScriptAction {
            script: Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "close"])
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: root.forceActiveFocus()
    }

    onVisibleChanged: {
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            introAnim.restart();
        } else {
            introAnim.stop();
            introBase = 0.0;
        }
    }

    Component.onCompleted: {
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            introAnim.restart();
        }
    }

    Keys.onEscapePressed: (event) => {
        closeSequence.start();
        event.accepted = true;
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

        Loader {
            id: tabLoader
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            anchors.leftMargin: 1
            anchors.rightMargin: 1
            Component.onCompleted: setSource("DigitalWellbeingTab.qml", {
                "rootObj": root,
                "tabIndex": 0
            })
            onStatusChanged: {
                if (status === Loader.Error) console.warn("Wellbeing popup failed to load DigitalWellbeingTab.qml");
            }
        }
    }
}
