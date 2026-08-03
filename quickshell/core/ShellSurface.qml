import QtQuick
import qs.core

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *                    MODAL SHELL SURFACE (ShellSurface.qml)
 * ─────────────────────────────────────────────────────────────────────────────
 * Primary background container frame for popups, dialogs, and floating utility
 * windows. Provides consistent outer borders, padding margins, and shadows.
 * ─────────────────────────────────────────────────────────────────────────────
 */
Rectangle {
    id: root

    // Forwards child components directly into internal body item
    default property alias content: body.data
    property int margin: Theme.popupMargin

    // ── Surface Geometry & Colors ────────────────────────────────────────────
    color: Theme.bg
    border.color: Theme.borderStrong
    border.width: Theme.pillBorderWidth
    radius: Theme.radius

    // Background elevation drop shadow
    PillShadow { cornerRadius: root.radius }

    // Internal padded layout container
    Item {
        id: body

        anchors.fill: parent
        anchors.margins: root.margin
    }
}
