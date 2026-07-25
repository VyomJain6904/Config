pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core
import qs.network
import QtQuick.Controls

FloatingWindow {
    id: root

    required property var networkModel
    required property var bluetoothModel
    required property var controlsModel
    required property var vpnModel

    property string activeTab: "wifi"

    readonly property int popupWidth: 460
    readonly property int popupHeight: 580
    readonly property int edgeMargin: Theme.rowSpacing
    readonly property int contentSpacing: Theme.popupSpacing
    readonly property int rowSpacing: Theme.rowSpacing
    readonly property int actionButtonHeight: Theme.compactButtonHeight
    readonly property int volumeControlHeight: 46
    readonly property int volumePercentWidth: 42
    readonly property int muteButtonWidth: 84
    readonly property int outputDeviceRowHeight: 34

    visible: networkModel.visible || bluetoothModel.visible || controlsModel.visible || vpnModel.visible
    implicitWidth: popupWidth
    implicitHeight: popupHeight
    title: "Quickshell Utility"
    color: Theme.transparent

    Connections {
        target: root.networkModel
        function onVisibleChanged() {
            if (root.networkModel.visible) {
                root.activeTab = "wifi";
                root.bluetoothModel.close();
                root.controlsModel.close();
                root.vpnModel.close();
            }
        }
    }

    Connections {
        target: root.bluetoothModel
        function onVisibleChanged() {
            if (root.bluetoothModel.visible) {
                root.activeTab = "bluetooth";
                root.networkModel.close();
                root.controlsModel.close();
                root.vpnModel.close();
            }
        }
    }

    Connections {
        target: root.controlsModel
        function onVisibleChanged() {
            if (root.controlsModel.visible) {
                root.activeTab = root.controlsModel.requestedTab;
                root.networkModel.close();
                root.bluetoothModel.close();
                root.vpnModel.close();
            }
        }
    }

    Connections {
        target: root.vpnModel
        function onVisibleChanged() {
            if (root.vpnModel.visible) {
                root.activeTab = "vpn";
                root.networkModel.close();
                root.bluetoothModel.close();
                root.controlsModel.close();
            }
        }
    }

    onVisibleChanged: {
        if (!visible) {
            root.networkModel.close();
            root.bluetoothModel.close();
            root.controlsModel.close();
            root.vpnModel.close();
        }
    }

    function setVolumePendingFromX(x) {
        volumeSlider.pendingPercent = volumeSlider.percentFromX(x);
    }

    function setBrightnessPendingFromX(x) {
        brightnessSlider.pendingPercent = brightnessSlider.percentFromX(x);
    }

    ShellSurface {
        id: content
        anchors.fill: parent
        anchors.bottomMargin: 12
        focus: true

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                root.networkModel.close();
                root.bluetoothModel.close();
                root.controlsModel.close();
                root.vpnModel.close();
                event.accepted = true;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.popupSpacing

            // TABS
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.buttonHeight + 10
                Layout.maximumHeight: Theme.buttonHeight + 10
                spacing: Theme.rowSpacing

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.activeTab === "wifi" ? Theme.accent : Theme.surface
                    radius: Theme.radius

                    UiText {
                        anchors.centerIn: parent
                        text: "Wi-Fi"
                        font.bold: true
                        color: root.activeTab === "wifi" ? Theme.accentText : Theme.textStrong
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeTab = "wifi"
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.activeTab === "bluetooth" ? Theme.accent : Theme.surface
                    radius: Theme.radius

                    UiText {
                        anchors.centerIn: parent
                        text: "Bluetooth"
                        font.bold: true
                        color: root.activeTab === "bluetooth" ? Theme.accentText : Theme.textStrong
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeTab = "bluetooth"
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.activeTab === "audio" ? Theme.accent : Theme.surface
                    radius: Theme.radius

                    UiText {
                        anchors.centerIn: parent
                        text: "Audio"
                        font.bold: true
                        color: root.activeTab === "audio" ? Theme.accentText : Theme.textStrong
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeTab = "audio"
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.activeTab === "brightness" ? Theme.accent : Theme.surface
                    radius: Theme.radius

                    UiText {
                        anchors.centerIn: parent
                        text: "Display"
                        font.bold: true
                        color: root.activeTab === "brightness" ? Theme.accentText : Theme.textStrong
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeTab = "brightness"
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.activeTab === "vpn" ? Theme.accent : Theme.surface
                    radius: Theme.radius

                    UiText {
                        anchors.centerIn: parent
                        text: "VPN"
                        font.bold: true
                        color: root.activeTab === "vpn" ? Theme.accentText : Theme.textStrong
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeTab = "vpn"
                    }
                }

                Rectangle {
                    Layout.preferredWidth: Theme.buttonHeight + 10
                    Layout.preferredHeight: Theme.buttonHeight + 10
                    color: Theme.transparent
                    radius: Theme.radius

                    UiText {
                        anchors.centerIn: parent
                        text: "x"
                        font.bold: true
                        color: closeMouse.containsMouse ? Theme.accent : Theme.textMuted
                        font.pixelSize: Theme.titleFontSize
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.networkModel.close();
                            root.bluetoothModel.close();
                            root.controlsModel.close();
                            root.vpnModel.close();
                        }
                    }
                }
            }

            // WIFI CONTENT
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.activeTab === "wifi"
                spacing: Theme.popupSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.rowSpacing

                    Text {
                        Layout.fillWidth: true
                        text: root.networkModel.statusText
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.titleFontSize
                        font.bold: true
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    ShellButton {
                        Layout.preferredWidth: implicitWidth
                        Layout.preferredHeight: Theme.buttonHeight
                        label: "Scan"
                        enabled: !root.networkModel.busy
                        onActivated: root.networkModel.refresh(true)
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.networkModel.message.length > 0
                    text: root.networkModel.message
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallFontSize
                    elide: Text.ElideRight
                }

                SectionLabel {
                    label: "Active"
                }

                ListView {
                    ScrollBar.vertical: ScrollBar {}
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(150, Math.max(42, contentHeight))
                    clip: true
                    spacing: Theme.listSpacing
                    model: root.networkModel.activeConnections

                    delegate: NetworkProfileRow {
                        required property var modelData
                        width: ListView.view.width
                        profile: modelData
                        active: true
                        onDisconnectRequested: device => root.networkModel.disconnectDevice(device)
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.networkModel.activeConnections.length === 0
                    text: "No active connections"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallFontSize
                }

                SectionLabel {
                    label: "Wi-Fi"
                }

                ListView {
                    ScrollBar.vertical: ScrollBar {}
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: Theme.listSpacing
                    model: root.networkModel.wifiNetworks

                    delegate: NetworkWifiRow {
                        required property int index
                        required property var modelData
                        width: ListView.view.width
                        network: modelData
                        selected: index === root.networkModel.selectedWifiIndex
                        busy: root.networkModel.busy
                        onSelectedRequested: root.networkModel.selectWifi(index)
                        onConnectRequested: network => {
                            root.networkModel.selectWifi(index);
                            root.networkModel.connectWifi(network);
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.networkModel.wifiNetworks.length === 0
                    text: "No visible Wi-Fi networks"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallFontSize
                }

                Rectangle {
                    readonly property var currentSelectedNetwork: root.networkModel.selectedWifiNetwork()
                    Layout.fillWidth: true
                    Layout.preferredHeight: currentSelectedNetwork !== null && currentSelectedNetwork.secured ? 44 : 0
                    visible: currentSelectedNetwork !== null && currentSelectedNetwork.secured
                    color: Theme.surface
                    radius: Theme.radius

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.rowSpacing
                        anchors.rightMargin: Theme.rowSpacing
                        spacing: Theme.rowSpacing

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            TextInput {
                                id: wifiPasswordInput
                                anchors.fill: parent
                                text: root.networkModel.wifiPassword
                                echoMode: TextInput.Password
                                color: Theme.textStrong
                                selectionColor: Theme.accent
                                selectedTextColor: Theme.accentText
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.inputFontSize
                                clip: true
                                verticalAlignment: TextInput.AlignVCenter
                                enabled: !root.networkModel.busy
                                onTextChanged: root.networkModel.wifiPassword = text
                                onAccepted: root.networkModel.connectSelectedWifi()
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                visible: wifiPasswordInput.text.length === 0
                                text: "Password"
                                color: Theme.placeholder
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.inputFontSize
                            }
                        }

                        ShellButton {
                            Layout.preferredWidth: implicitWidth
                            Layout.preferredHeight: Theme.buttonHeight
                            label: "Connect"
                            enabled: !root.networkModel.busy
                            onActivated: root.networkModel.connectSelectedWifi()
                        }
                    }
                }

                ShellButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.networkModel.editorAvailable ? 36 : 0
                    visible: root.networkModel.editorAvailable
                    label: "Edit Connections"
                    compact: false
                    onActivated: root.networkModel.openEditor()
                }
            }

            // BLUETOOTH CONTENT
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.activeTab === "bluetooth"
                spacing: Theme.popupSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.rowSpacing
                    UiText {
                        Layout.fillWidth: true
                        text: root.bluetoothModel.statusText
                        color: Theme.textStrong
                        font.pixelSize: Theme.titleFontSize
                        font.bold: true
                    }
                    ShellButton {
                        Layout.preferredWidth: implicitWidth
                        Layout.preferredHeight: Theme.buttonHeight
                        label: "Scan"
                        onActivated: root.bluetoothModel.refresh(true)
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.bluetoothModel.message.length > 0
                    text: root.bluetoothModel.message
                    color: root.bluetoothModel.message.indexOf("Failed") >= 0 ? Theme.danger : Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallFontSize
                    elide: Text.ElideRight
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.rowSpacing
                    ShellButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.buttonHeight
                        label: "Bluetooth On"
                        onActivated: root.bluetoothModel.action("bluetooth-power", ["on"])
                    }
                    ShellButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.buttonHeight
                        label: "Bluetooth Off"
                        onActivated: root.bluetoothModel.action("bluetooth-power", ["off"])
                    }
                }

                ListView {
                    ScrollBar.vertical: ScrollBar {}
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: Theme.listSpacing
                    model: root.bluetoothModel.devices

                    delegate: Rectangle {
                        id: deviceRow
                        required property var modelData
                        width: ListView.view.width
                        height: 54
                        radius: Theme.smallRadius
                        color: modelData.connected ? Theme.accent : (deviceMouse.containsMouse ? Theme.surfaceHover : Theme.surface)
                        border.color: Theme.border
                        border.width: 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.rowSpacing
                            anchors.rightMargin: Theme.rowSpacing
                            spacing: Theme.rowSpacing

                            FallbackIcon {
                                iconName: "bluetooth-active"
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                UiText {
                                    Layout.fillWidth: true
                                    text: modelData.name || modelData.address || "Unknown"
                                    color: modelData.connected ? Theme.accentText : Theme.textStrong
                                    font.bold: true
                                }
                                UiText {
                                    Layout.fillWidth: true
                                    text: modelData.paired ? (modelData.connected ? "Connected" : "Paired") : "Available"
                                    color: modelData.connected ? Theme.accentText : Theme.textMuted
                                    font.pixelSize: Theme.smallFontSize
                                }
                            }

                            ShellButton {
                                visible: !modelData.connected
                                label: modelData.paired ? "Connect" : "Pair"
                                compact: true
                                z: 10
                                enabled: !root.bluetoothModel.busy
                                onActivated: root.bluetoothModel.action(modelData.paired ? "bluetooth-connect" : "bluetooth-pair", [modelData.address])
                            }

                            ShellButton {
                                visible: modelData.connected
                                label: "Disconnect"
                                compact: true
                                z: 10
                                enabled: !root.bluetoothModel.busy
                                onActivated: root.bluetoothModel.action("bluetooth-disconnect", [modelData.address])
                            }
                        }

                        MouseArea {
                            id: deviceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            z: -1
                        }
                    }
                }
            }

            // VPN CONTENT
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.activeTab === "vpn"
                spacing: Theme.popupSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.rowSpacing

                    Text {
                        Layout.fillWidth: true
                        text: root.vpnModel.connected
                            ? "VPN connected" + (root.vpnModel.activeProfile.length > 0 ? " - " + root.vpnModel.activeProfile : "")
                            : "VPN disconnected"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.titleFontSize
                        font.bold: true
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    ShellButton {
                        Layout.preferredWidth: implicitWidth
                        Layout.preferredHeight: Theme.buttonHeight
                        label: "Refresh"
                        enabled: !root.vpnModel.busy
                        onActivated: root.vpnModel.refresh()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.vpnModel.message.length > 0
                    text: root.vpnModel.message
                    color: root.vpnModel.message.indexOf("Failed") === 0 ? Theme.danger : Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallFontSize
                    elide: Text.ElideRight
                }

                SectionLabel {
                    label: "Target IP"
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1
                    radius: Theme.radius

                    TextInput {
                        id: vpnTargetInput
                        anchors.fill: parent
                        anchors.leftMargin: Theme.rowSpacing
                        anchors.rightMargin: Theme.rowSpacing
                        text: root.vpnModel.targetInput
                        color: Theme.textStrong
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.inputFontSize
                        clip: true
                        verticalAlignment: TextInput.AlignVCenter
                        enabled: !root.vpnModel.busy
                        onTextChanged: root.vpnModel.targetInput = text
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.rowSpacing
                        anchors.verticalCenter: parent.verticalCenter
                        visible: vpnTargetInput.text.length === 0
                        text: "Target IP"
                        color: Theme.placeholder
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.inputFontSize
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.rowSpacing

                    SectionLabel {
                        Layout.fillWidth: true
                        label: "Profiles"
                    }

                    ShellButton {
                        Layout.preferredWidth: implicitWidth
                        Layout.preferredHeight: Theme.buttonHeight
                        visible: root.vpnModel.connected
                        label: "Disconnect"
                        enabled: !root.vpnModel.busy
                        onActivated: root.vpnModel.disconnect()
                    }
                }

                ListView {
                    ScrollBar.vertical: ScrollBar {}
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: Theme.listSpacing
                    model: root.vpnModel.profiles

                    delegate: Rectangle {
                        id: vpnRow

                        required property var modelData
                        readonly property bool profileActive: root.vpnModel.connected && root.vpnModel.activeProfile === modelData.name

                        width: ListView.view.width
                        height: 54
                        radius: Theme.smallRadius
                        color: profileActive ? Theme.accent : (vpnMouse.containsMouse && !root.vpnModel.busy ? Theme.surfaceHover : Theme.surface)
                        border.color: profileActive ? Theme.accent : Theme.border
                        border.width: 1
                        opacity: root.vpnModel.busy && !profileActive ? 0.5 : 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.rowSpacing
                            anchors.rightMargin: Theme.rowSpacing
                            spacing: Theme.rowSpacing

                            Rectangle {
                                Layout.preferredWidth: 10
                                Layout.preferredHeight: 10
                                Layout.alignment: Qt.AlignVCenter
                                radius: 5
                                color: vpnRow.profileActive ? Theme.accentText : Theme.accentSecondary
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Theme.compactSpacing

                                Text {
                                    Layout.fillWidth: true
                                    text: vpnRow.modelData.name
                                    color: vpnRow.profileActive ? Theme.accentText : Theme.textStrong
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.panelFontSize
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: vpnRow.profileActive ? ("Connected" + (root.vpnModel.vpnIp.length > 0 ? " - " + root.vpnModel.vpnIp : "")) : vpnRow.modelData.path
                                    color: vpnRow.profileActive ? Theme.accentText : Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.smallFontSize
                                    elide: Text.ElideRight
                                }
                            }

                            ShellButton {
                                label: vpnRow.profileActive ? "Connected" : "Connect"
                                compact: true
                                enabled: !root.vpnModel.busy && !vpnRow.profileActive
                                onActivated: root.vpnModel.connectProfile(vpnRow.modelData)
                            }
                        }

                        MouseArea {
                            id: vpnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            z: -1
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.vpnModel.profiles.length === 0
                    text: "No VPN profiles in ~/vpn"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallFontSize
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                visible: root.activeTab === "brightness"
                spacing: root.contentSpacing

                SectionLabel {
                    label: "Brightness"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.rowSpacing

                    Item {
                        id: brightnessSlider

                        property int pendingPercent: root.controlsModel.brightnessPercent
                        property int displayPercent: brightnessMouse.pressed ? pendingPercent : root.controlsModel.brightnessPercent

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
                                width: Math.round((brightnessSlider.displayPercent / 100) * parent.width)
                                height: parent.height
                                color: Theme.accent
                                radius: parent.radius
                            }
                        }

                        Rectangle {
                            width: 20
                            height: 20
                            x: Math.max(0, Math.min(parent.width - width, Math.round((brightnessSlider.displayPercent / 100) * parent.width) - width / 2))
                            y: parent.height / 2 - height / 2
                            color: brightnessMouse.enabled ? Theme.text : Theme.textMuted
                            border.color: Theme.border
                            border.width: 1
                            radius: height / 2
                        }

                        MouseArea {
                            id: brightnessMouse

                            anchors.fill: parent
                            enabled: !root.controlsModel.busy
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: function (mouse) {
                                root.setBrightnessPendingFromX(mouse.x);
                            }
                            onPositionChanged: function (mouse) {
                                if (pressed) {
                                    root.setBrightnessPendingFromX(mouse.x);
                                }
                            }
                            onReleased: function (mouse) {
                                root.setBrightnessPendingFromX(mouse.x);
                                root.controlsModel.brightnessSet(brightnessSlider.pendingPercent);
                            }
                        }
                    }

                    Text {
                        Layout.preferredWidth: root.volumePercentWidth
                        text: root.controlsModel.brightnessPercent + "%"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.panelFontSize
                        font.bold: true
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                visible: root.activeTab === "audio"
                spacing: root.contentSpacing

                SectionLabel {
                    label: "Volume"
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
                            id: sliderTrack

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
                                root.controlsModel.volumeSet(volumeSlider.pendingPercent);
                            }
                        }
                    }

                    Text {
                        Layout.preferredWidth: root.volumePercentWidth
                        text: root.controlsModel.volumePercent + "%"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.panelFontSize
                        font.bold: true
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    ControlsActionButton {
                        Layout.preferredWidth: root.muteButtonWidth
                        Layout.preferredHeight: root.volumeControlHeight
                        label: root.controlsModel.volumeMuted ? "Unmute" : "Mute"
                        enabled: !root.controlsModel.busy
                        onActivated: root.controlsModel.volumeToggleMute()
                    }
                }

                SectionLabel {
                    label: "Output"
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
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(150, Math.max(0, contentHeight))
                    clip: true
                    spacing: Theme.compactSpacing
                    visible: root.controlsModel.outputDevices.length > 0
                    model: root.controlsModel.outputDevices
                    ScrollBar.vertical: ScrollBar {
                        active: true
                        width: 4
                    }

                    delegate: Rectangle {
                        id: outputDeviceRow

                        required property var modelData

                        width: ListView.view.width
                        height: root.outputDeviceRowHeight
                        radius: Theme.radius
                        color: outputDeviceRow.modelData.isDefault ? Theme.accent : (outputMouse.containsMouse && !root.controlsModel.busy ? Theme.surfaceHover : Theme.surface)
                        border.color: outputDeviceRow.modelData.isDefault ? Theme.accent : Theme.border
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

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.rowSpacing

                    SectionLabel {
                        label: "Microphone"
                    }

                    Text {
                        text: root.controlsModel.micText
                        color: root.controlsModel.micText === "MIC muted" ? Theme.danger : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.panelFontSize
                        font.bold: true
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
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(150, Math.max(0, contentHeight))
                    clip: true
                    spacing: Theme.compactSpacing
                    visible: root.controlsModel.inputDevices.length > 0
                    model: root.controlsModel.inputDevices
                    ScrollBar.vertical: ScrollBar {
                        active: true
                        width: 4
                    }

                    delegate: Rectangle {
                        id: inputDeviceRow

                        required property var modelData

                        width: ListView.view.width
                        height: root.outputDeviceRowHeight
                        radius: Theme.radius
                        color: inputDeviceRow.modelData.isDefault ? Theme.accent : (inputMouse.containsMouse && !root.controlsModel.busy ? Theme.surfaceHover : Theme.surface)
                        border.color: inputDeviceRow.modelData.isDefault ? Theme.accent : Theme.border
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

                SectionLabel {
                    label: "Media"
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    color: Theme.surface
                    radius: Theme.radius
                    border.color: Theme.border
                    border.width: 1

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: Theme.compactSpacing

                        Text {
                            width: parent.width
                            text: root.controlsModel.mediaText
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.panelFontSize
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            visible: root.controlsModel.mediaPlayer.length > 0
                            text: root.controlsModel.mediaPlayer
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.smallFontSize
                            elide: Text.ElideRight
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.listSpacing * 2

                    ControlsActionButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.actionButtonHeight
                        label: "Previous"
                        enabled: !root.controlsModel.busy && root.controlsModel.mediaPlayer.length > 0
                        onActivated: root.controlsModel.mediaPrevious()
                    }

                    ControlsActionButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.actionButtonHeight
                        label: "Play/Pause"
                        enabled: !root.controlsModel.busy && root.controlsModel.mediaPlayer.length > 0
                        onActivated: root.controlsModel.mediaPlayPause()
                    }

                    ControlsActionButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.actionButtonHeight
                        label: "Next"
                        enabled: !root.controlsModel.busy && root.controlsModel.mediaPlayer.length > 0
                        onActivated: root.controlsModel.mediaNext()
                    }
                } // RowLayout
            } // Audio ColumnLayout
            Item {
                Layout.fillHeight: true
            }
        }
    }
}
