import QtQuick
import QtQuick.Layouts
import QtQuick.Controls 2.15 as QQC2
import Quickshell
import qs.core

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *                    WALLPAPER SWITCHER GALLERY VIEW (WallpaperView.qml)
 * ─────────────────────────────────────────────────────────────────────────────
 * Interactive dashboard menu combining background scaling mode controls, dual-mode
 * border color studio (Auto detection vs Custom Hex Code), and virtualized grid.
 * ─────────────────────────────────────────────────────────────────────────────
 */
ColumnLayout {
    id: root

    required property var wallpaperModel
    property int selectedGridIndex: 0
    spacing: Theme.popupSpacing

    // ── Custom Color Studio Hex Variable ─────────────────────────────────────
    property string customHex: "#242424"

    function syncCustomFromHex(hexStr) {
        if (!hexStr || !hexStr.startsWith("#") || hexStr.length !== 7)
            return;
        customHex = hexStr.toLowerCase();
    }

    Connections {
        target: root.wallpaperModel
        function onCurrentColorChanged() {
            if (root.wallpaperModel.currentColor.toLowerCase() !== "auto") {
                root.syncCustomFromHex(root.wallpaperModel.currentColor);
            }
        }
    }

    // ── Scaling Modes Defined by feh Flags (with Nerd Font Icons) ───────────
    readonly property var scalingModes: [
        {
            id: "fill",
            label: "\uf065  Zoom"
        },
        {
            id: "max",
            label: "\uf0b2  Fit"
        },
        {
            id: "center",
            label: "\uf192  Centered"
        },
        {
            id: "scale",
            label: "\uf07e  Stretch"
        },
        {
            id: "tile",
            label: "\uf009  Tiled"
        }
    ]

    function activeWallpaperFilename() {
        const path = root.wallpaperModel.currentWallpaperPath || "";
        const parts = path.split("/");
        return parts.length > 0 ? parts[parts.length - 1] : "Select Background";
    }

    // =========================================================================
    // 1. TOP STYLING & CONFIGURATION CONTROLS DRAWER
    // =========================================================================
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: configColumn.implicitHeight + 24
        radius: Theme.radius
        color: Theme.buttonBackground
        border.color: Theme.border
        border.width: 1
        clip: true

        ColumnLayout {
            id: configColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            // ── Header & Action Bar ──────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                UiText {
                    text: "\uf03e  " + root.activeWallpaperFilename()
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.titleFontSize
                    font.bold: true
                    color: Theme.textStrong
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Rectangle {
                    implicitWidth: countText.implicitWidth + 16
                    implicitHeight: 22
                    radius: 11
                    color: Theme.accent

                    UiText {
                        id: countText
                        anchors.centerIn: parent
                        text: "\uf009  " + (root.wallpaperModel.wallpaperCount || 0) + " WALLPAPERS"
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.tinyFontSize
                        font.bold: true
                        color: Theme.accentText
                    }
                }

                ShellButton {
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: Theme.buttonHeight
                    label: "\uf074  Randomize"
                    onActivated: root.wallpaperModel.randomize()
                }

                ShellButton {
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: Theme.buttonHeight
                    label: root.wallpaperModel.busy ? "..." : "\uf021"
                    enabled: !root.wallpaperModel.busy
                    onActivated: root.wallpaperModel.refresh()
                }
            }

            // ── Row 2: Scaling Style Selection Strip ─────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                UiText {
                    text: "SCALING STYLE & GEOMETRY"
                    font.pixelSize: Theme.tinyFontSize
                    font.bold: true
                    color: Theme.textMuted
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: root.scalingModes

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: Theme.radius - 2
                            color: root.wallpaperModel.currentMode === modelData.id ? Theme.buttonSelectedBackground : (modeMouse.containsMouse ? Theme.buttonHoverBackground : Theme.surfaceHover)
                            border.width: 1
                            border.color: root.wallpaperModel.currentMode === modelData.id ? Theme.accent : Theme.border

                            UiText {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.family: Theme.iconFontFamily
                                font.pixelSize: 11
                                font.bold: root.wallpaperModel.currentMode === modelData.id
                                color: root.wallpaperModel.currentMode === modelData.id ? Theme.accentText : Theme.textStrong
                            }

                            MouseArea {
                                id: modeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.wallpaperModel.updateMode(modelData.id)
                            }
                        }
                    }
                }
            }

            // ── Row 3: Border Padding Fill Color Mode Selector ───────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                UiText {
                    text: "BORDER PADDING FILL COLOR (FOR FIT & CENTERED MODES)"
                    font.pixelSize: Theme.tinyFontSize
                    font.bold: true
                    color: Theme.textMuted
                }

                // Mode Choice Strip (Auto vs Custom Hex Code)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Auto Option
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: Theme.radius - 2
                        color: root.wallpaperModel.currentColor.toLowerCase() === "auto" ? Theme.buttonSelectedBackground : (autoMouse.containsMouse ? Theme.buttonHoverBackground : Theme.surfaceHover)
                        border.width: root.wallpaperModel.currentColor.toLowerCase() === "auto" ? 2 : 1
                        border.color: root.wallpaperModel.currentColor.toLowerCase() === "auto" ? Theme.accent : Theme.border

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            UiText {
                                text: "\uf0d0  Auto"
                                font.family: Theme.iconFontFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: root.wallpaperModel.currentColor.toLowerCase() === "auto" ? Theme.accentText : Theme.textStrong
                            }
                            Rectangle {
                                width: 16
                                height: 16
                                radius: 8
                                color: root.wallpaperModel.computedColor || "#000000"
                                border.color: Theme.borderLight
                                border.width: 1
                                visible: root.wallpaperModel.currentColor.toLowerCase() === "auto"
                            }
                        }

                        MouseArea {
                            id: autoMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.wallpaperModel.updateColor("auto")
                        }
                    }

                    // Custom Color Picker Option
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: Theme.radius - 2
                        color: root.wallpaperModel.currentColor.toLowerCase() !== "auto" ? Theme.buttonSelectedBackground : (pickerMouse.containsMouse ? Theme.buttonHoverBackground : Theme.surfaceHover)
                        border.width: root.wallpaperModel.currentColor.toLowerCase() !== "auto" ? 2 : 1
                        border.color: root.wallpaperModel.currentColor.toLowerCase() !== "auto" ? Theme.accent : Theme.border

                        UiText {
                            anchors.centerIn: parent
                            text: "\uf043  Hex Code"
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: root.wallpaperModel.currentColor.toLowerCase() !== "auto" ? Theme.accentText : Theme.textStrong
                        }

                        MouseArea {
                            id: pickerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.wallpaperModel.currentColor.toLowerCase() === "auto") {
                                    root.wallpaperModel.updateColor(root.customHex);
                                }
                            }
                        }
                    }
                }

                // Inline Custom Color Studio Drawer (Expanded when Mode != Auto)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    radius: Theme.radius - 2
                    color: Theme.surfaceHover
                    border.color: Theme.border
                    border.width: 1
                    visible: root.wallpaperModel.currentColor.toLowerCase() !== "auto"
                    clip: true

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 16

                        Rectangle {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 28
                            radius: 6
                            color: root.customHex
                            border.color: Theme.borderLight
                            border.width: 1
                        }

                        UiText {
                            text: "\uf043  Hex Color Code:"
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 12
                            font.bold: true
                            color: Theme.textStrong
                        }

                        Rectangle {
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 28
                            radius: 6
                            color: Theme.surface
                            border.color: hexInput.activeFocus ? Theme.accent : Theme.border
                            border.width: hexInput.activeFocus ? 2 : 1

                            TextInput {
                                id: hexInput
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                text: root.customHex
                                color: Theme.textStrong
                                selectionColor: Theme.accent
                                selectedTextColor: Theme.accentText
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                clip: true
                                onTextEdited: {
                                    if (text.startsWith("#") && text.length === 7) {
                                        root.customHex = text.toLowerCase();
                                        root.wallpaperModel.updateColor(text);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // 2. VIRTUALIZED 3-COLUMN GALLERY GRID
    // =========================================================================
    GridView {
        id: gridView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        cellWidth: Math.floor(width / 3)
        cellHeight: 122
        boundsBehavior: Flickable.StopAtBounds
        model: root.wallpaperModel.wallpapers

        QQC2.ScrollBar.vertical: QQC2.ScrollBar {
            background: Rectangle {
                implicitWidth: 7
                color: Theme.buttonFocusBackground
                opacity: gridView.contentHeight > gridView.height ? 0.55 : 0
            }
            contentItem: Rectangle {
                implicitWidth: 7
                radius: 3
                color: Theme.textMuted
            }
        }

        delegate: Item {
            required property var modelData
            required property int index

            width: gridView.cellWidth
            height: gridView.cellHeight

            WallpaperCard {
                anchors.centerIn: parent
                width: parent.width - 10
                height: parent.height - 10
                modelData: parent.modelData
                index: parent.index
                isSelected: parent.index === root.selectedGridIndex

                onClicked: {
                    root.selectedGridIndex = parent.index;
                    root.wallpaperModel.setWallpaper(parent.modelData.path);
                }
            }
        }

        // Keyboard arrow navigation handlers
        Keys.onUpPressed: {
            if (root.selectedGridIndex >= 3) {
                root.selectedGridIndex -= 3;
                gridView.positionViewAtIndex(root.selectedGridIndex, GridView.Contain);
            }
        }
        Keys.onDownPressed: {
            if (root.selectedGridIndex + 3 < gridView.count) {
                root.selectedGridIndex += 3;
                gridView.positionViewAtIndex(root.selectedGridIndex, GridView.Contain);
            }
        }
        Keys.onLeftPressed: {
            if (root.selectedGridIndex > 0) {
                root.selectedGridIndex -= 1;
                gridView.positionViewAtIndex(root.selectedGridIndex, GridView.Contain);
            }
        }
        Keys.onRightPressed: {
            if (root.selectedGridIndex + 1 < gridView.count) {
                root.selectedGridIndex += 1;
                gridView.positionViewAtIndex(root.selectedGridIndex, GridView.Contain);
            }
        }
        Keys.onReturnPressed: {
            if (root.selectedGridIndex >= 0 && root.selectedGridIndex < root.wallpaperModel.wallpapers.length) {
                const item = root.wallpaperModel.wallpapers[root.selectedGridIndex];
                root.wallpaperModel.setWallpaper(item.path);
            }
        }
    }

    Component.onCompleted: {
        if (root.wallpaperModel && root.wallpaperModel.currentColor && root.wallpaperModel.currentColor.toLowerCase() !== "auto") {
            root.syncCustomFromHex(root.wallpaperModel.currentColor);
        }
        gridView.forceActiveFocus();
    }
}
