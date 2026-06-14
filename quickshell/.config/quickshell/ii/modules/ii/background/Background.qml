pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.common.functions as CF
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.modules.ii.background.widgets
import qs.modules.ii.background.widgets.clock
import qs.modules.ii.background.widgets.weather

Variants {
    id: root
    model: Quickshell.screens

    PanelWindow {
        id: bgRoot

        required property var modelData

        // Hide when fullscreen
        property list<HyprlandWorkspace> workspacesForMonitor: Hyprland.workspaces.values.filter(workspace => workspace.monitor && workspace.monitor.name == monitor.name)
        property var activeWorkspaceWithFullscreen: workspacesForMonitor.filter(workspace => ((workspace.toplevels.values.filter(window => window.wayland?.fullscreen)[0] != undefined) && workspace.active))[0]
        visible: GlobalStates.screenLocked || (!(activeWorkspaceWithFullscreen != undefined)) || !Config?.options.background.hideWhenFullscreen

        // Workspaces
        property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)
        property list<var> relevantWindows: HyprlandData.windowList.filter(win => win.monitor == monitor?.id && win.workspace.id >= 0).sort((a, b) => a.workspace.id - b.workspace.id)
        property int firstWorkspaceId: relevantWindows[0]?.workspace.id || 1
        property int lastWorkspaceId: relevantWindows[relevantWindows.length - 1]?.workspace.id || 10
        property int workspaceChunkSize: Config?.options.bar.workspaces.shown ?? 10
        property int totalWorkspaces: Math.ceil(lastWorkspaceId / workspaceChunkSize) * workspaceChunkSize
        // Wallpaper
        property bool wallpaperIsVideo: Config.options.background.wallpaperPath.endsWith(".mp4") || Config.options.background.wallpaperPath.endsWith(".webm") || Config.options.background.wallpaperPath.endsWith(".mkv") || Config.options.background.wallpaperPath.endsWith(".avi") || Config.options.background.wallpaperPath.endsWith(".mov")
        property string wallpaperPath: wallpaperIsVideo ? Config.options.background.thumbnailPath : Config.options.background.wallpaperPath
        property bool wallpaperSafetyTriggered: {
            const enabled = Config.options.workSafety.enable.wallpaper;
            const sensitiveWallpaper = (CF.StringUtils.stringListContainsSubstring(wallpaperPath.toLowerCase(), Config.options.workSafety.triggerCondition.fileKeywords));
            const sensitiveNetwork = (CF.StringUtils.stringListContainsSubstring(Network.networkName.toLowerCase(), Config.options.workSafety.triggerCondition.networkNameKeywords));
            return enabled && sensitiveWallpaper && sensitiveNetwork;
        }
        readonly property real parallaxRation: Config.options.background.parallax.workspaceZoom
        property real minSuitableScale: 1 // Some reasonable init, to be updated
        property real effectiveWallpaperScale: minSuitableScale * parallaxRation
        property int wallpaperWidth: modelData.width // Some reasonable init value, to be updated
        property int wallpaperHeight: modelData.height // Some reasonable init value, to be updated
        property real scaledWallpaperWidth: wallpaperWidth * effectiveWallpaperScale
        property real scaledWallpaperHeight: wallpaperHeight * effectiveWallpaperScale
        property real parallaxTotalPixelsX: Math.max(0, scaledWallpaperWidth - screen.width)
        property real parallaxTotalPixelsY: Math.max(0, scaledWallpaperHeight - screen.height)
        readonly property bool verticalParallax: (Config.options.background.parallax.autoVertical && wallpaperHeight > wallpaperWidth) || Config.options.background.parallax.vertical

        // Wallpaper transition (directional wipe)
        readonly property bool transitionEnabled: Config.options?.background?.transition?.enable ?? true
        readonly property int transitionDuration: Config.options?.background?.transition?.duration ?? 900
        readonly property string transitionDirection: Config.options?.background?.transition?.direction ?? "right"
        readonly property real transitionSoftness: Config.options?.background?.transition?.softness ?? 0.13
        property string displayedPath: "" // The wallpaper currently shown by the base layer
        property string incomingPath: ""  // The wallpaper being wiped in
        property real wipeProgress: 0      // 0 = incoming hidden, 1 = incoming fully revealed
        property bool transitionActive: false
        property bool transitionPending: false
        property bool awaitingBaseReady: false

        Component.onCompleted: bgRoot.displayedPath = bgRoot.wallpaperPath

        function beginTransition() {
            // No transition for: disabled, first paint, video wallpapers, or no real change
            if (!bgRoot.transitionEnabled || bgRoot.displayedPath === "" || bgRoot.wallpaperIsVideo) {
                bgRoot.displayedPath = bgRoot.wallpaperPath;
                return;
            }
            if (bgRoot.wallpaperPath === bgRoot.displayedPath || bgRoot.wallpaperPath === "")
                return;
            bgRoot.incomingPath = bgRoot.wallpaperPath;
            bgRoot.transitionPending = true;
            bgRoot.wipeProgress = 0;
            // If the image is already loaded (cached), start right away
            if (incomingImage.status === Image.Ready)
                bgRoot.startWipe();
        }
        function startWipe() {
            if (!bgRoot.transitionPending)
                return;
            bgRoot.transitionPending = false;
            bgRoot.wipeProgress = 0;        // Behavior disabled while inactive -> instant reset
            bgRoot.transitionActive = true; // Enables the Behavior below
            bgRoot.wipeProgress = 1;        // Animate the wipe 0 -> 1
        }
        // Completion is detected from the value itself: a NumberAnimation nested in a
        // Behavior does NOT emit onFinished, but wipeProgress changes fire reliably.
        onWipeProgressChanged: {
            if (bgRoot.transitionActive && bgRoot.wipeProgress >= 0.999)
                bgRoot.onWipeFinished();
        }
        function onWipeFinished() {
            if (!bgRoot.transitionActive)
                return;
            // Hand off to the base layer; the bottom bridge covers any re-decode gap
            bgRoot.displayedPath = bgRoot.incomingPath;
            bgRoot.awaitingBaseReady = true;
            bgRoot.transitionActive = false; // Disable Behavior before resetting
            bgRoot.wipeProgress = 0;          // Instant reset for the next wipe
        }
        // Drives the directional wipe without referencing nested ids from JS
        Behavior on wipeProgress {
            enabled: bgRoot.transitionActive
            NumberAnimation {
                duration: bgRoot.transitionDuration
                easing.type: Easing.InOutCubic
            }
        }
        // Keeps the bridge layer up until the base layer re-decodes the new wallpaper
        Timer {
            running: bgRoot.awaitingBaseReady
            interval: 1000
            onTriggered: bgRoot.awaitingBaseReady = false
        }

        // Colors
        property bool shouldBlur: (GlobalStates.screenLocked && Config.options.lock.blur.enable)
        property color dominantColor: Appearance.colors.colPrimary // Default, to be changed
        property bool dominantColorIsDark: dominantColor.hslLightness < 0.5
        property color colText: {
            if (wallpaperSafetyTriggered)
                return CF.ColorUtils.mix(Appearance.colors.colOnLayer0, Appearance.colors.colPrimary, 0.75);
            return (GlobalStates.screenLocked && shouldBlur) ? Appearance.colors.colOnLayer0 : CF.ColorUtils.colorWithLightness(Appearance.colors.colPrimary, (dominantColorIsDark ? 0.8 : 0.12));
        }
        Behavior on colText {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        // Layer props
        screen: modelData
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: (GlobalStates.screenLocked && !scaleAnim.running) ? WlrLayer.Overlay : WlrLayer.Bottom
        // WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell:background"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: {
            if (!bgRoot.wallpaperSafetyTriggered || bgRoot.wallpaperIsVideo)
                return "transparent";
            return CF.ColorUtils.mix(Appearance.colors.colLayer0, Appearance.colors.colPrimary, 0.75);
        }
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        onWallpaperPathChanged: {
            bgRoot.updateZoomScale();
            bgRoot.beginTransition();
            // Clock position gets updated after zoom scale is updated
        }

        // Wallpaper zoom scale
        function updateZoomScale() {
            getWallpaperSizeProc.path = bgRoot.wallpaperPath;
            getWallpaperSizeProc.running = true;
        }
        Process {
            id: getWallpaperSizeProc
            property string path: bgRoot.wallpaperPath
            command: ["magick", "identify", "-format", "%w %h", path]
            stdout: StdioCollector {
                id: wallpaperSizeOutputCollector
                onStreamFinished: {
                    const output = wallpaperSizeOutputCollector.text;
                    const [width, height] = output.split(" ").map(Number);
                    const [screenWidth, screenHeight] = [bgRoot.screen.width, bgRoot.screen.height];
                    bgRoot.wallpaperWidth = width;
                    bgRoot.wallpaperHeight = height;

                    // Perfect image; scale = 1
                    // Small picture; scale > 1; will zoom in the picture
                    // Big picture; scale < 1; will zoom out the picture
                    // Choose max number so every side will fit
                    bgRoot.minSuitableScale = Math.max(screenWidth / width, screenHeight / height);
                }
            }
        }

        Item {
            anchors.fill: parent

            // Incoming wallpaper.
            // Sits at the bottom as the OpacityMask source AND as a bridge that keeps
            // the new image on screen while the base layer re-decodes it after the wipe.
            Item {
                id: incomingContainer
                anchors.fill: parent
                visible: !bgRoot.wallpaperIsVideo && (bgRoot.transitionActive || bgRoot.transitionPending || bgRoot.awaitingBaseReady)
                layer.enabled: true
                StyledImage {
                    id: incomingImage
                    x: wallpaper.x
                    y: wallpaper.y
                    width: wallpaper.width
                    height: wallpaper.height
                    cache: false
                    smooth: false
                    fillMode: Image.PreserveAspectCrop
                    source: bgRoot.incomingPath
                    onStatusChanged: {
                        if (status === Image.Ready && bgRoot.transitionPending)
                            bgRoot.startWipe();
                    }
                }
            }

            // Wallpaper
            StyledImage {
                id: wallpaper
                visible: opacity > 0 && !blurLoader.active
                // Stay opaque during the post-wipe handoff so the bridge layer never
                // reveals the empty background while the new image is re-decoding.
                opacity: (bgRoot.awaitingBaseReady || (status === Image.Ready && !bgRoot.wallpaperIsVideo)) ? 1 : 0
                cache: false
                smooth: false

                property int workspaceIndex: (bgRoot.monitor.activeWorkspace?.id ?? 1) - 1
                property real middleFraction: 0.5
                property real fraction: {
                    // 0 - start of the picture
                    // 1 - end of the picture
                    if (bgRoot.totalWorkspaces <= 1) {
                        return middleFraction;
                    }
                    return Math.max(0, Math.min(1, workspaceIndex / (bgRoot.totalWorkspaces - 1)));
                }

                property real usedFractionX: {
                    let usedFraction = middleFraction;
                    if (Config.options.background.parallax.enableWorkspace && !bgRoot.verticalParallax) {
                        usedFraction = fraction;
                    }
                    if (Config.options.background.parallax.enableSidebar) {
                        let sidebarFraction = bgRoot.parallaxRation / bgRoot.workspaceChunkSize / 2;
                        usedFraction += (sidebarFraction * GlobalStates.sidebarRightOpen - sidebarFraction * GlobalStates.sidebarLeftOpen);
                    }
                    return Math.max(0, Math.min(1, usedFraction));
                }
                property real usedFractionY: {
                    let usedFraction = middleFraction;
                    if (Config.options.background.parallax.enableWorkspace && bgRoot.verticalParallax) {
                        usedFraction = fraction;
                    }
                    return Math.max(0, Math.min(1, usedFraction));
                }

                x: {
                    if (bgRoot.screen.width > width) {
                        // Center the picture
                        return (bgRoot.screen.width - width) / 2;
                    }
                    return - bgRoot.parallaxTotalPixelsX * usedFractionX;
                }
                y: {
                    if (bgRoot.screen.height > height) {
                        // Center the picture
                        return (bgRoot.screen.height - height) / 2;
                    }
                    return - bgRoot.parallaxTotalPixelsY * usedFractionY;
                }

                source: bgRoot.wallpaperSafetyTriggered ? "" : bgRoot.displayedPath
                fillMode: Image.PreserveAspectCrop
                onStatusChanged: {
                    // Once the base layer finishes loading the new wallpaper, drop the bridge
                    if (status === Image.Ready && bgRoot.awaitingBaseReady)
                        bgRoot.awaitingBaseReady = false;
                }
                Behavior on x {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
                // Smooth fade on wallpaper change
                Behavior on opacity {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }
                width: bgRoot.scaledWallpaperWidth
                height: bgRoot.scaledWallpaperHeight
            }

            // Soft-edged gradient that sweeps across the screen (the wipe mask).
            // White = revealed, transparent = hidden; the band slides as wipeProgress goes 0 -> 1.
            LinearGradient {
                id: wipeGradient
                anchors.fill: parent
                visible: false
                start: {
                    switch (bgRoot.transitionDirection) {
                    case "left": return Qt.point(width, 0);
                    case "up": return Qt.point(0, height);
                    case "down": return Qt.point(0, 0);
                    default: return Qt.point(0, 0); // "right"
                    }
                }
                end: {
                    switch (bgRoot.transitionDirection) {
                    case "left": return Qt.point(0, 0);
                    case "up": return Qt.point(0, 0);
                    case "down": return Qt.point(0, height);
                    default: return Qt.point(width, 0); // "right"
                    }
                }
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "white" }
                    GradientStop {
                        position: Math.max(0, bgRoot.wipeProgress * (1 + bgRoot.transitionSoftness) - bgRoot.transitionSoftness)
                        color: "white"
                    }
                    GradientStop {
                        position: Math.min(1, bgRoot.wipeProgress * (1 + bgRoot.transitionSoftness))
                        color: "transparent"
                    }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // Composited reveal of the incoming wallpaper over the current one
            OpacityMask {
                id: wipeReveal
                anchors.fill: parent
                visible: bgRoot.transitionActive
                source: incomingContainer
                maskSource: wipeGradient
            }

            Loader {
                id: blurLoader
                active: Config.options.lock.blur.enable && (GlobalStates.screenLocked || scaleAnim.running)
                anchors.fill: wallpaper
                scale: GlobalStates.screenLocked ? Config.options.lock.blur.extraZoom : 1
                Behavior on scale {
                    NumberAnimation {
                        id: scaleAnim
                        duration: 400
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
                    }
                }
                sourceComponent: GaussianBlur {
                    source: wallpaper
                    radius: GlobalStates.screenLocked ? Config.options.lock.blur.radius : 0
                    samples: radius * 2 + 1

                    Rectangle {
                        opacity: GlobalStates.screenLocked ? 1 : 0
                        anchors.fill: parent
                        color: CF.ColorUtils.transparentize(Appearance.colors.colLayer0, 0.7)
                    }
                }
            }

            WidgetCanvas {
                id: widgetCanvas
                width: parent.width
                height: parent.height
                readonly property real parallaxFactor: {
                    var f = Config.options.background.parallax.widgetsFactor;
                    return f / bgRoot.parallaxRation;
                }
                readonly property real baseWallpaperOffsetX: (bgRoot.screen.width - wallpaper.width) / 2
                readonly property real baseWallpaperOffsetY: (bgRoot.screen.height - wallpaper.height) / 2
                readonly property real wallpaperTotalOffsetX: wallpaper.x - baseWallpaperOffsetX
                readonly property real wallpaperTotalOffsetY: wallpaper.y - baseWallpaperOffsetY
                readonly property bool locked: GlobalStates.screenLocked
                x: wallpaperTotalOffsetX * parallaxFactor * !locked
                y: wallpaperTotalOffsetY * parallaxFactor * !locked

                transitions: Transition {
                    PropertyAnimation {
                        properties: "width,height"
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Appearance.animation.elementMove.type
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                    }
                    AnchorAnimation {
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Appearance.animation.elementMove.type
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.weather.enable
                    sourceComponent: WeatherWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: Config.options.background.widgets.clock.enable
                    sourceComponent: ClockWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                        wallpaperSafetyTriggered: bgRoot.wallpaperSafetyTriggered
                    }
                }
            }
        }
    }
}
