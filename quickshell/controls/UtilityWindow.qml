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
    property int selectedIndex: 0

    readonly property int popupWidth: 460
    readonly property int popupHeight: 580
    readonly property var tabOrder: ["wifi", "bluetooth", "audio", "brightness", "vpn"]
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
                root.setActiveTab("wifi");
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
                root.setActiveTab("bluetooth");
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
                root.setActiveTab(root.controlsModel.requestedTab);
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
                root.setActiveTab("vpn");
                root.networkModel.close();
                root.bluetoothModel.close();
                root.controlsModel.close();
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            root.selectedIndex = 0;
            Qt.callLater(() => content.forceActiveFocus());
        } else {
            root.networkModel.close();
            root.bluetoothModel.close();
            root.controlsModel.close();
            root.vpnModel.close();
        }
    }

    function setActiveTab(tab) {
        root.activeTab = tab;
        root.selectedIndex = 0;
        Qt.callLater(() => content.forceActiveFocus());
    }

    function cycleTab(delta) {
        let index = root.tabOrder.indexOf(root.activeTab);
        if (index < 0) {
            index = 0;
        }
        index = (index + delta + root.tabOrder.length) % root.tabOrder.length;
        root.setActiveTab(root.tabOrder[index]);
    }

    function selectedWifiNetwork() {
        if (root.networkModel.selectedWifiIndex < 0 || root.networkModel.selectedWifiIndex >= root.networkModel.wifiNetworks.length) {
            return null;
        }
        return root.networkModel.wifiNetworks[root.networkModel.selectedWifiIndex];
    }

    function percentFromText(text, fallbackValue) {
        const match = text.match(/[0-9]+/);
        if (match === null) {
            return fallbackValue;
        }

        return Math.max(0, Math.min(100, parseInt(match[0], 10)));
    }

    function wifiPasswordIndex() {
        const network = root.selectedWifiNetwork();
        return network !== null && network.secured ? 1 + root.networkModel.wifiNetworks.length : -1;
    }

    function wifiEditIndex() {
        let index = 1 + root.networkModel.wifiNetworks.length;
        if (root.wifiPasswordIndex() >= 0) {
            index += 1;
        }
        return root.networkModel.editorAvailable ? index : -1;
    }

    function itemCountForTab() {
        if (root.activeTab === "wifi") {
            return 1 + root.networkModel.wifiNetworks.length
                + (root.wifiPasswordIndex() >= 0 ? 1 : 0)
                + (root.networkModel.editorAvailable ? 1 : 0);
        }
        if (root.activeTab === "bluetooth") {
            return 3 + root.bluetoothModel.devices.length;
        }
        if (root.activeTab === "vpn") {
            return 2 + (root.vpnModel.connected ? 1 : 0) + root.vpnModel.profiles.length;
        }
        if (root.activeTab === "brightness") {
            return 1;
        }
        if (root.activeTab === "audio") {
            return 2 + root.controlsModel.outputDevices.length + root.controlsModel.inputDevices.length + 3;
        }
        return 1;
    }

    function normalizeSelectedIndex() {
        const count = Math.max(1, root.itemCountForTab());
        if (root.selectedIndex < 0) {
            root.selectedIndex = count - 1;
        } else if (root.selectedIndex >= count) {
            root.selectedIndex = 0;
        }

        if (root.activeTab === "wifi" && root.selectedIndex > 0 && root.selectedIndex <= root.networkModel.wifiNetworks.length) {
            root.networkModel.selectWifi(root.selectedIndex - 1);
        }
    }

    function moveSelection(delta) {
        root.selectedIndex += delta;
        root.normalizeSelectedIndex();
    }

    function activateSelected() {
        root.normalizeSelectedIndex();

        if (root.activeTab === "wifi") {
            if (root.selectedIndex === 0) {
                root.networkModel.refresh(true);
                return;
            }
            if (root.selectedIndex <= root.networkModel.wifiNetworks.length) {
                const network = root.networkModel.wifiNetworks[root.selectedIndex - 1];
                root.networkModel.selectWifi(root.selectedIndex - 1);
                if (network.secured && root.networkModel.wifiPassword.length === 0) {
                    Qt.callLater(() => wifiPasswordInput.forceActiveFocus());
                } else {
                    root.networkModel.connectWifi(network);
                }
                return;
            }
            if (root.selectedIndex === root.wifiPasswordIndex()) {
                Qt.callLater(() => wifiPasswordInput.forceActiveFocus());
                return;
            }
            if (root.selectedIndex === root.wifiEditIndex()) {
                root.networkModel.openEditor();
            }
            return;
        }

        if (root.activeTab === "bluetooth") {
            if (root.selectedIndex === 0) {
                root.bluetoothModel.refresh(true);
            } else if (root.selectedIndex === 1) {
                root.bluetoothModel.action("bluetooth-power", ["on"]);
            } else if (root.selectedIndex === 2) {
                root.bluetoothModel.action("bluetooth-power", ["off"]);
            } else {
                const device = root.bluetoothModel.devices[root.selectedIndex - 3];
                if (device) {
                    root.bluetoothModel.action(device.connected ? "bluetooth-disconnect" : (device.paired ? "bluetooth-connect" : "bluetooth-pair"), [device.address]);
                }
            }
            return;
        }

        if (root.activeTab === "vpn") {
            if (root.selectedIndex === 0) {
                root.vpnModel.refresh();
                return;
            }
            if (root.selectedIndex === 1) {
                if (!root.vpnModel.targetLocked) {
                    Qt.callLater(() => vpnTargetInput.forceActiveFocus());
                }
                return;
            }
            let profileOffset = 2;
            if (root.vpnModel.connected) {
                if (root.selectedIndex === 2) {
                    root.vpnModel.disconnect();
                    return;
                }
                profileOffset = 3;
            }
            const profile = root.vpnModel.profiles[root.selectedIndex - profileOffset];
            if (profile) {
                root.vpnModel.connectProfile(profile);
            }
            return;
        }

        if (root.activeTab === "brightness") {
            Qt.callLater(() => brightnessPercentInput.forceActiveFocus());
            return;
        }

        if (root.activeTab === "audio") {
            const outputStart = 2;
            const inputStart = outputStart + root.controlsModel.outputDevices.length;
            const mediaStart = inputStart + root.controlsModel.inputDevices.length;
            if (root.selectedIndex === 0) {
                Qt.callLater(() => volumePercentInput.forceActiveFocus());
            } else if (root.selectedIndex === 1) {
                root.controlsModel.volumeToggleMute();
            } else if (root.selectedIndex >= outputStart && root.selectedIndex < inputStart) {
                root.controlsModel.outputSetDefault(root.controlsModel.outputDevices[root.selectedIndex - outputStart].name);
            } else if (root.selectedIndex >= inputStart && root.selectedIndex < mediaStart) {
                root.controlsModel.inputSetDefault(root.controlsModel.inputDevices[root.selectedIndex - inputStart].name);
            } else if (root.selectedIndex === mediaStart && root.controlsModel.mediaPlayer.length > 0) {
                root.controlsModel.mediaPrevious();
            } else if (root.selectedIndex === mediaStart + 1 && root.controlsModel.mediaPlayer.length > 0) {
                root.controlsModel.mediaPlayPause();
            } else if (root.selectedIndex === mediaStart + 2 && root.controlsModel.mediaPlayer.length > 0) {
                root.controlsModel.mediaNext();
            }
        }
    }

    function adjustSelected(delta) {
        if (root.activeTab === "brightness") {
            if (delta > 0) root.controlsModel.brightnessUp(); else root.controlsModel.brightnessDown();
        } else if (root.activeTab === "audio" && root.selectedIndex === 0) {
            if (delta > 0) root.controlsModel.volumeUp(); else root.controlsModel.volumeDown();
        } else {
            root.moveSelection(delta);
        }
    }

    function setVolumePendingFromX(x) {
        volumeSlider.pendingPercent = volumeSlider.percentFromX(x);
        root.controlsModel.volumeSet(volumeSlider.pendingPercent);
    }

    function setBrightnessPendingFromX(x) {
        brightnessSlider.pendingPercent = brightnessSlider.percentFromX(x);
        root.controlsModel.brightnessSet(brightnessSlider.pendingPercent);
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
                return;
            }

            if (wifiPasswordInput.activeFocus || vpnTargetInput.activeFocus || volumePercentInput.activeFocus || brightnessPercentInput.activeFocus) {
                return;
            }

            if (event.key === Qt.Key_Tab) {
                root.cycleTab((event.modifiers & Qt.ShiftModifier) ? -1 : 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Down) {
                root.moveSelection(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                root.moveSelection(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                root.adjustSelected(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Left) {
                root.adjustSelected(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.activateSelected();
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
                        onClicked: root.setActiveTab("wifi")
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
                        onClicked: root.setActiveTab("bluetooth")
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
                        onClicked: root.setActiveTab("audio")
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
                        onClicked: root.setActiveTab("brightness")
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
                        onClicked: root.setActiveTab("vpn")
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
                        selected: root.activeTab === "wifi" && root.selectedIndex === 0
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
                    border.color: root.activeTab === "wifi" && root.selectedIndex === root.wifiPasswordIndex() ? Theme.accent : Theme.border
                    border.width: 1
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
                    selected: root.activeTab === "wifi" && root.selectedIndex === root.wifiEditIndex()
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
                        selected: root.activeTab === "bluetooth" && root.selectedIndex === 0
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
                        selected: root.activeTab === "bluetooth" && root.selectedIndex === 1
                        onActivated: root.bluetoothModel.action("bluetooth-power", ["on"])
                    }
                    ShellButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.buttonHeight
                        label: "Bluetooth Off"
                        selected: root.activeTab === "bluetooth" && root.selectedIndex === 2
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
                        required property int index
                        required property var modelData
                        readonly property bool selected: root.activeTab === "bluetooth" && root.selectedIndex === index + 3
                        width: ListView.view.width
                        height: 54
                        radius: Theme.smallRadius
                        color: modelData.connected ? Theme.accent : (selected ? Theme.surfaceActive : (deviceMouse.containsMouse ? Theme.surfaceHover : Theme.surface))
                        border.color: selected ? Theme.accent : Theme.border
                        border.width: selected ? 1 : 0

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
                        selected: root.activeTab === "vpn" && root.selectedIndex === 0
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
                    color: root.vpnModel.targetLocked ? Theme.surfaceActive : Theme.surface
                    border.color: root.activeTab === "vpn" && root.selectedIndex === 1 ? Theme.accent : (root.vpnModel.connected ? Theme.accent : Theme.border)
                    border.width: 1
                    radius: Theme.radius

                    TextInput {
                        id: vpnTargetInput
                        anchors.fill: parent
                        anchors.leftMargin: Theme.rowSpacing
                        anchors.rightMargin: root.vpnModel.targetLocked ? 38 : Theme.rowSpacing
                        text: root.vpnModel.targetInput
                        color: root.vpnModel.targetLocked ? Theme.text : Theme.textStrong
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.inputFontSize
                        clip: true
                        verticalAlignment: TextInput.AlignVCenter
                        readOnly: root.vpnModel.targetLocked
                        activeFocusOnPress: !root.vpnModel.targetLocked
                        cursorVisible: !root.vpnModel.targetLocked && activeFocus
                        onTextChanged: {
                            if (!root.vpnModel.targetLocked) {
                                root.vpnModel.targetInput = text;
                            }
                        }
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

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.rowSpacing
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.vpnModel.targetLocked
                        text: "\uf023"
                        color: root.vpnModel.connected ? Theme.accent : Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.bodyFontSize
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
                        selected: root.activeTab === "vpn" && root.selectedIndex === 2
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

                        required property int index
                        required property var modelData
                        readonly property bool profileActive: root.vpnModel.connected && root.vpnModel.activeProfile === modelData.name
                        readonly property bool rowInteractive: !root.vpnModel.busy && !root.vpnModel.connected
                        readonly property int profileSelectionIndex: index + (root.vpnModel.connected ? 3 : 2)
                        readonly property bool selected: root.activeTab === "vpn" && root.selectedIndex === profileSelectionIndex

                        width: ListView.view.width
                        height: 54
                        radius: Theme.smallRadius
                        color: profileActive ? Theme.accent : (selected ? Theme.surfaceActive : (vpnMouse.containsMouse && rowInteractive ? Theme.surfaceHover : Theme.surface))
                        border.color: selected || profileActive ? Theme.accent : Theme.border
                        border.width: 1
                        opacity: (root.vpnModel.busy || root.vpnModel.connected) && !profileActive ? 0.5 : 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.rowSpacing
                            anchors.rightMargin: Theme.rowSpacing
                            spacing: Theme.rowSpacing

                            Item {
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                Layout.alignment: Qt.AlignVCenter

                                Image {
                                    anchors.fill: parent
                                    source: vpnRow.modelData.logoPath && vpnRow.modelData.logoPath.length > 0 ? "file://" + vpnRow.modelData.logoPath : ""
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    asynchronous: true
                                    visible: source.toString().length > 0 && status === Image.Ready
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 10
                                    height: 10
                                    radius: 5
                                    visible: !vpnRow.modelData.logoPath || vpnRow.modelData.logoPath.length === 0
                                    color: vpnRow.profileActive ? Theme.accentText : Theme.accentSecondary
                                }
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
                                    text: vpnRow.profileActive ? ("Connected" + (root.vpnModel.vpnIp.length > 0 ? " - " + root.vpnModel.vpnIp : "")) : "Ready"
                                    color: vpnRow.profileActive ? Theme.accentText : Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.smallFontSize
                                    elide: Text.ElideRight
                                }
                            }

                            ShellButton {
                                label: vpnRow.profileActive ? "Connected" : (root.vpnModel.connected ? "Locked" : "Connect")
                                compact: true
                                enabled: !root.vpnModel.busy && !root.vpnModel.connected && !vpnRow.profileActive
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
                            }
                        }
                    }

                    TextInput {
                        id: brightnessPercentInput
                        Layout.preferredWidth: root.volumePercentWidth
                        text: root.controlsModel.brightnessPercent + "%"
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
                                text = root.controlsModel.brightnessPercent + "%";
                            }
                        }
                        onAccepted: {
                            const value = root.percentFromText(text, root.controlsModel.brightnessPercent);
                            root.controlsModel.brightnessSet(value);
                            text = value + "%";
                            content.forceActiveFocus();
                        }

                        Connections {
                            target: root.controlsModel
                            function onBrightnessPercentChanged() {
                                if (!brightnessPercentInput.activeFocus) {
                                    brightnessPercentInput.text = root.controlsModel.brightnessPercent + "%";
                                }
                            }
                        }
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
                            content.forceActiveFocus();
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

                    ControlsActionButton {
                        Layout.preferredWidth: root.muteButtonWidth
                        Layout.preferredHeight: root.volumeControlHeight
                        label: root.controlsModel.volumeMuted ? "Unmute" : "Mute"
                        enabled: !root.controlsModel.busy
                        selected: root.activeTab === "audio" && root.selectedIndex === 1
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

                        required property int index
                        required property var modelData
                        readonly property int inputSelectionIndex: index + 2 + root.controlsModel.outputDevices.length
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
                        selected: root.activeTab === "audio" && root.selectedIndex === 2 + root.controlsModel.outputDevices.length + root.controlsModel.inputDevices.length
                        onActivated: root.controlsModel.mediaPrevious()
                    }

                    ControlsActionButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.actionButtonHeight
                        label: "Play/Pause"
                        enabled: !root.controlsModel.busy && root.controlsModel.mediaPlayer.length > 0
                        selected: root.activeTab === "audio" && root.selectedIndex === 3 + root.controlsModel.outputDevices.length + root.controlsModel.inputDevices.length
                        onActivated: root.controlsModel.mediaPlayPause()
                    }

                    ControlsActionButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.actionButtonHeight
                        label: "Next"
                        enabled: !root.controlsModel.busy && root.controlsModel.mediaPlayer.length > 0
                        selected: root.activeTab === "audio" && root.selectedIndex === 4 + root.controlsModel.outputDevices.length + root.controlsModel.inputDevices.length
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
