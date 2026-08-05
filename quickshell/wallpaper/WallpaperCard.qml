import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *                    WALLPAPER THUMBNAIL CARD (WallpaperCard.qml)
 * ─────────────────────────────────────────────────────────────────────────────
 * Virtualized GridView delegate representing an individual wallpaper item with
 * async GPU texture decoding, hover scale expansions, and active status pill.
 * ─────────────────────────────────────────────────────────────────────────────
 */
Item {
    id: root

    required property var modelData
    required property int index
    required property bool isSelected
    signal clicked()

    width: 164
    height: 112
    z: (cardMouse.containsMouse || root.isSelected) ? 2 : 1
    scale: (cardMouse.containsMouse || root.isSelected) ? 1.04 : 1.00
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

    PillShadow {
        anchors.fill: card
        cornerRadius: card.radius
        visible: cardMouse.containsMouse || root.isSelected
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.surfaceHover
        border.width: Boolean(modelData.active) || root.isSelected || cardMouse.containsMouse ? 2 : 1
        border.color: Boolean(modelData.active) || root.isSelected ? Theme.accent : (cardMouse.containsMouse ? Theme.text : Theme.border)
        Behavior on border.color { ColorAnimation { duration: 150 } }

        // Clipped container preserving border curvature around the background image
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: card.radius - 1
            color: "#161616"
            clip: true

            Image {
                id: thumbnailImage
                anchors.fill: parent
                source: modelData.thumbnail || modelData.url || ""
                asynchronous: true
                cache: true
                sourceSize: Qt.size(328, 224) // 2x density bounds to prevent texture memory bloat
                fillMode: Image.PreserveAspectCrop
                smooth: true
                opacity: status === Image.Ready ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }
        }

        // Floating active badge capsule in bottom-right corner
        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 6
            height: 20
            width: activeLabel.implicitWidth + 12
            radius: 10
            color: Theme.accent
            border.width: 1
            border.color: "#30000000"
            visible: Boolean(modelData.active)

            UiText {
                id: activeLabel
                anchors.centerIn: parent
                text: "\uf00c Active"
                font.family: Theme.iconFontFamily
                font.pixelSize: 11
                font.bold: true
                color: Theme.accentText
            }
        }

        MouseArea {
            id: cardMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }
    }
}
