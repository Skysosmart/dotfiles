pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../../"

Item {
    id: root

    readonly property bool isDesktop: UPower.displayDevice.ready ? !UPower.displayDevice.isLaptopBattery : (typeof SystemInfo !== "undefined" ? SystemInfo.isDesktop : true)
    readonly property int batteryPercentage: UPower.displayDevice.ready ? Math.round(UPower.displayDevice.percentage * 100) : 0
    readonly property bool isCharging: UPower.displayDevice.ready && (UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.FullyCharged)

    property bool notifiedFull: false
    property bool notifiedLow: false
    property bool notifiedCritical: false
    property real lastNotifTime: 0
    property string lastNotifType: ""

    onIsDesktopChanged: root.checkBattery()

    function sendNotification(type, summary, body, icon, urgency) {
        let now = Date.now();
        if (root.lastNotifType === type && (now - root.lastNotifTime < 60000)) {
            return;
        }
        if (now - root.lastNotifTime < 3000) {
            return;
        }
        root.lastNotifType = type;
        root.lastNotifTime = now;

        let u = urgency ? urgency : "normal";
        let ic = icon ? icon : "battery";
        let appName = I18n.t("sysnotif.battery.app_name");
        if (appName === "sysnotif.battery.app_name") appName = "System";
        Quickshell.execDetached([
            "notify-send",
            "-a", appName,
            "-u", u,
            "-i", ic,
            summary,
            body
        ]);
    }

    function checkBattery() {
        if (root.isDesktop || !UPower.displayDevice.ready || (typeof I18n !== "undefined" && !I18n.isReady)) return;

        let pct = root.batteryPercentage;
        let state = UPower.displayDevice.state;
        let charging = state === UPowerDeviceState.Charging || state === UPowerDeviceState.FullyCharged;

        if (pct < 95) {
            root.notifiedFull = false;
        }

        if (charging) {
            if (pct > 20) {
                root.notifiedLow = false;
                root.notifiedCritical = false;
            }

            if ((pct >= 100 || state === UPowerDeviceState.FullyCharged) && !root.notifiedFull) {
                let title = I18n.t("sysnotif.battery.full_title");
                let body = I18n.t("sysnotif.battery.full_body");
                if (title === "sysnotif.battery.full_title" || body === "sysnotif.battery.full_body") return;
                root.notifiedFull = true;
                root.sendNotification(
                    "full",
                    title,
                    body,
                    "battery-full-charged",
                    "normal"
                );
            }
        } else {
            if (pct <= 5) {
                if (!root.notifiedCritical) {
                    let title = I18n.t("sysnotif.battery.critical_title");
                    let body = I18n.t("sysnotif.battery.critical_body", { "pct": pct.toString() });
                    if (title === "sysnotif.battery.critical_title") return;
                    root.notifiedCritical = true;
                    root.notifiedLow = true;
                    root.sendNotification(
                        "critical",
                        title,
                        body,
                        "battery-level-0-symbolic",
                        "critical"
                    );
                }
            } else if (pct <= 20) {
                if (!root.notifiedLow) {
                    let title = I18n.t("sysnotif.battery.low_title");
                    let body = I18n.t("sysnotif.battery.low_body", { "pct": pct.toString() });
                    if (title === "sysnotif.battery.low_title") return;
                    root.notifiedLow = true;
                    root.sendNotification(
                        "low",
                        title,
                        body,
                        "battery-level-20-symbolic",
                        "critical"
                    );
                }
            } else if (pct > 25) {
                root.notifiedLow = false;
                root.notifiedCritical = false;
            }
        }
    }

    Connections {
        target: (typeof I18n !== "undefined") ? I18n : null
        function onLanguageChanged() { root.checkBattery(); }
    }

    Connections {
        target: UPower.displayDevice
        function onPercentageChanged() { root.checkBattery(); }
        function onStateChanged() { root.checkBattery(); }
        function onReadyChanged() { root.checkBattery(); }
    }
}
