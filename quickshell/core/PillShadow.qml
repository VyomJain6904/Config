import QtQuick
import qs.core

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *                    DROP SHADOW PRIMITIVE (PillShadow.qml)
 * ─────────────────────────────────────────────────────────────────────────────
 * Renders a subtle semi-transparent dark offset behind active pills, cards,
 * and dialog surfaces to generate visual depth and elevation.
 * ─────────────────────────────────────────────────────────────────────────────
 */
Rectangle {
    property real cornerRadius: Theme.pillRadius

    // Offset coordinates directly beneath parent element
    x: 1
    y: 2
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    radius: cornerRadius
    color: Theme.shadow
    opacity: 0.45
    z: -1   // Position behind parent container layer
}
