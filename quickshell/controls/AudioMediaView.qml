import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.core

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *                    AUDIO & MEDIA VIEW (AudioMediaView.qml)
 * ─────────────────────────────────────────────────────────────────────────────
 * Comprehensive control interface for Audio volume slider, input/output device
 * selection lists, microphone gain level adjustments, and Media playback
 * controls with Album art thumbnail display.
 * ─────────────────────────────────────────────────────────────────────────────
 */
ColumnLayout {
    id: root

    // ── External Models & State References ───────────────────────────────────
    required property var controlsModel
    property string activeTab: "audio"
    property int selectedIndex: 0
    property int volumeControlHeight: 32
    property int rowSpacing: 10
    property int volumePercentWidth: 54
    property int outputDeviceListMaxHeight: 140
    property int deviceListReservedHeight: 40
    property int outputDeviceRowHeight: 32
    property int inputDeviceListMaxHeight: 140
    property int mediaThumbnailHeight: 120

    readonly property bool volumeInputActiveFocus: volumePercentInput.activeFocus

    signal requestParentFocus()

    function focusVolumeInput() {
        Qt.callLater(() => volumePercentInput.forceActiveFocus());
    }

    function setVolumePendingFromX(x) {
        volumeSlider.pendingPercent = volumeSlider.percentFromX(x);
        root.controlsModel.volumeSet(volumeSlider.pendingPercent);
    }

    function setMicFromX(x, width) {
        const value = Math.max(0, Math.min(100, Math.round((x / Math.max(1, width)) * 100)));
        root.controlsModel.micSet(value);
    }

    function percentFromText(text, fallbackValue) {
        const match = text.match(/[0-9]+/);
        if (match === null) {
            return fallbackValue;
        }
        return Math.max(0, Math.min(100, parseInt(match[0], 10)));
    }

    Layout.fillWidth: true
    spacing: Theme.compactSpacing

    // =========================================================================
    // 1. SECTION TITLE HEADER
    // =========================================================================

    RowLayout {
        Layout.fillWidth: true
        spacing: 14
        Layout.bottomMargin: 8

        Text {
            text: "\uf028"
            color: Theme.accent
            font.family: Theme.iconFontFamily
            font.pixelSize: 28
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                text: "Audio & Media"
                color: Theme.textStrong
                font.family: Theme.fontFamily
                font.pixelSize: Theme.titleFontSize
                font.bold: true
            }
        }
    }

    // =========================================================================
    // 2. MASTER VOLUME CONTROLS & SLIDER
    // =========================================================================

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: root.volumeControlHeight

        SectionLabel {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            label: root.controlsModel.volumeMuted ? "\uf026  Volume" : "\uf028  Volume"
        }

        Text {
            anchors.centerIn: parent
            width: Math.max(80, parent.width - 240)
            height: parent.height
            text: root.controlsModel.volumeMuted ? "\uf026  Muted" : ""
            color: Theme.danger
            font.family: Theme.fontFamily
            font.pixelSize: Theme.panelFontSize
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        ShellButton {
            compact: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: implicitWidth
            height: Theme.buttonHeight
            label: root.controlsModel.volumeMuted ? "\uf028  Unmute" : "\uf026  Mute"
            enabled: !root.controlsModel.busy
            selected: root.activeTab === "audio" && root.selectedIndex === 1
            onActivated: root.controlsModel.volumeToggleMute()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: root.rowSpacing

        Item {
            id: volumeSlider

            property int pendingPercent: root.controlsModel.volumePercent
            property int displayPercent: volumeMouse.pressed ? pendingPercent : root.controlsModel.volumePercent

            Layout.fillWidth: true
            Layout.preferredHeight: root.volumeControlHeight

            function percentFromX(x) {
                return Math.max(0, Math.min(100, Math.round((x / Math.max(1, width)) * 100)));
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 8
                color: Theme.surface
                radius: Theme.radius

                Rectangle {
                    width: Math.round((volumeSlider.displayPercent / 100) * parent.width)
                    height: parent.height
                    color: root.controlsModel.volumeMuted ? Theme.textMuted : Theme.accent
                    radius: parent.radius
                }
            }

            Rectangle {
                width: 20
                height: 20
                x: Math.max(0, Math.min(parent.width - width, Math.round((volumeSlider.displayPercent / 100) * parent.width) - width / 2))
                y: parent.height / 2 - height / 2
                color: volumeMouse.enabled ? Theme.text : Theme.textMuted
                border.color: Theme.border
                border.width: 1
                radius: height / 2
            }

            MouseArea {
                id: volumeMouse

                anchors.fill: parent
                enabled: !root.controlsModel.busy
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: function (mouse) {
                    root.setVolumePendingFromX(mouse.x);
                }
                onPositionChanged: function (mouse) {
                    if (pressed) {
                        root.setVolumePendingFromX(mouse.x);
                    }
                }
                onReleased: function (mouse) {
                    root.setVolumePendingFromX(mouse.x);
                }
            }
        }

        TextInput {
            id: volumePercentInput
            Layout.preferredWidth: root.volumePercentWidth
            text: root.controlsModel.volumePercent + "%"
            color: Theme.text
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.panelFontSize
            font.bold: true
            horizontalAlignment: TextInput.AlignRight
            verticalAlignment: TextInput.AlignVCenter
            selectByMouse: true
            clip: true
            onActiveFocusChanged: {
                if (activeFocus) {
                    selectAll();
                } else {
                    text = root.controlsModel.volumePercent + "%";
                }
            }
            onAccepted: {
                const value = root.percentFromText(text, root.controlsModel.volumePercent);
                root.controlsModel.volumeSet(value);
                text = value + "%";
                root.requestParentFocus();
            }

            Connections {
                target: root.controlsModel
                function onVolumePercentChanged() {
                    if (!volumePercentInput.activeFocus) {
                        volumePercentInput.text = root.controlsModel.volumePercent + "%";
                    }
                }
            }
        }
    }

    // =========================================================================
    // 3. AUDIO OUTPUT DEVICES
    // =========================================================================

    SectionLabel {
        label: "\uf025  Output Devices"
    }

    Text {
        Layout.fillWidth: true
        visible: root.controlsModel.outputDevices.length === 0
        text: "OUTPUT unavailable"
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.panelFontSize
        font.bold: true
        elide: Text.ElideRight
    }

    ListView {
        id: outputDeviceList

        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(root.outputDeviceListMaxHeight, Math.max(root.deviceListReservedHeight, contentHeight))
        clip: true
        spacing: Theme.compactSpacing
        visible: root.controlsModel.outputDevices.length > 0
        model: root.controlsModel.outputDevices
        ScrollBar.vertical: ScrollBar {
            active: outputDeviceList.contentHeight > outputDeviceList.height
            policy: ScrollBar.AsNeeded
            width: 4
        }

        delegate: Rectangle {
            id: outputDeviceRow

            required property int index
            required property var modelData
            readonly property bool selected: root.activeTab === "audio" && root.selectedIndex === index + 2

            width: ListView.view.width
            height: root.outputDeviceRowHeight
            radius: Theme.radius
            color: outputDeviceRow.modelData.isDefault ? Theme.accent : (selected ? Theme.surfaceActive : (outputMouse.containsMouse && !root.controlsModel.busy ? Theme.surfaceHover : Theme.surface))
            border.color: selected || outputDeviceRow.modelData.isDefault ? Theme.accent : Theme.border
            border.width: 1
            opacity: root.controlsModel.busy && !outputDeviceRow.modelData.isDefault ? 0.5 : 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: root.rowSpacing

                Text {
                    Layout.fillWidth: true
                    text: outputDeviceRow.modelData.description
                    color: outputDeviceRow.modelData.isDefault ? Theme.accentText : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.panelFontSize
                    font.bold: outputDeviceRow.modelData.isDefault
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    Layout.preferredWidth: 58
                    text: outputDeviceRow.modelData.isDefault ? "Default" : "Set"
                    color: outputDeviceRow.modelData.isDefault ? Theme.accentText : Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallFontSize
                    font.bold: true
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: outputMouse

                anchors.fill: parent
                enabled: !root.controlsModel.busy && !outputDeviceRow.modelData.isDefault
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.controlsModel.outputSetDefault(outputDeviceRow.modelData.name)
            }
        }
    }

    // =========================================================================
    // 4. MICROPHONE GAIN & INPUT DEVICES
    // =========================================================================

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: root.volumeControlHeight

        SectionLabel {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            label: (root.controlsModel.micText.indexOf("\uf131") !== -1 || root.controlsModel.micText === "MIC muted") ? "\uf131  Microphone" : "\uf130  Microphone"
        }

        Text {
            anchors.centerIn: parent
            width: Math.max(80, parent.width - 240)
            height: parent.height
            text: root.controlsModel.micText
            color: (root.controlsModel.micText === "MIC muted" || root.controlsModel.micText.indexOf("\uf131") !== -1) ? Theme.danger : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.panelFontSize
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        ShellButton {
            compact: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: implicitWidth
            height: Theme.buttonHeight
            label: (root.controlsModel.micText === "MIC muted" || root.controlsModel.micText.indexOf("\uf131") !== -1) ? "\uf130  Unmute Mic" : "\uf131  Mute Mic"
            enabled: !root.controlsModel.busy
            selected: root.activeTab === "audio" && root.selectedIndex === 2 + root.controlsModel.outputDevices.length
            onActivated: root.controlsModel.micToggleMute()
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 28

        Item {
            anchors.left: parent.left
            anchors.right: micPercentLabel.left
            anchors.rightMargin: root.rowSpacing
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 8
                color: Theme.surface
                radius: Theme.radius

                Rectangle {
                    width: Math.round((root.controlsModel.micPercent / 100) * parent.width)
                    height: parent.height
                    color: (root.controlsModel.micText === "MIC muted" || root.controlsModel.micText.indexOf("\uf131") !== -1) ? Theme.textMuted : Theme.accent
                    radius: parent.radius
                }
            }

            Rectangle {
                width: 20
                height: 20
                x: Math.max(0, Math.min(parent.width - width, Math.round((root.controlsModel.micPercent / 100) * parent.width) - width / 2))
                y: parent.height / 2 - height / 2
                color: micMouse.enabled ? Theme.text : Theme.textMuted
                border.color: Theme.border
                border.width: 1
                radius: height / 2
            }

            MouseArea {
                id: micMouse
                anchors.fill: parent
                enabled: !root.controlsModel.busy
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: function (mouse) {
                    root.setMicFromX(mouse.x, width);
                }
                onPositionChanged: function (mouse) {
                    if (pressed) {
                        root.setMicFromX(mouse.x, width);
                    }
                }
            }
        }

        Text {
            id: micPercentLabel
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: root.volumePercentWidth
            text: root.controlsModel.micPercent + "%"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallFontSize
            font.bold: true
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
        }
    }

    Text {
        Layout.fillWidth: true
        visible: root.controlsModel.inputDevices.length === 0
        text: "INPUT unavailable"
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.panelFontSize
        font.bold: true
        elide: Text.ElideRight
    }

    ListView {
        id: inputDeviceList

        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(root.inputDeviceListMaxHeight, Math.max(root.deviceListReservedHeight, contentHeight))
        clip: true
        spacing: Theme.compactSpacing
        visible: root.controlsModel.inputDevices.length > 0
        model: root.controlsModel.inputDevices
        ScrollBar.vertical: ScrollBar {
            active: inputDeviceList.contentHeight > inputDeviceList.height
            policy: ScrollBar.AsNeeded
            width: 4
        }

        delegate: Rectangle {
            id: inputDeviceRow

            required property int index
            required property var modelData
            readonly property int inputSelectionIndex: index + 3 + root.controlsModel.outputDevices.length
            readonly property bool selected: root.activeTab === "audio" && root.selectedIndex === inputSelectionIndex

            width: ListView.view.width
            height: root.outputDeviceRowHeight
            radius: Theme.radius
            color: inputDeviceRow.modelData.isDefault ? Theme.accent : (selected ? Theme.surfaceActive : (inputMouse.containsMouse && !root.controlsModel.busy ? Theme.surfaceHover : Theme.surface))
            border.color: selected || inputDeviceRow.modelData.isDefault ? Theme.accent : Theme.border
            border.width: 1
            opacity: root.controlsModel.busy && !inputDeviceRow.modelData.isDefault ? 0.5 : 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: root.rowSpacing

                Text {
                    Layout.fillWidth: true
                    text: inputDeviceRow.modelData.description
                    color: inputDeviceRow.modelData.isDefault ? Theme.accentText : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.panelFontSize
                    font.bold: inputDeviceRow.modelData.isDefault
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    Layout.preferredWidth: 58
                    text: inputDeviceRow.modelData.isDefault ? "Default" : "Set"
                    color: inputDeviceRow.modelData.isDefault ? Theme.accentText : Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallFontSize
                    font.bold: true
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: inputMouse

                anchors.fill: parent
                enabled: !root.controlsModel.busy && !inputDeviceRow.modelData.isDefault
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.controlsModel.inputSetDefault(inputDeviceRow.modelData.name)
            }
        }
    }

    // =========================================================================
    // 5. MEDIA PLAYER & SCRUBBER
    // =========================================================================

    SectionLabel {
        label: "\uf03d  Media Player"
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: root.mediaThumbnailHeight + 88
        color: Theme.surface
        radius: Theme.radius
        border.color: Theme.border
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            spacing: Theme.compactSpacing

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.mediaThumbnailHeight
                clip: true
                color: Theme.barBackground
                radius: Theme.radius
                border.color: Theme.border
                border.width: 1

                Image {
                    anchors.fill: parent
                    source: mediaThumbnail.source
                    fillMode: Image.PreserveAspectCrop
                    visible: mediaThumbnail.visible
                    opacity: 0.4
                    smooth: true
                    mipmap: true
                }

                Image {
                    id: mediaThumbnail
                    anchors.fill: parent
                    source: root.controlsModel.mediaArtUrl
                    asynchronous: true
                    cache: true
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    mipmap: true
                    visible: source.toString().length > 0 && (status === Image.Ready || status === Image.Loading)
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.max(100, parent.width - 32)
                    visible: !mediaThumbnail.visible
                    spacing: Theme.compactSpacing

                    Image {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        source: "file:///usr/share/icons/MacTahoe/apps/scalable/multimedia.svg"
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: root.controlsModel.mediaText.length > 0 && root.controlsModel.mediaText !== "MEDIA none" ? root.controlsModel.mediaText : "No Media Playing"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.smallFontSize
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                    }
                }
            }

            // ── Media progress scrubber + timestamps ─────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                // Formats microseconds into M:SS or H:MM:SS
                function formatTime(us) {
                    const totalSec = Math.max(0, Math.floor(us / 1000000));
                    const h = Math.floor(totalSec / 3600);
                    const m = Math.floor((totalSec % 3600) / 60);
                    const s = totalSec % 60;
                    const mm = m.toString().padStart(h > 0 ? 2 : 1, "0");
                    const ss = s.toString().padStart(2, "0");
                    return h > 0 ? h + ":" + mm + ":" + ss : mm + ":" + ss;
                }

                Item {
                    id: mediaProgressBar

                    Layout.fillWidth: true
                    Layout.preferredHeight: 16

                    function progressFromX(x) {
                        return Math.max(0, Math.min(1, x / Math.max(1, width)));
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 6
                        color: Theme.barBackground
                        radius: height / 2
                        border.color: Theme.border
                        border.width: 1

                        Rectangle {
                            width: Math.round(root.controlsModel.mediaProgress * parent.width)
                            height: parent.height
                            color: root.controlsModel.mediaPlayer.length > 0 ? Theme.accent : Theme.textMuted
                            radius: parent.radius

                            // Scrubber handle — visible thumb dot at the progress head
                            Rectangle {
                                visible: root.controlsModel.mediaLengthUs > 0
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.rightMargin: -width / 2
                                width: 10
                                height: 10
                                radius: 5
                                color: Theme.accent
                                border.color: Theme.barBackground
                                border.width: 1.5
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.topMargin: -6
                        anchors.bottomMargin: -6
                        enabled: root.controlsModel.mediaLengthUs > 0
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onPressed: function (mouse) {
                            root.controlsModel.mediaPositionUs = root.controlsModel.mediaLengthUs * mediaProgressBar.progressFromX(mouse.x);
                        }
                        onPositionChanged: function (mouse) {
                            if (pressed) {
                                root.controlsModel.mediaPositionUs = root.controlsModel.mediaLengthUs * mediaProgressBar.progressFromX(mouse.x);
                            }
                        }
                        onReleased: function (mouse) {
                            root.controlsModel.mediaSeek(mediaProgressBar.progressFromX(mouse.x));
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.controlsModel.mediaLengthUs > 0

                    Text {
                        text: parent.parent.formatTime(root.controlsModel.mediaPositionUs)
                        color: root.controlsModel.mediaPlayer.length > 0 ? Theme.accent : Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.smallFontSize
                        font.bold: true
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: parent.parent.formatTime(root.controlsModel.mediaLengthUs)
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.smallFontSize
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.compactSpacing

                ControlsActionButton {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 26
                    label: "−5s"
                    labelPixelSize: 11
                    enabled: root.controlsModel.mediaText.length > 0 && root.controlsModel.mediaText !== "No Media Playing" && root.controlsModel.mediaText !== "MEDIA none"
                    onActivated: root.controlsModel.mediaSeekBy(-5)
                }

                ControlsActionButton {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 26
                    label: ""
                    labelFontFamily: Theme.iconFontFamily
                    labelPixelSize: 13
                    enabled: root.controlsModel.mediaText.length > 0 && root.controlsModel.mediaText !== "No Media Playing" && root.controlsModel.mediaText !== "MEDIA none"
                    selected: root.activeTab === "audio" && root.selectedIndex === 3 + root.controlsModel.outputDevices.length + root.controlsModel.inputDevices.length
                    onActivated: root.controlsModel.mediaPrevious()
                }

                ControlsActionButton {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 26
                    label: root.controlsModel.mediaState === "Playing" ? "" : ""
                    labelFontFamily: Theme.iconFontFamily
                    labelPixelSize: 13
                    enabled: root.controlsModel.mediaText.length > 0 && root.controlsModel.mediaText !== "No Media Playing" && root.controlsModel.mediaText !== "MEDIA none"
                    selected: root.activeTab === "audio" && root.selectedIndex === 4 + root.controlsModel.outputDevices.length + root.controlsModel.inputDevices.length
                    onActivated: root.controlsModel.mediaPlayPause()
                }

                ControlsActionButton {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 26
                    label: ""
                    labelFontFamily: Theme.iconFontFamily
                    labelPixelSize: 13
                    enabled: root.controlsModel.mediaText.length > 0 && root.controlsModel.mediaText !== "No Media Playing" && root.controlsModel.mediaText !== "MEDIA none"
                    selected: root.activeTab === "audio" && root.selectedIndex === 5 + root.controlsModel.outputDevices.length + root.controlsModel.inputDevices.length
                    onActivated: root.controlsModel.mediaNext()
                }

                ControlsActionButton {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 26
                    label: "+5s"
                    labelPixelSize: 11
                    enabled: root.controlsModel.mediaText.length > 0 && root.controlsModel.mediaText !== "No Media Playing" && root.controlsModel.mediaText !== "MEDIA none"
                    onActivated: root.controlsModel.mediaSeekBy(5)
                }
            }
        }
    }

    Item {
        Layout.fillHeight: true
    }
}
