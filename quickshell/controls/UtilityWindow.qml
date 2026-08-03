pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.ai
import qs.calendar
import qs.controls
import qs.core
import qs.network

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *                    MASTER UTILITY WINDOW (UtilityWindow.qml)
 * ─────────────────────────────────────────────────────────────────────────────
 * Central interactive hub housing tabs for Wi-Fi, Bluetooth, Audio/Media,
 * Display Brightness, Battery management, VPN connections, Calendar events,
 * and AI usage statistics.
 * ─────────────────────────────────────────────────────────────────────────────
 */
FloatingWindow {
    id: root

    required property var networkModel
    required property var bluetoothModel
    required property var controlsModel
    required property var vpnModel
    required property var calendarModel
    required property var aiModel
    required property var i3State
    property string vpnFontFamily: "JetBrainsMono-VPN"

    property string activeTab: "wifi"
    property int selectedIndex: 0
    property bool showSavedWifi: false

    readonly property int popupWidth: 560
    readonly property int popupHeight: 820
    readonly property var tabOrder: ["wifi", "bluetooth", "audio", "brightness", "battery", "vpn", "calendar", "ai"]
    property string pendingTab: ""
    readonly property int contentSpacing: Theme.popupSpacing
    readonly property int rowSpacing: Theme.rowSpacing
    readonly property int volumeControlHeight: 32
    readonly property int volumePercentWidth: 42
    readonly property int mediaThumbnailHeight: 240
    readonly property int outputDeviceRowHeight: 32
    readonly property int outputDeviceListMaxHeight: 68
    readonly property int inputDeviceListMaxHeight: 68
    readonly property int deviceListReservedHeight: outputDeviceRowHeight * 2 + Theme.compactSpacing
    readonly property string workspaceIconRoot: "file:///usr/share/icons/MacTahoe/"
    readonly property string workspaceFallbackIcon: workspaceIconRoot + "apps/scalable/preferences-system.svg"
    readonly property var workspaceIconMap: ({
            "ghostty": "apps/scalable/com.mitchellh.ghostty-clear.png",
            "helium": "apps/scalable/helium-clear.png",
            "sublime": "apps/scalable/sublime-mc.png",
            "burp": "/usr/share/icons/MacTahoe/apps/scalable/burpsuitepro.icns",
            "excalidraw": "/usr/share/icons/MacTahoe/apps/scalable/pake-excalidraw-mc.png",
            "camera": "apps/scalable/camera-clear.png",
            "discord": "apps/scalable/com.discordapp.Discord-clear.png",
            "obs": "apps/scalable/com.obsproject.Studio-clear.png",
            "whatsapp": "apps/scalable/com.whatsapp.Whatsapp-clear.png",
            "obsidian": "apps/scalable/md.obsidian-clear.png",
            "thunar": "apps/scalable/org.gtk.FileManager-clear.png",
            "telegram": "apps/scalable/org.telegram.desktop-clear.png",
            "vlc": "apps/scalable/org.videolan.VLC-clear.png",
            "terminal": "apps/scalable/utilities-terminal-clear.png",
            "wireshark": "apps/scalable/wireshark-clear.png",
            "alacritty": "apps/scalable/alacritty-mc.png",
            "antigravity": "apps/scalable/antigravity-mc.png",
            "localsend": "apps/scalable/localsend-mc.png",
            "torbrowser": "apps/scalable/torbrowser-mc.png",
            "vmware-workstation": "apps/scalable/vmware-workstation-mc.png",
            "brave-origin": "apps/scalable/brave-browser-clear.png"
        })

    function workspaceAppIconSource(iconKey) {
        const key = (iconKey || "").toString().toLowerCase().trim();
        const icon = root.workspaceIconMap[key] || "";
        if (icon.length === 0) {
            return root.workspaceFallbackIcon;
        }
        return icon.indexOf("/") === 0 ? "file://" + icon : root.workspaceIconRoot + icon;
    }

    visible: networkModel.visible || controlsModel.visible || vpnModel.visible || calendarModel.visible || aiModel.visible
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

    Connections {
        target: root.aiModel
        function onVisibleChanged() {
            if (root.aiModel.visible) {
                root.setActiveTab("ai");
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
            root.aiModel.close();
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
            root.aiModel.close();
            root.setActiveTab("wifi");
            root.networkModel.refresh(false);
        } else if (tab === "bluetooth" || tab === "audio" || tab === "brightness" || tab === "battery") {
            root.controlsModel.requestedTab = tab;
            root.controlsModel.visible = true;
            root.networkModel.close();
            root.vpnModel.close();
            root.calendarModel.close();
            root.aiModel.close();
            root.setActiveTab(tab);
            if (tab === "bluetooth") {
                root.bluetoothModel.refresh(false);
                root.controlsModel.refreshBluetoothStatus();
            } else if (tab === "audio") {
                root.controlsModel.refreshAudioStatus();
                root.controlsModel.refreshOutputDevices();
                root.controlsModel.refreshInputDevices();
                root.controlsModel.refreshMediaStatus();
            } else if (tab === "brightness") {
                root.controlsModel.refreshBrightnessStatus();
            } else if (tab === "battery") {
                root.controlsModel.refresh();
            }
        } else if (tab === "vpn") {
            root.vpnModel.visible = true;
            root.networkModel.close();
            root.controlsModel.close();
            root.calendarModel.close();
            root.aiModel.close();
            root.setActiveTab("vpn");
            root.vpnModel.refreshProfiles();
            root.vpnModel.refresh();
        } else if (tab === "calendar") {
            root.calendarModel.visible = true;
            root.networkModel.close();
            root.controlsModel.close();
            root.vpnModel.close();
            root.aiModel.close();
            root.setActiveTab("calendar");
            if (root.calendarModel.events.length === 0) {
                root.calendarModel.refreshEvents();
            }
        } else if (tab === "ai") {
            root.aiModel.visible = true;
            root.networkModel.close();
            root.controlsModel.close();
            root.vpnModel.close();
            root.calendarModel.close();
            root.setActiveTab("ai");
            root.aiModel.refresh();
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
        } else if (root.aiModel.visible) {
            root.setActiveTab("ai");
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
            return 3 + root.controlsModel.outputDevices.length + root.controlsModel.inputDevices.length + 3;
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

        if (root.activeTab === "ai") {
            root.aiModel.refresh();
            return;
        }

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
            const micIndex = inputStart;
            const inputDeviceStart = micIndex + 1;
            const mediaStart = inputDeviceStart + root.controlsModel.inputDevices.length;
            if (root.selectedIndex === 0) {
                audioMediaView.focusVolumeInput();
            } else if (root.selectedIndex === 1) {
                root.controlsModel.volumeToggleMute();
            } else if (root.selectedIndex >= outputStart && root.selectedIndex < inputStart) {
                root.controlsModel.outputSetDefault(root.controlsModel.outputDevices[root.selectedIndex - outputStart].name);
            } else if (root.selectedIndex === micIndex) {
                root.controlsModel.micToggleMute();
            } else if (root.selectedIndex >= inputDeviceStart && root.selectedIndex < mediaStart) {
                root.controlsModel.inputSetDefault(root.controlsModel.inputDevices[root.selectedIndex - inputDeviceStart].name);
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
        if (root.activeTab === "ai") {
            root.aiModel.cyclePlatform(delta);
        } else if (root.activeTab === "brightness") {
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
                root.aiModel.close();
                event.accepted = true;
                return;
            }

            if (wifiPasswordInput.activeFocus || vpnTargetInput.activeFocus || (typeof audioMediaView !== "undefined" && audioMediaView.volumeInputActiveFocus) || brightnessPercentInput.activeFocus) {
                return;
            }

            if (event.key === Qt.Key_Tab) {
                root.cycleTab((event.modifiers & Qt.ShiftModifier) ? -1 : 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_R && root.activeTab === "ai") {
                root.aiModel.refresh();
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
                    color: root.activeTab === "wifi" ? Theme.buttonSelectedBackground : (wifiTabMouse.containsMouse ? Theme.buttonHoverBackground : Theme.buttonBackground)
                    radius: Theme.radius

                    UiText {
                        anchors.centerIn: parent
                        text: "\uf1eb"
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 18
                        color: root.activeTab === "wifi" ? Theme.accentText : Theme.textStrong
                    }

                    MouseArea {
                        id: wifiTabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activateTab("wifi")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.activeTab === "bluetooth" ? Theme.buttonSelectedBackground : (bluetoothTabMouse.containsMouse ? Theme.buttonHoverBackground : Theme.buttonBackground)
                    radius: Theme.radius

                    UiText {
                        anchors.centerIn: parent
                        text: "\uf293"
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 18
                        color: root.activeTab === "bluetooth" ? Theme.accentText : Theme.textStrong
                    }

                    MouseArea {
                        id: bluetoothTabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activateTab("bluetooth")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.activeTab === "audio" ? Theme.buttonSelectedBackground : (audioTabMouse.containsMouse ? Theme.buttonHoverBackground : Theme.buttonBackground)
                    radius: Theme.radius

                    UiText {
                        anchors.centerIn: parent
                        text: "\uf028"
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 18
                        color: root.activeTab === "audio" ? Theme.accentText : Theme.textStrong
                    }

                    MouseArea {
                        id: audioTabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activateTab("audio")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.activeTab === "brightness" ? Theme.buttonSelectedBackground : (brightnessTabMouse.containsMouse ? Theme.buttonHoverBackground : Theme.buttonBackground)
                    radius: Theme.radius

                    UiText {
                        anchors.centerIn: parent
                        text: "\uf26c"
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 18
                        color: root.activeTab === "brightness" ? Theme.accentText : Theme.textStrong
                    }

                    MouseArea {
                        id: brightnessTabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activateTab("brightness")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.activeTab === "battery" ? Theme.buttonSelectedBackground : (batteryTabMouse.containsMouse ? Theme.buttonHoverBackground : Theme.buttonBackground)
                    radius: Theme.radius

                    UiText {
                        anchors.centerIn: parent
                        text: "\uf240"
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 18
                        color: root.activeTab === "battery" ? Theme.accentText : Theme.textStrong
                    }

                    MouseArea {
                        id: batteryTabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activateTab("battery")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.activeTab === "vpn" ? Theme.buttonSelectedBackground : (vpnTabMouse.containsMouse ? Theme.buttonHoverBackground : Theme.buttonBackground)
                    radius: Theme.radius

                    UiText {
                        anchors.centerIn: parent
                        text: ""
                        font.family: root.vpnFontFamily
                        font.pixelSize: 18
                        color: root.activeTab === "vpn" ? Theme.accentText : Theme.textStrong
                    }

                    MouseArea {
                        id: vpnTabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activateTab("vpn")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.activeTab === "calendar" ? Theme.buttonSelectedBackground : (calendarTabMouse.containsMouse ? Theme.buttonHoverBackground : Theme.buttonBackground)
                    radius: Theme.radius

                    UiText {
                        anchors.centerIn: parent
                        text: "\uf073"
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 18
                        color: root.activeTab === "calendar" ? Theme.accentText : Theme.textStrong
                    }

                    MouseArea {
                        id: calendarTabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activateTab("calendar")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.activeTab === "ai" ? Theme.buttonSelectedBackground : (aiTabMouse.containsMouse ? Theme.buttonHoverBackground : Theme.buttonBackground)
                    radius: Theme.radius

                    Image {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: root.activeTab === "ai"
                            ? "file:///usr/share/icons/MacTahoe/apps/scalable/agent-dark.png"
                            : "file:///usr/share/icons/MacTahoe/apps/scalable/agent-light.png"
                        sourceSize.width: 32
                        sourceSize.height: 32
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    MouseArea {
                        id: aiTabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activateTab("ai")
                    }
                }

                Rectangle {
                    Layout.preferredWidth: Theme.buttonHeight + 10
                    Layout.preferredHeight: Theme.buttonHeight + 10
                    color: closeMouse.containsMouse ? Theme.buttonHoverBackground : Theme.buttonBackground
                    radius: Theme.radius

                    UiText {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        font.family: Theme.iconFontFamily
                        color: closeMouse.containsMouse ? Theme.accent : Theme.textMuted
                        font.pixelSize: 18
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
                            root.aiModel.close();
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
                    spacing: 14

                    Text {
                        text: "\uf1eb"
                        color: Theme.accent
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 28
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: "Wi-Fi Network"
                            color: Theme.textStrong
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.titleFontSize
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.networkModel.statusText.replace("\uf1eb", "").trim().toUpperCase()
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.tinyFontSize
                            font.bold: true
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: Theme.buttonHeight
                        color: qrMouse.containsMouse ? Theme.buttonHoverBackground : Theme.buttonBackground
                        border.color: qrMouse.containsMouse ? Theme.accent : Theme.border
                        border.width: 1
                        radius: Theme.radius
                        visible: !root.networkModel.sharingWifi

                        Text {
                            anchors.centerIn: parent
                            text: "\udb81\udc33"
                            color: qrMouse.containsMouse ? Theme.accent : Theme.textStrong
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 18
                        }

                        MouseArea {
                            id: qrMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.networkModel.shareActiveWifi()
                        }
                    }

                    ShellButton {
                        Layout.preferredWidth: implicitWidth
                        Layout.preferredHeight: Theme.buttonHeight
                        label: root.networkModel.scanning ? "Scanning..." : "Scan"
                        enabled: !root.networkModel.busy && !root.networkModel.scanning
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

                // OMARCHY-STYLE WI-FI QR SHARE MODAL / CARD
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 460
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                    visible: root.networkModel.sharingWifi
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1
                    radius: Theme.radius * 1.5

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 40
                        spacing: 20

                        RowLayout {
                            Layout.fillWidth: true

                            Item {
                                Layout.preferredWidth: 28
                            }

                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: "Share " + root.networkModel.shareSsid
                                color: Theme.textStrong
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.titleFontSize
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                color: closeShareMouse.containsMouse ? Theme.buttonHoverBackground : Theme.buttonBackground
                                radius: 14

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf00d"
                                    color: closeShareMouse.containsMouse ? Theme.accent : Theme.textMuted
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: 16
                                }

                                MouseArea {
                                    id: closeShareMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.networkModel.closeShare()
                                }
                            }
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 280
                            Layout.preferredHeight: 280
                            color: "#ffffff"
                            radius: 12
                            border.color: "#e0e0e0"
                            border.width: 1

                            Image {
                                anchors.centerIn: parent
                                width: 256
                                height: 256
                                source: root.networkModel.shareQrPath
                                sourceSize.width: 256
                                sourceSize.height: 256
                                fillMode: Image.PreserveAspectFit
                                smooth: false
                                cache: false
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: "Scan to join this network"
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.panelFontSize
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: passText.implicitWidth + 24
                            Layout.preferredHeight: Theme.chipHeight
                            color: passMouse.containsMouse ? Theme.buttonHoverBackground : Theme.buttonBackground
                            border.color: passMouse.containsMouse || root.networkModel.showSharePassword ? Theme.border : "transparent"
                            border.width: 1
                            radius: Theme.radius

                            Text {
                                id: passText
                                anchors.centerIn: parent
                                text: root.networkModel.showSharePassword ? ("Password: " + (root.networkModel.sharePassword || "None") + "  \uf0c5") : "Show password"
                                color: root.networkModel.showSharePassword ? Theme.accent : Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.smallFontSize
                                font.bold: true
                            }

                            MouseArea {
                                id: passMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!root.networkModel.showSharePassword) {
                                        root.networkModel.showSharePassword = true;
                                    } else if (root.networkModel.sharePassword && root.networkModel.sharePassword.length > 0) {
                                        root.networkModel.copyToClipboard(root.networkModel.sharePassword);
                                        root.networkModel.message = "Wi-Fi password copied to clipboard!";
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: !root.networkModel.sharingWifi
                    spacing: Theme.popupSpacing

                    SectionLabel {
                        label: "\uf1eb  Active Connection"
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
                        label: "\uf0c1  Hotspot"
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
                                            text: hotspotPasswordInput.showPassword ? "\uf070" : "\uf06e"
                                            color: eyeMouse.containsMouse ? Theme.accent : Theme.textMuted
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: 14
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

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        SectionLabel {
                            label: "\uf0e4  Speed Test"
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        ShellButton {
                            Layout.preferredWidth: implicitWidth
                            Layout.preferredHeight: Theme.buttonHeight
                            label: root.networkModel.testingSpeed ? "Testing..." : "Run Test"
                            enabled: !root.networkModel.testingSpeed
                            onActivated: root.networkModel.runSpeedTest()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 58
                        color: Theme.surface
                        radius: Theme.radius
                        border.color: Theme.border
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            spacing: 0

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.fillHeight: true

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 6
                                        Text {
                                            text: "\uf017"
                                            color: Theme.accent
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: 13
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                        Text {
                                            text: "Ping"
                                            color: Theme.textMuted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.smallFontSize
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        horizontalAlignment: Text.AlignHCenter
                                        text: root.networkModel.speedPing
                                        color: Theme.textStrong
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.bodyFontSize
                                        font.bold: true
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: 36
                                Layout.alignment: Qt.AlignVCenter
                                color: Theme.border
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.fillHeight: true

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 6
                                        Text {
                                            text: "\uf019"
                                            color: Theme.accent
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: 13
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                        Text {
                                            text: "Download"
                                            color: Theme.textMuted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.smallFontSize
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        horizontalAlignment: Text.AlignHCenter
                                        text: root.networkModel.speedDownload
                                        color: Theme.textStrong
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.bodyFontSize
                                        font.bold: true
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: 36
                                Layout.alignment: Qt.AlignVCenter
                                color: Theme.border
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.fillHeight: true

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 6
                                        Text {
                                            text: "\uf093"
                                            color: Theme.accent
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: 13
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                        Text {
                                            text: "Upload"
                                            color: Theme.textMuted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.smallFontSize
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        horizontalAlignment: Text.AlignHCenter
                                        text: root.networkModel.speedUpload
                                        color: Theme.textStrong
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.bodyFontSize
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        SectionLabel {
                            label: "\uf1eb  Wi-Fi"
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            Layout.preferredWidth: availText.implicitWidth + 20
                            Layout.preferredHeight: Theme.chipHeight
                            color: !root.showSavedWifi ? Theme.buttonSelectedBackground : (availMouse.containsMouse ? Theme.buttonHoverBackground : Theme.buttonBackground)
                            radius: Theme.radius

                            Text {
                                id: availText
                                anchors.centerIn: parent
                                text: "Available"
                                color: !root.showSavedWifi ? Theme.accentText : Theme.textStrong
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.smallFontSize
                                font.bold: !root.showSavedWifi
                            }

                            MouseArea {
                                id: availMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showSavedWifi = false
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: savedText.implicitWidth + 20
                            Layout.preferredHeight: Theme.chipHeight
                            color: root.showSavedWifi ? Theme.buttonSelectedBackground : (savedMouse.containsMouse ? Theme.buttonHoverBackground : Theme.buttonBackground)
                            radius: Theme.radius

                            Text {
                                id: savedText
                                anchors.centerIn: parent
                                text: "Saved (" + root.networkModel.savedNetworks.length + ")"
                                color: root.showSavedWifi ? Theme.accentText : Theme.textStrong
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.smallFontSize
                                font.bold: root.showSavedWifi
                            }

                            MouseArea {
                                id: savedMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showSavedWifi = true
                            }
                        }
                    }

                    ListView {
                        ScrollBar.vertical: ScrollBar {}
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: !root.showSavedWifi
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
                        visible: !root.showSavedWifi && root.networkModel.wifiNetworks.length === 0
                        text: root.networkModel.scanning ? "Scanning for available Wi-Fi networks..." : "No Wi-Fi networks scanned — click 'Scan' to search"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.smallFontSize
                    }

                    ListView {
                        ScrollBar.vertical: ScrollBar {}
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.showSavedWifi
                        clip: true
                        spacing: Theme.listSpacing
                        model: root.networkModel.savedNetworks

                        delegate: NetworkSavedRow {
                            required property var modelData
                            width: ListView.view.width
                            profile: modelData
                            busy: root.networkModel.busy
                            onConnectRequested: uuid => root.networkModel.connectSavedNetwork(uuid)
                            onDisconnectRequested: device => root.networkModel.disconnectDevice(device)
                            onForgetRequested: uuid => root.networkModel.forgetSavedNetwork(uuid)
                            onToggleAutoconnectRequested: (uuid, enable) => root.networkModel.toggleAutoconnect(uuid, enable)
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.showSavedWifi && root.networkModel.savedNetworks.length === 0
                        text: "No saved Wi-Fi networks found"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.smallFontSize
                    }

                    Rectangle {
                        readonly property var currentSelectedNetwork: root.networkModel.selectedWifiNetwork()
                        Layout.fillWidth: true
                        Layout.preferredHeight: (!root.showSavedWifi && currentSelectedNetwork !== null && currentSelectedNetwork.secured && !currentSelectedNetwork.saved && !currentSelectedNetwork.active) ? 44 : 0
                        visible: !root.showSavedWifi && currentSelectedNetwork !== null && currentSelectedNetwork.secured && !currentSelectedNetwork.saved && !currentSelectedNetwork.active
                        color: Theme.surface
                        border.color: root.activeTab === "wifi" && root.selectedIndex === root.wifiPasswordIndex() ? Theme.accent : Theme.border
                        border.width: 1
                        radius: Theme.radius

                        transform: Translate {
                            id: passwordTranslate
                            x: 0
                        }

                        SequentialAnimation {
                            id: passwordShakeAnimation
                            NumberAnimation {
                                target: passwordTranslate
                                property: "x"
                                to: -14
                                duration: 40
                            }
                            NumberAnimation {
                                target: passwordTranslate
                                property: "x"
                                to: 14
                                duration: 40
                            }
                            NumberAnimation {
                                target: passwordTranslate
                                property: "x"
                                to: -10
                                duration: 40
                            }
                            NumberAnimation {
                                target: passwordTranslate
                                property: "x"
                                to: 10
                                duration: 40
                            }
                            NumberAnimation {
                                target: passwordTranslate
                                property: "x"
                                to: -5
                                duration: 40
                            }
                            NumberAnimation {
                                target: passwordTranslate
                                property: "x"
                                to: 0
                                duration: 40
                            }
                        }

                        Connections {
                            target: root.networkModel
                            function onPasswordFailed(attempt) {
                                passwordShakeAnimation.start();
                                Qt.callLater(() => wifiPasswordInput.forceActiveFocus());
                            }
                        }

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
                                        text: wifiPasswordInput.showPassword ? "\uf070" : "\uf06e"
                                        color: wifiEyeMouse.containsMouse ? Theme.accent : Theme.textMuted
                                        font.family: Theme.iconFontFamily
                                        font.pixelSize: 14
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
            }

            // BLUETOOTH CONTENT
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.activeTab === "bluetooth"
                spacing: Theme.popupSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Text {
                        text: "\uf293"
                        color: root.bluetoothModel.statusText.indexOf("off") === -1 && root.bluetoothModel.statusText.indexOf("unavailable") === -1 ? Theme.accent : Theme.textMuted
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 28
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: "Bluetooth"
                            color: Theme.textStrong
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.titleFontSize
                            font.bold: true
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.bluetoothModel.statusText.indexOf("on") !== -1 ? "POWERED ON" : (root.bluetoothModel.statusText.indexOf("off") !== -1 ? "POWERED OFF" : root.bluetoothModel.statusText.toUpperCase())
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.tinyFontSize
                            font.bold: true
                        }
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

                SectionLabel {
                    label: "\uf293  Paired & Available Devices"
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
                        color: modelData.connected ? Theme.buttonSelectedBackground : (selected ? Theme.buttonFocusBackground : (deviceMouse.containsMouse ? Theme.buttonHoverBackground : Theme.buttonBackground))
                        border.color: selected ? Theme.accent : Theme.border
                        border.width: selected ? 1 : 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.rowSpacing
                            anchors.rightMargin: Theme.rowSpacing
                            spacing: Theme.rowSpacing

                            Text {
                                text: "\uf293"
                                color: modelData.connected ? Theme.accentText : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 18
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
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
                    spacing: 14

                    Text {
                        text: ""
                        color: root.vpnModel.connected ? Theme.success : Theme.accent
                        font.family: root.vpnFontFamily
                        font.pixelSize: 28
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: "VPN Network"
                            color: Theme.textStrong
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.titleFontSize
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: (root.vpnModel.connected ? (root.vpnModel.activeProfile.length > 0 ? "CONNECTED: " + root.vpnModel.activeProfile : "CONNECTED") : "DISCONNECTED").toUpperCase()
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.tinyFontSize
                            font.bold: true
                            elide: Text.ElideRight
                        }
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
                    label: "\uf132  Target IP"
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
                        label: "\uf132  Profiles"
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
                        color: profileActive ? Theme.buttonSelectedBackground : (selected ? Theme.buttonFocusBackground : (vpnMouse.containsMouse && rowInteractive ? Theme.buttonHoverBackground : Theme.buttonBackground))
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
                                    sourceSize.width: 30
                                    sourceSize.height: 30
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
                Layout.fillHeight: true
                visible: root.activeTab === "brightness"
                spacing: root.contentSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Text {
                        text: "\uf26c"
                        color: Theme.accent
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 28
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Display"
                            color: Theme.textStrong
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.titleFontSize
                            font.bold: true
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.border
                    opacity: 0.5
                }

                RowLayout {
                    Layout.fillWidth: true
                    SectionLabel {
                        label: "\uf185  Brightness"
                    }
                    TextInput {
                        id: brightnessPercentInput
                        text: root.controlsModel.brightnessPercent + "%"
                        color: Theme.textStrong
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.panelFontSize
                        font.bold: true
                        horizontalAlignment: TextInput.AlignRight
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
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    SectionLabel {
                        label: "\uf031  Text Size"
                    }
                    Text {
                        text: root.controlsModel.textSize.toString() + "px"
                        color: Theme.textStrong
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.panelFontSize
                        font.bold: true
                    }
                }

                Item {
                    id: textSizeSlider
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32

                    property int minSize: 9
                    property int maxSize: 14
                    property int currentSize: root.controlsModel.textSize

                    function sizeFromX(xPos) {
                        let ratio = Math.max(0, Math.min(1, xPos / Math.max(1, width)));
                        return Math.round(minSize + ratio * (maxSize - minSize));
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 8
                        color: Theme.surface
                        radius: Theme.radius

                        Rectangle {
                            width: Math.round(((textSizeSlider.currentSize - textSizeSlider.minSize) / (textSizeSlider.maxSize - textSizeSlider.minSize)) * parent.width)
                            height: parent.height
                            color: Theme.accent
                            radius: parent.radius
                        }
                    }

                    Rectangle {
                        width: 20
                        height: 20
                        x: Math.max(0, Math.min(parent.width - width, Math.round(((textSizeSlider.currentSize - textSizeSlider.minSize) / (textSizeSlider.maxSize - textSizeSlider.minSize)) * parent.width) - width / 2))
                        y: parent.height / 2 - height / 2
                        color: Theme.text
                        border.color: Theme.border
                        border.width: 1
                        radius: height / 2
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: function (mouse) {
                            root.controlsModel.setTextSize(textSizeSlider.sizeFromX(mouse.x));
                        }
                        onPositionChanged: function (mouse) {
                            if (pressed) {
                                root.controlsModel.setTextSize(textSizeSlider.sizeFromX(mouse.x));
                            }
                        }
                        onReleased: function (mouse) {
                            root.controlsModel.setTextSize(textSizeSlider.sizeFromX(mouse.x));
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    SectionLabel {
                        label: "\uf065  Display Scale"
                    }
                    Text {
                        text: root.controlsModel.focusedDisplay
                        color: Theme.textStrong
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.smallFontSize
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: ["1x", "1.25x", "1.6x", "2x", "3x", "4x"]
                        delegate: Rectangle {
                            required property string modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 34
                            color: root.controlsModel.displayScale === modelData
                                ? Theme.buttonSelectedBackground
                                : (scaleMouse.containsMouse ? Theme.buttonHoverBackground : Theme.buttonBackground)
                            border.color: Theme.border
                            border.width: 1
                            radius: Theme.radius

                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData
                                color: root.controlsModel.displayScale === parent.modelData ? Theme.accentText : Theme.textStrong
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.panelFontSize
                                font.bold: true
                            }

                            MouseArea {
                                id: scaleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.controlsModel.setDisplayScale(parent.modelData)
                            }
                        }
                    }
                }

                SectionLabel {
                    label: "\uf26c  Active Displays"
                }

                Repeater {
                    model: root.controlsModel.displayList
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        color: displayMouse.containsMouse ? Theme.buttonHoverBackground : Theme.buttonBackground
                        border.color: Theme.border
                        border.width: 1
                        radius: Theme.radius

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            Text {
                                text: "\uf108"
                                color: modelData.focused ? Theme.accent : Theme.textMuted
                                font.family: Theme.iconFontFamily
                                font.pixelSize: 16
                            }

                            Text {
                                text: modelData.name + (modelData.focused ? " \u00b7 focused" : "")
                                color: Theme.textStrong
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.bodyFontSize
                                font.bold: modelData.focused
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "\uf00c"
                                visible: modelData.focused
                                color: Theme.accent
                                font.family: Theme.iconFontFamily
                                font.pixelSize: 14
                            }
                        }

                        MouseArea {
                            id: displayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.controlsModel.focusedDisplay = modelData.name;
                            }
                        }
                    }
                }

                SectionLabel {
                    label: "\uf108  Workspaces"
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
                            Layout.preferredHeight: Math.max(42, (Math.ceil(modelData.windows.length / 4) * 32) + 12)
                            color: modelData.focused ? Theme.buttonFocusBackground : ((workspaceMouse.containsMouse || workspaceDrop.containsDrag) ? Theme.buttonHoverBackground : Theme.buttonBackground)
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
                                anchors.margins: 6

                                Item {
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: iconGrid.implicitHeight

                                    GridLayout {
                                        id: iconGrid

                                        anchors.centerIn: parent
                                        width: Math.min(parent.width, Math.max(0, Math.min(4, modelData.windows.length) * 26 + Math.max(0, Math.min(4, modelData.windows.length) - 1) * 6))
                                        height: implicitHeight
                                        columns: 4
                                        columnSpacing: 6
                                        rowSpacing: 6

                                        Repeater {
                                            model: modelData.windows

                                            delegate: Item {
                                                id: iconSlot

                                                required property var modelData

                                                Layout.preferredWidth: 26
                                                Layout.preferredHeight: 26
                                                Layout.minimumWidth: 26
                                                Layout.minimumHeight: 26
                                                Layout.maximumWidth: 26
                                                Layout.maximumHeight: 26

                                                property bool dragStarted: false
                                                property bool dragging: dragStarted

                                                Image {
                                                    anchors.fill: parent
                                                    source: root.workspaceAppIconSource(iconSlot.modelData.iconKey)
                                                    sourceSize.width: 26
                                                    sourceSize.height: 26
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
                                                        sourceSize.width: 26
                                                        sourceSize.height: 26
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

                Item {
                    Layout.fillHeight: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.activeTab === "battery"
                spacing: root.contentSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Text {
                        text: "\uf240"
                        color: root.controlsModel.batteryCharging ? Theme.success : Theme.accent
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 28
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Battery"
                            color: Theme.textStrong
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.titleFontSize
                            font.bold: true
                        }
                        Text {
                            text: root.controlsModel.batteryStatusText
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.tinyFontSize
                            font.bold: true
                        }
                    }

                    Text {
                        text: root.controlsModel.batteryPercent.toString() + "%"
                        color: Theme.textStrong
                        font.family: Theme.fontFamily
                        font.pixelSize: 26
                        font.bold: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.border
                    opacity: 0.5
                }

                SectionLabel {
                    label: "\uf240  Charge Level"
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.surface
                        border.color: Theme.border
                        border.width: 1
                        radius: 12

                        Rectangle {
                            width: Math.max(height, Math.round((root.controlsModel.batteryPercent / 100) * parent.width))
                            height: parent.height
                            color: root.controlsModel.batteryCharging ? Theme.success : (root.controlsModel.batteryPercent <= 20 ? Theme.danger : Theme.accent)
                            radius: 12
                        }
                    }
                }

                SectionLabel {
                    label: "\uf080  Battery Statistics"
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: Theme.rowSpacing
                    rowSpacing: Theme.rowSpacing

                    Repeater {
                        model: [
                            {
                                "label": "Capacity",
                                "icon": "\uf242",
                                "value": root.controlsModel.batterySize
                            },
                            {
                                "label": root.controlsModel.batteryCharging ? "Time to Full" : "Remaining Time",
                                "icon": "\uf017",
                                "value": root.controlsModel.batteryTime
                            },
                            {
                                "label": "Charge Cycles",
                                "icon": "\uf021",
                                "value": root.controlsModel.batteryCycles
                            },
                            {
                                "label": root.controlsModel.batteryCharging ? "Charge Rate" : "Power Draw",
                                "icon": "\uf0e4",
                                "value": root.controlsModel.batteryRate
                            }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 52
                            color: Theme.surface
                            border.color: Theme.border
                            border.width: 1
                            radius: Theme.radius

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Text {
                                    text: modelData.icon
                                    color: Theme.accent
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: 18
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.label
                                        color: Theme.textMuted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.tinyFontSize
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.value
                                        color: Theme.textStrong
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.panelFontSize
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }

                SectionLabel {
                    label: "\uf0e4  Power Profile"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: [
                            {
                                "id": "Power-saver",
                                "icon": "\uf06c",
                                "label": "Power-saver"
                            },
                            {
                                "id": "Balanced",
                                "icon": "\uf248",
                                "label": "Balanced"
                            },
                            {
                                "id": "Performance",
                                "icon": "\uf135",
                                "label": "Performance"
                            }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 46
                            color: root.controlsModel.powerProfile === modelData.id ? Theme.buttonSelectedBackground : (profileMouse.containsMouse ? Theme.buttonHoverBackground : Theme.buttonBackground)
                            border.color: Theme.border
                            border.width: 1
                            radius: Theme.radius

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: modelData.icon
                                    color: root.controlsModel.powerProfile === modelData.id ? Theme.accentText : Theme.textStrong
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: 15
                                }
                                Text {
                                    text: modelData.label
                                    color: root.controlsModel.powerProfile === modelData.id ? Theme.accentText : Theme.textStrong
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.bodyFontSize
                                    font.bold: true
                                }
                            }

                            MouseArea {
                                id: profileMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.controlsModel.setPowerProfile(modelData.id)
                            }
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }

            AudioMediaView {
                id: audioMediaView
                visible: root.activeTab === "audio"
                Layout.fillWidth: true
                Layout.fillHeight: true
                controlsModel: root.controlsModel
                activeTab: root.activeTab
                selectedIndex: root.selectedIndex
                volumeControlHeight: root.volumeControlHeight
                rowSpacing: root.rowSpacing
                volumePercentWidth: root.volumePercentWidth
                outputDeviceListMaxHeight: root.outputDeviceListMaxHeight
                deviceListReservedHeight: root.deviceListReservedHeight
                outputDeviceRowHeight: root.outputDeviceRowHeight
                inputDeviceListMaxHeight: root.inputDeviceListMaxHeight
                mediaThumbnailHeight: root.mediaThumbnailHeight
                onRequestParentFocus: content.forceActiveFocus()
            }

            CalendarView {
                visible: root.activeTab === "calendar"
                Layout.fillWidth: true
                Layout.fillHeight: true
                calendarModel: root.calendarModel
            }

            Loader {
                active: root.activeTab === "ai"
                visible: root.activeTab === "ai"
                Layout.fillWidth: true
                Layout.fillHeight: true

                sourceComponent: Component {
                    AiUsageView {
                        aiModel: root.aiModel
                    }
                }
            }
        }
    }
}
