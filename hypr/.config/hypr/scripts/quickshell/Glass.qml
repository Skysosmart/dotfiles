import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell

// ─────────────────────────────────────────────────────────────────────────────
//  Liquid Glass surface (iOS 26/27-style).
//
//  Drop-in replacement for a background Rectangle. The actual frosted blur is
//  produced by the compositor (Hyprland `layerrule = blur` on the qs-* layers);
//  this draws the translucent tinted fill + specular highlight + refractive
//  hairline border + soft ambient shadow on top of that blur.
//
//  Usage:  Glass { anchors.fill: parent; tint: theme.base; radius: 22 }
//          (place it where the old background Rectangle was; content sits above)
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: glass

    property color tint: "#1e1e2e"      // base tint (usually theme.base / mantle / crust)
    property real tintAlpha: 0.6         // translucency of the fill (blur shows through)

    property real radius: 22             // continuous-corner radius (rounder = more iOS)
    property real borderAlpha: 0.16      // refractive light edge
    property real highlightAlpha: 0.22   // specular top sheen
    property bool shadow: true
    property real shadowOpacity: 0.45
    property real shadowSize: 28

    // expose the inner surface for anyone who needs to anchor to it
    property alias surface: surface

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: glass.radius
        antialiasing: true
        color: Qt.rgba(glass.tint.r, glass.tint.g, glass.tint.b, glass.tintAlpha)

        // specular highlight: light catching the top edge, fading to a faint base shade
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            antialiasing: true
            gradient: Gradient {
                GradientStop { position: 0.0;  color: Qt.rgba(1, 1, 1, glass.highlightAlpha) }
                GradientStop { position: 0.32; color: Qt.rgba(1, 1, 1, 0.0) }
                GradientStop { position: 1.0;  color: Qt.rgba(0, 0, 0, 0.05) }
            }
        }

        // hairline refractive border
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            antialiasing: true
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, glass.borderAlpha)
        }

        // soft ambient shadow for lift (rendered via layer effect, contained)
        layer.enabled: glass.shadow
        layer.effect: DropShadow {
            horizontalOffset: 0
            verticalOffset: 6
            radius: glass.shadowSize
            samples: Math.min(63, glass.shadowSize * 2 + 1)
            color: Qt.rgba(0, 0, 0, glass.shadowOpacity)
            transparentBorder: true
        }
    }
}
