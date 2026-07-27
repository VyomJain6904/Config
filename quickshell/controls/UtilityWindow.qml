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
    required property var calendarModel
    required property var i3State

    property string activeTab: "wifi"
    property int selectedIndex: 0

    readonly property int popupWidth: 560
    readonly property int popupHeight: 740
    readonly property var tabOrder: ["wifi", "bluetooth", "audio", "brightness", "vpn", "calendar"]
    property string pendingTab: ""
    readonly property int contentSpacing: Theme.popupSpacing
    readonly property int rowSpacing: Theme.rowSpacing
    readonly property int actionButtonHeight: Theme.compactButtonHeight
    readonly property int volumeControlHeight: 46
    readonly property int volumePercentWidth: 42
    readonly property int muteButtonWidth: 84
    readonly property int outputDeviceRowHeight: 34
    readonly property string workspaceIconRoot: "file:///usr/share/icons/MacTahoe/"
    readonly property string workspaceFallbackIcon: workspaceIconRoot + "apps/scalable/preferences-system.svg"
    readonly property var workspaceIconMap: ({
            "ghostty": "apps/scalable/com.mitchellh.ghostty-clear.png",
            "helium": "apps/scalable/helium-clear.png",
            "librewolf": "apps/scalable/librewolf-mc.png",
            "sublime": "apps/scalable/sublime-mc.png",
            "burp": "/usr/share/icons/MacTahoe/apps/scalable/burpsuitepro.icns",
            "excalidraw": "/usr/share/icons/MacTahoe/apps/scalable/pake-excalidraw-mc.png",
            "camera": "apps/scalable/camera-clear.png",
            "discord": "apps/scalable/com.discordapp.Discord-clear.png",
            "obs": "apps/scalable/com.obsproject.Studio-clear.png",
            "whatsapp": "apps/scalable/com.whatsapp.Whatsapp-clear.png",
            "obsidian": "apps/scalable/md.obsidian-clear.png",
            "nvidia": "apps/scalable/nvidia-clear.png",
            "thunar": "apps/scalable/org.gtk.FileManager-clear.png",
            "telegram": "apps/scalable/org.telegram.desktop-clear.png",
            "vlc": "apps/scalable/org.videolan.VLC-clear.png",
            "terminal": "apps/scalable/utilities-terminal-clear.png",
            "wireshark": "apps/scalable/wireshark-clear.png",
            "alacritty": "apps/scalable/alacritty-mc.png",
            "antigravity": "apps/scalable/antigravity-mc.png",
            "localsend": "apps/scalable/localsend-mc.png",
            "torbrowser": "apps/scalable/torbrowser-mc.png",
            "vmware-workstation": "apps/scalable/vmware-workstation-mc.png"
        })

    function workspaceAppIconSource(iconKey) {
        const key = (iconKey || "").toString().toLowerCase().trim();
        const icon = root.workspaceIconMap[key] || "";
        if (icon.length === 0) {
            return root.workspaceFallbackIcon;
        }
        return icon.indexOf("/") === 0 ? "file://" + icon : root.workspaceIconRoot + icon;
    }

    visible: networkModel.visible || controlsModel.visible || vpnModel.visible || calendarModel.visible
    implicitWidth: popupWidth
    implicitHeight: popupHeight
    title: "Quickshell Utility"
    color: Theme.transparent

    Connections {
        target: root.networkModel
        function onVisibleChanged() {
            if (root.networkModel.visible) {
                root.setActiveTab("wifi");
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
                root.controlsModel.close();
            }
        }
    }

    Connections {
        target: root.calendarModel
        function onVisibleChanged() {
            if (root.calendarModel.visible) {
                root.setActiveTab("calendar");
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            root.selectedIndex = 0;
            Qt.callLater(() => content.forceActiveFocus());
        } else {
            root.networkModel.close();
            root.controlsModel.close();
            root.vpnModel.close();
            root.calendarModel.close();
        }
        root.updateWorkspaceGridActive();
    }

    function setActiveTab(tab) {
        root.activeTab = tab;
        root.selectedIndex = 0;
        root.updateWorkspaceGridActive();
        Qt.callLater(() => content.forceActiveFocus());
    }

    function activateTab(tab) {
        if (tab === "wifi") {
            root.networkModel.visible = true;
            root.controlsModel.close();
            root.vpnModel.close();
            root.calendarModel.close();
            root.setActiveTab("wifi");
            root.networkModel.refresh(false);
        } else if (tab === "bluetooth" || tab === "audio" || tab === "brightness") {
            root.controlsModel.requestedTab = tab;
            root.controlsModel.visible = true;
            root.networkModel.close();
            root.vpnModel.close();
            root.calendarModel.close();
            root.setActiveTab(tab);
            if (tab === "bluetooth") {
                root.bluetoothModel.refresh(false);
                root.controlsModel.refreshBluetoothStatus();
            } else if (tab === "audio") {
                root.controlsModel.refreshAudioStatus();
                root.controlsModel.refreshOutputDevices();
                root.controlsModel.refreshInputDevices();
                root.controlsModel.refreshMediaStatus();
            } else {
                root.controlsModel.refreshBrightnessStatus();
            }
        } else if (tab === "vpn") {
            root.vpnModel.visible = true;
            root.networkModel.close();
            root.controlsModel.close();
            root.calendarModel.close();
            root.setActiveTab("vpn");
            root.vpnModel.refreshProfiles();
            root.vpnModel.refresh();
        } else if (tab === "calendar") {
            root.calendarModel.visible = true;
            root.networkModel.close();
            root.controlsModel.close();
            root.vpnModel.close();
            root.setActiveTab("calendar");
            if (root.calendarModel.events.length === 0) {
                root.calendarModel.refreshEvents();
            }
        }
    }

    function scheduleTab(tab) {
        root.pendingTab = tab;
        root.setActiveTab(tab);
        tabActivationTimer.restart();
    }

    function updateWorkspaceGridActive() {
        root.i3State.windowGridActive = root.visible && root.activeTab === "brightness";
    }

    Component.onCompleted: {
        if (root.networkModel.visible) {
            root.setActiveTab("wifi");
        } else if (root.controlsModel.visible) {
            root.setActiveTab(root.controlsModel.requestedTab);
        } else if (root.vpnModel.visible) {
            root.setActiveTab("vpn");
        } else if (root.calendarModel.visible) {
            root.setActiveTab("calendar");
        } else {
            root.updateWorkspaceGridActive();
        }
    }

    function cycleTab(delta) {
        let index = root.tabOrder.indexOf(root.activeTab);
        if (index < 0) {
            index = 0;
        }
        index = (index + delta + root.tabOrder.length) % root.tabOrder.length;
        root.scheduleTab(root.tabOrder[index]);
    }

    Timer {
        id: tabActivationTimer

        interval: 120
        repeat: false
        onTriggered: {
            if (root.pendingTab === root.activeTab) {
                root.activateTab(root.pendingTab);
            }
            root.pendingTab = "";
        }
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
        return network !== null && network.secured ? 2 + root.networkModel.wifiNetworks.length : -1;
    }

    function wifiEditIndex() {
        let index = 2 + root.networkModel.wifiNetworks.length;
        if (root.wifiPasswordIndex() >= 0) {
            index += 1;
        }
        return root.networkModel.editorAvailable ? index : -1;
    }

    function itemCountForTab() {
        if (root.activeTab === "wifi") {
            return 2 + root.networkModel.wifiNetworks.length + (root.wifiPasswordIndex() >= 0 ? 1 : 0) + (root.networkModel.editorAvailable ? 1 : 0);
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

        if (root.activeTab === "wifi" && root.selectedIndex >= 2 && root.selectedIndex < 2 + root.networkModel.wifiNetworks.length) {
            root.networkModel.selectWifi(root.selectedIndex - 2);
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
            if (root.selectedIndex === 1) {
                root.networkModel.toggleHotspot();
                return;
            }
            if (root.selectedIndex < 2 + root.networkModel.wifiNetworks.length) {
                const network = root.networkModel.wifiNetworks[root.selectedIndex - 2];
                root.networkModel.selectWifi(root.selectedIndex - 2);
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
            if (delta > 0)
                root.controlsModel.brightnessUp();
            else
                root.controlsModel.brightnessDown();
        } else if (root.activeTab === "audio" && root.selectedIndex === 0) {
            if (delta > 0)
                root.controlsModel.volumeUp();
            else
                root.controlsModel.volumeDown();
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
                root.controlsModel.close();
                root.vpnModel.close();
                root.calendarModel.close();
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

            // STICKY TOP TAB NAVIGATION BAR
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
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
                        onClicked: root.activateTab("wifi")
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
                        onClicked: root.activateTab("bluetooth")
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
                        onClicked: root.activateTab("audio")
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
                        onClicked: root.activateTab("brightness")
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
                        onClicked: root.activateTab("vpn")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.activeTab === "calendar" ? Theme.accent : Theme.surface
                    radius: Theme.radius

                    UiText {
                        anchors.centerIn: parent
                        text: "Calendar"
                        font.bold: true
                        color: root.activeTab === "calendar" ? Theme.accentText : Theme.textStrong
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activateTab("calendar")
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
                            root.controlsModel.close();
                            root.vpnModel.close();
                            root.calendarModel.close();
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
                    label: "Hotspot"
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: hotspotColumn.implicitHeight + Theme.rowSpacing * 2
                    color: Theme.surface
                    border.color: root.activeTab === "wifi" && root.selectedIndex === 1 ? Theme.accent : Theme.border
                    border.width: 1
                    radius: Theme.radius

                    ColumnLayout {
                        id: hotspotColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.rowSpacing
                        anchors.rightMargin: Theme.rowSpacing
                        spacing: Theme.compactSpacing

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.rowSpacing

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Theme.compactSpacing

                                Text {
                                    Layout.fillWidth: true
                                    text: root.networkModel.hotspotAvailable ? root.networkModel.hotspotSsid : "Hotspot unavailable"
                                    color: Theme.textStrong
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.panelFontSize
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                            }

                            ShellButton {
                                Layout.preferredWidth: implicitWidth
                                Layout.preferredHeight: Theme.buttonHeight
                                label: root.networkModel.editingHotspot ? "Cancel" : "Edit"
                                enabled: root.networkModel.hotspotAvailable && !root.networkModel.busy
                                onActivated: {
                                    if (root.networkModel.editingHotspot) {
                                        root.networkModel.cancelEditingHotspot();
                                    } else {
                                        root.networkModel.startEditingHotspot();
                                    }
                                }
                            }

                            ShellButton {
                                Layout.preferredWidth: implicitWidth
                                Layout.preferredHeight: Theme.buttonHeight
                                label: root.networkModel.hotspotActive ? "Stop" : "Start"
                                enabled: root.networkModel.hotspotAvailable && !root.networkModel.busy
                                selected: root.activeTab === "wifi" && root.selectedIndex === 1
                                onActivated: root.networkModel.toggleHotspot()
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.networkModel.editingHotspot
                            spacing: Theme.compactSpacing

                            Text {
                                text: "Hotspot Name (SSID)"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.smallFontSize
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                color: Theme.surface
                                border.color: Theme.border
                                border.width: 1
                                radius: Theme.radius

                                TextInput {
                                    id: hotspotSsidInput
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.rowSpacing
                                    anchors.rightMargin: Theme.rowSpacing
                                    text: root.networkModel.hotspotSsidInput
                                    color: Theme.textStrong
                                    selectionColor: Theme.accent
                                    selectedTextColor: Theme.accentText
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.inputFontSize
                                    clip: true
                                    verticalAlignment: TextInput.AlignVCenter
                                    onTextChanged: root.networkModel.hotspotSsidInput = text
                                }
                            }

                            Text {
                                text: "Hotspot Password (min 8 chars)"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.smallFontSize
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                color: Theme.surface
                                border.color: Theme.border
                                border.width: 1
                                radius: Theme.radius

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.rowSpacing
                                    anchors.rightMargin: Theme.rowSpacing
                                    spacing: 4

                                    TextInput {
                                        id: hotspotPasswordInput
                                        property bool showPassword: false
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        text: root.networkModel.hotspotPasswordInput
                                        echoMode: showPassword ? TextInput.Normal : TextInput.Password
                                        color: Theme.textStrong
                                        selectionColor: Theme.accent
                                        selectedTextColor: Theme.accentText
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.inputFontSize
                                        clip: true
                                        verticalAlignment: TextInput.AlignVCenter
                                        onTextChanged: root.networkModel.hotspotPasswordInput = text
                                    }

                                    Text {
                                        text: hotspotPasswordInput.showPassword ? "Hide" : "Show"
                                        color: eyeMouse.containsMouse ? Theme.accent : Theme.textMuted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.smallFontSize
                                        Layout.alignment: Qt.AlignVCenter

                                        MouseArea {
                                            id: eyeMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: hotspotPasswordInput.showPassword = !hotspotPasswordInput.showPassword
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.rowSpacing

                                Text {
                                    Layout.fillWidth: true
                                    visible: hotspotPasswordInput.text.length < 8
                                    text: "Password must be >= 8 chars"
                                    color: Theme.danger
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.smallFontSize
                                }

                                Item {
                                    Layout.fillWidth: true
                                    visible: hotspotPasswordInput.text.length >= 8
                                }

                                ShellButton {
                                    Layout.preferredWidth: implicitWidth
                                    Layout.preferredHeight: Theme.buttonHeight
                                    label: "Save"
                                    enabled: hotspotSsidInput.text.length > 0 && hotspotPasswordInput.text.length >= 8 && !root.networkModel.busy
                                    onActivated: root.networkModel.saveHotspotConfig(hotspotSsidInput.text, hotspotPasswordInput.text)
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.networkModel.hotspotActive && root.networkModel.hotspotClients.length === 0
                            text: "No connected devices"
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.smallFontSize
                            elide: Text.ElideRight
                        }

                        Repeater {
                            model: root.networkModel.hotspotClients

                            RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: Theme.rowSpacing

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.smallFontSize
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: modelData.ip
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.smallFontSize
                                }
                            }
                        }
                    }
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

                            RowLayout {
                                anchors.fill: parent
                                spacing: 4

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    TextInput {
                                        id: wifiPasswordInput
                                        property bool showPassword: false
                                        anchors.fill: parent
                                        text: root.networkModel.wifiPassword
                                        echoMode: showPassword ? TextInput.Normal : TextInput.Password
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

                                Text {
                                    text: wifiPasswordInput.showPassword ? "Hide" : "Show"
                                    color: wifiEyeMouse.containsMouse ? Theme.accent : Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.smallFontSize
                                    Layout.alignment: Qt.AlignVCenter

                                    MouseArea {
                                        id: wifiEyeMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: wifiPasswordInput.showPassword = !wifiPasswordInput.showPassword
                                    }
                                }
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
                        text: root.vpnModel.connected ? "VPN connected" + (root.vpnModel.activeProfile.length > 0 ? " - " + root.vpnModel.activeProfile : "") : "VPN disconnected"
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

                SectionLabel {
                    label: "Workspaces"
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: root.rowSpacing
                    rowSpacing: Theme.listSpacing

                    Repeater {
                        model: root.i3State.workspaceAppGrid

                        delegate: Rectangle {
                            id: workspaceTile

                            required property var modelData

                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(74, (Math.ceil(modelData.windows.length / 3) * 56) + 16)
                            color: modelData.focused ? Theme.surfaceActive : ((workspaceMouse.containsMouse || workspaceDrop.containsDrag) ? Theme.surfaceHover : Theme.surface)
                            border.color: (modelData.focused || workspaceDrop.containsDrag) ? Theme.accent : Theme.border
                            border.width: 1
                            radius: Theme.radius

                            MouseArea {
                                id: workspaceMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.i3State.switchWorkspace(modelData.num)
                            }

                            Item {
                                anchors.fill: parent
                                anchors.margins: 8

                                Item {
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: iconGrid.implicitHeight

                                    GridLayout {
                                        id: iconGrid

                                        anchors.centerIn: parent
                                        width: Math.min(parent.width, Math.max(0, Math.min(3, modelData.windows.length) * 46 + Math.max(0, Math.min(3, modelData.windows.length) - 1) * 10))
                                        height: implicitHeight
                                        columns: 3
                                        columnSpacing: 10
                                        rowSpacing: 10

                                        Repeater {
                                            model: modelData.windows

                                            delegate: Item {
                                                id: iconSlot

                                                required property var modelData

                                                Layout.preferredWidth: 46
                                                Layout.preferredHeight: 46
                                                Layout.minimumWidth: 46
                                                Layout.minimumHeight: 46
                                                Layout.maximumWidth: 46
                                                Layout.maximumHeight: 46

                                                property bool dragStarted: false
                                                property bool dragging: dragStarted

                                                Image {
                                                    anchors.fill: parent
                                                    source: root.workspaceAppIconSource(iconSlot.modelData.iconKey)
                                                    fillMode: Image.PreserveAspectFit
                                                    asynchronous: true
                                                    smooth: true
                                                    mipmap: true
                                                    opacity: iconSlot.dragging ? 0.45 : 1
                                                }

                                                Item {
                                                    id: dragProxy

                                                    property string conId: iconSlot.modelData.conId ? iconSlot.modelData.conId.toString() : ""
                                                    property int workspaceNum: iconSlot.modelData.workspaceNum

                                                    width: iconSlot.width
                                                    height: iconSlot.height
                                                    x: 0
                                                    y: 0
                                                    z: iconSlot.dragging ? 1000 : 0
                                                    visible: iconSlot.dragging
                                                    Drag.active: iconSlot.dragging
                                                    Drag.hotSpot.x: width / 2
                                                    Drag.hotSpot.y: height / 2
                                                    Drag.keys: ["application/x-i3-con-id"]
                                                    Drag.mimeData: ({
                                                            "application/x-i3-con-id": conId.toString()
                                                        })
                                                    Drag.source: dragProxy

                                                    Image {
                                                        anchors.fill: parent
                                                        source: root.workspaceAppIconSource(iconSlot.modelData.iconKey)
                                                        fillMode: Image.PreserveAspectFit
                                                        smooth: true
                                                        mipmap: true
                                                    }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    acceptedButtons: Qt.LeftButton
                                                    hoverEnabled: true
                                                    preventStealing: true
                                                    cursorShape: iconSlot.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                                    drag.target: dragProxy
                                                    drag.threshold: 6
                                                    onPressed: {
                                                        iconSlot.dragStarted = false;
                                                        dragProxy.x = 0;
                                                        dragProxy.y = 0;
                                                    }
                                                    onPositionChanged: {
                                                        if (pressed && (Math.abs(dragProxy.x) > 3 || Math.abs(dragProxy.y) > 3)) {
                                                            iconSlot.dragStarted = true;
                                                        }
                                                    }
                                                    onReleased: {
                                                        if (iconSlot.dragStarted) {
                                                            dragProxy.Drag.drop();
                                                        }
                                                        iconSlot.dragStarted = false;
                                                        dragProxy.x = 0;
                                                        dragProxy.y = 0;
                                                    }
                                                    onCanceled: {
                                                        iconSlot.dragStarted = false;
                                                        dragProxy.x = 0;
                                                        dragProxy.y = 0;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            DropArea {
                                id: workspaceDrop

                                z: 50
                                anchors.fill: parent
                                keys: ["application/x-i3-con-id"]
                                onDropped: function (drop) {
                                    if (!drop.source || !drop.source.conId) {
                                        return;
                                    }

                                    drop.accepted = true;
                                    if (drop.source.workspaceNum === workspaceTile.modelData.num) {
                                        return;
                                    }

                                    root.i3State.moveWindowToWorkspace(drop.source.conId, workspaceTile.modelData.num);
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

                        Item {
                            id: mediaMarquee
                            width: parent.width
                            height: mediaTitleText.implicitHeight
                            clip: true

                            Text {
                                id: mediaTitleText
                                text: root.controlsModel.mediaText
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.panelFontSize
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                                x: mediaAnim.running ? mediaAnim.from : ((parent.width - implicitWidth) / 2)
                            }

                            NumberAnimation {
                                id: mediaAnim
                                target: mediaTitleText
                                property: "x"
                                from: mediaMarquee.width
                                to: -mediaTitleText.implicitWidth
                                duration: Math.max(3000, mediaTitleText.implicitWidth * 30)
                                loops: 1
                            }

                            Timer {
                                id: mediaStartTimer
                                interval: 1000
                                running: false
                                repeat: false
                                onTriggered: {
                                    if (root.controlsModel.mediaState === "Playing" && mediaTitleText.implicitWidth > mediaMarquee.width) {
                                        mediaTitleText.x = mediaMarquee.width;
                                        mediaAnim.start();
                                    }
                                }
                            }

                            function startMarquee() {
                                if (mediaAnim.running || mediaStartTimer.running)
                                    return;
                                mediaTitleText.x = mediaMarquee.width;
                                mediaStartTimer.restart();
                            }

                            function stopMarquee() {
                                mediaAnim.stop();
                                mediaTitleText.x = (mediaMarquee.width - mediaTitleText.implicitWidth) / 2;
                            }

                            Connections {
                                target: root.controlsModel
                                function onMediaStateChanged() {
                                    if (root.controlsModel.mediaState === "Playing") {
                                        mediaMarquee.startMarquee();
                                    } else {
                                        mediaMarquee.stopMarquee();
                                    }
                                }

                                function onMediaTextChanged() {
                                    if (root.controlsModel.mediaState === "Playing") {
                                        mediaMarquee.startMarquee();
                                    } else {
                                        mediaMarquee.stopMarquee();
                                    }
                                }
                            }

                            onWidthChanged: {
                                if (root.controlsModel.mediaState === "Playing" && mediaTitleText.implicitWidth > width) {
                                    mediaMarquee.startMarquee();
                                } else {
                                    mediaMarquee.stopMarquee();
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.controlsModel.mediaState === "Playing"
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: mediaMarquee.startMarquee()
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

            // CALENDAR CONTENT CONTAINER (Static Month Grid + Independent Scrollable Event List)
            ColumnLayout {
                id: calContainer
                visible: root.activeTab === "calendar"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.popupSpacing

                property date currentDate: new Date()
                property int currentMonth: currentDate.getMonth()
                property int currentYear: currentDate.getFullYear()
                property int selectedDay: 0
                property var days: []

                function getDateString(day) {
                    if (day === 0)
                        return "";
                    const m = (currentMonth + 1).toString().padStart(2, '0');
                    const d = day.toString().padStart(2, '0');
                    return currentYear + "-" + m + "-" + d;
                }

                function formatEventBadge(dateStr, timeStr, isHoliday) {
                    let datePart = "";
                    if (dateStr) {
                        const parts = dateStr.split("-");
                        if (parts.length === 3) {
                            const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                            const mIdx = parseInt(parts[1], 10) - 1;
                            const d = parseInt(parts[2], 10);
                            if (mIdx >= 0 && mIdx < 12) {
                                datePart = months[mIdx] + " " + d;
                            }
                        }
                    }
                    const tYear = currentDate.getFullYear();
                    const tMonth = (currentDate.getMonth() + 1).toString().padStart(2, '0');
                    const tDay = currentDate.getDate().toString().padStart(2, '0');
                    const todayStr = tYear + "-" + tMonth + "-" + tDay;
                    if (dateStr === todayStr) {
                        datePart = "Today";
                    }

                    const timePart = (timeStr && timeStr.length > 0) ? timeStr : "All Day";
                    if (isHoliday) {
                        return (datePart ? datePart + " • " : "") + "Holiday (" + timePart + ")";
                    }
                    return datePart ? (datePart + " • " + timePart) : timePart;
                }

                function updateMonth(offset) {
                    let m = currentMonth + offset;
                    let y = currentYear;
                    if (m < 0) {
                        m = 11;
                        y--;
                    } else if (m > 11) {
                        m = 0;
                        y++;
                    }
                    currentMonth = m;
                    currentYear = y;
                    selectedDay = 0;
                    generateDays();
                    root.calendarModel.refreshEventsForMonth(currentMonth + 1, currentYear);
                }

                function generateDays() {
                    const firstDay = new Date(currentYear, currentMonth, 1).getDay();
                    const totalDays = new Date(currentYear, currentMonth + 1, 0).getDate();
                    const list = [];
                    for (let i = 0; i < firstDay; i++) {
                        list.push(0);
                    }
                    for (let d = 1; d <= totalDays; d++) {
                        list.push(d);
                    }
                    while (list.length % 7 !== 0) {
                        list.push(0);
                    }
                    days = list;
                }

                Component.onCompleted: generateDays()

                // Month Navigation Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.rowSpacing

                    ShellButton {
                        label: "<<"
                        Layout.preferredWidth: 32
                        onActivated: calContainer.updateMonth(-12)
                    }

                    ShellButton {
                        label: "<"
                        Layout.preferredWidth: 32
                        onActivated: calContainer.updateMonth(-1)
                    }

                    UiText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.formatDateTime(new Date(calContainer.currentYear, calContainer.currentMonth, 1), "MMMM yyyy")
                        color: Theme.textStrong
                        font.pixelSize: Theme.titleFontSize
                        font.bold: true
                    }

                    ShellButton {
                        label: ">"
                        Layout.preferredWidth: 32
                        onActivated: calContainer.updateMonth(1)
                    }

                    ShellButton {
                        label: ">>"
                        Layout.preferredWidth: 32
                        onActivated: calContainer.updateMonth(12)
                    }

                    ShellButton {
                        label: "T"
                        Layout.preferredWidth: implicitWidth
                        onActivated: {
                            calContainer.currentMonth = calContainer.currentDate.getMonth();
                            calContainer.currentYear = calContainer.currentDate.getFullYear();
                            calContainer.selectedDay = calContainer.currentDate.getDate();
                            calContainer.generateDays();
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.border
                }

                // Weekdays Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                        delegate: UiText {
                            required property string modelData
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: Theme.textMuted
                            font.bold: true
                        }
                    }
                }

                // Calendar Month Grid Container (Static at top with gesture MouseArea)
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 230

                    GridLayout {
                        anchors.fill: parent
                        columns: 7
                        columnSpacing: 4
                        rowSpacing: 4

                        Repeater {
                            model: calContainer.days
                            delegate: Rectangle {
                                required property int modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                color: Theme.transparent

                                property string dateStr: calContainer.getDateString(modelData)
                                property var dayEvents: dateStr.length > 0 && root.calendarModel.eventsByDate ? (root.calendarModel.eventsByDate[dateStr] || []) : []
                                property bool hasEvents: dayEvents.length > 0
                                property bool isSelected: modelData !== 0 && modelData === calContainer.selectedDay
                                property bool isToday: modelData !== 0 && modelData === calContainer.currentDate.getDate() && calContainer.currentMonth === calContainer.currentDate.getMonth() && calContainer.currentYear === calContainer.currentDate.getFullYear()
                                property bool hasHoliday: dayEvents.some(function (e) {
                                    return e.is_holiday;
                                })

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: isToday ? Theme.accent : (isSelected ? Theme.surfaceHover : Theme.transparent)
                                    border.color: isSelected && !isToday ? Theme.accent : "transparent"
                                    border.width: 1

                                    UiText {
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: (hasEvents && modelData !== 0) ? -3 : 0
                                        text: modelData === 0 ? "" : modelData
                                        color: isToday ? Theme.surface : Theme.textStrong
                                        font.bold: isToday || isSelected
                                        font.pixelSize: Theme.smallFontSize
                                    }

                                    Rectangle {
                                        visible: hasEvents && modelData !== 0
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 4
                                        width: 4
                                        height: 4
                                        radius: 2
                                        color: isToday ? Theme.surface : (hasHoliday ? Theme.danger : Theme.success)
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: modelData !== 0
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: calContainer.selectedDay = modelData
                                    }
                                }
                            }
                        }

                        MouseArea {
                            width: parent.width
                            height: parent.height
                            z: 10
                            acceptedButtons: Qt.NoButton
                            hoverEnabled: false

                            property double lastWheelTime: 0

                            onWheel: function (wheel) {
                                const now = Date.now();
                                if (now - lastWheelTime < 250) {
                                    return;
                                }
                                let delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                                if (delta < 0) {
                                    lastWheelTime = now;
                                    calContainer.updateMonth(1);
                                } else if (delta > 0) {
                                    lastWheelTime = now;
                                    calContainer.updateMonth(-1);
                                }
                            }
                        }
                    }
                } // End Item (Month Grid Container)

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.border
                }

                // Chronological Event Timeline (Independent Scrollable ListView)
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    UiText {
                        text: calContainer.selectedDay > 0 ? "Events for " + calContainer.getDateString(calContainer.selectedDay) : "Upcoming Events"
                        color: Theme.textStrong
                        font.bold: true
                        font.pixelSize: Theme.smallFontSize
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6

                        model: {
                            const allEvents = root.calendarModel.events || [];

                            // 1. Specific Date Selection View: Show ALL events (personal + holidays) for that date
                            if (calContainer.selectedDay > 0) {
                                const dateStr = calContainer.getDateString(calContainer.selectedDay);
                                return allEvents.filter(function (e) {
                                    return e.date === dateStr;
                                });
                            }

                            // 2. Default Upcoming Events View: Show ONLY National Holidays
                            const mStr = (calContainer.currentMonth + 1).toString().padStart(2, '0');
                            const prefix = calContainer.currentYear + "-" + mStr + "-";
                            const holidaysOnly = allEvents.filter(function (e) {
                                return e.is_holiday === true;
                            });
                            const monthHolidays = holidaysOnly.filter(function (e) {
                                return e.date && e.date.startsWith(prefix);
                            });

                            if (monthHolidays.length > 0) {
                                return monthHolidays;
                            }
                            return holidaysOnly.filter(function (e) {
                                return e.date >= prefix + "01";
                            });
                        }

                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view.width
                            implicitHeight: eventCol.implicitHeight + 14
                            color: modelData.is_holiday ? Theme.surfaceHover : Theme.surface
                            border.color: modelData.is_holiday ? Theme.borderStrong : Theme.border
                            border.width: modelData.is_holiday ? 1 : 0
                            radius: Theme.smallRadius

                            ColumnLayout {
                                id: eventCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                anchors.topMargin: 7
                                spacing: 3

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    UiText {
                                        Layout.fillWidth: true
                                        text: modelData.summary || "Untitled Event"
                                        color: Theme.textStrong
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    UiText {
                                        text: calContainer.formatEventBadge(modelData.date, modelData.time, modelData.is_holiday)
                                        color: modelData.is_holiday ? Theme.danger : Theme.accent
                                        font.pixelSize: Theme.tinyFontSize
                                        font.bold: true
                                    }
                                }
                            }
                        }

                        UiText {
                            anchors.centerIn: parent
                            visible: parent.count === 0
                            text: root.calendarModel.loading ? "Loading events..." : "No events scheduled"
                            color: Theme.textMuted
                            font.pixelSize: Theme.smallFontSize
                        }
                    }
                }
            } // End calContainer ColumnLayout
        }
    }
}
