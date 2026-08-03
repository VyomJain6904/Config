import QtQuick
import qs.core

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *                    PANEL PILL CONTAINER (PanelPill.qml)
 * ─────────────────────────────────────────────────────────────────────────────
 * Reusable container box for status items in the bar (Wi-Fi, Audio, Battery).
 * Supports animated background transitions and automatic drop shadows.
 * ─────────────────────────────────────────────────────────────────────────────
 */
Rectangle {
    id: root

    // ── Interaction States ───────────────────────────────────────────────────
    property bool active: false     // True when associated menu dialog is open
    property bool hovered: false    // True when cursor is hovering over capsule

    // ── Visual Geometry & Styling ────────────────────────────────────────────
    implicitHeight: Theme.pillHeight
    color: active ? Theme.surfaceActive : (hovered ? Theme.surfaceHover : "transparent")
    border.color: active ? Theme.accent : "transparent"
    border.width: Theme.pillBorderWidth
    radius: Theme.pillRadius

    // ── Smooth Color Transitions ─────────────────────────────────────────────
    Behavior on color {
        ColorAnimation { duration: Theme.animationNormal }
    }

    Behavior on border.color {
        ColorAnimation { duration: Theme.animationNormal }
    }

    // ── Drop Shadow Accent ───────────────────────────────────────────────────
    PillShadow {
        cornerRadius: root.radius
        visible: root.active || root.hovered
    }
}
