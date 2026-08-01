import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.core

Scope {
    id: root

    property bool visible: false
    property bool busy: false
    property string requestedTab: "audio"
    property string volumeText: "\uf026  unavailable"
    property int volumePercent: 0
    property bool volumeMuted: false
    property string volumeDisplayText: volumeText + (outputDeviceDescription.length > 0 ? " - " + outputDeviceDescription : "")

    property int brightnessPercent: 0
    property bool brightnessReady: false
    property int targetVolume: -1
    property int targetBrightness: -1
    property int batteryPercent: 0
    property bool batteryCharging: false

    property string focusedDisplay: "eDP"
    property var displayList: []
    property string displayScale: "1x"
    property int textSize: 11

    property string batterySize: "40Wh"
    property string batteryCycles: "0"
    property string batteryTime: "22m"
    property string batteryRate: "0.0W"
    property string batteryStatusText: "PUMPING POWER"
    property string powerProfile: "Balanced"

    property var outputDevices: []
    property string outputDeviceName: ""
    property string outputDeviceDescription: ""
    property var inputDevices: []
    property string inputDeviceName: ""
    property string micText: "\uf131  unavailable"
    property int micPercent: 0
    property string mediaText: "MEDIA none"
    property string mediaPlayer: ""
    property string mediaState: ""
    property string mediaArtUrl: ""
    property double mediaLengthUs: 0
    property double mediaPositionUs: 0
    property real mediaProgress: mediaLengthUs > 0 ? Math.max(0, Math.min(1, mediaPositionUs / mediaLengthUs)) : 0
    property string bluetoothText: "BT unavailable"
    property string pendingAction: ""
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property var audioSource: Pipewire.defaultAudioSource
    readonly property string backlightPath: "/sys/class/backlight/amdgpu_bl0"
    readonly property string batteryPath: "/sys/class/power_supply/BAT1"

    Timer {
        id: volumeTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (root.targetVolume >= 0) {
                root.commitVolumeSet();
            }
        }
    }

    Timer {
        id: brightnessTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (root.targetBrightness >= 0) {
                root.commitBrightnessSet();
            }
        }
    }

    function refreshAudioStatus() {
        const sink = root.audioSink;

        if (sink !== null && sink.ready && sink.audio !== null) {
            root.volumePercent = root.clampPercent(sink.audio.volume * 100);
            root.volumeMuted = sink.audio.muted;
            root.volumeText = (root.volumeMuted ? "\uf026  Muted " : "\uf028  ") + root.volumePercent.toString() + "%";
            root.outputDeviceName = sink.name;
            root.outputDeviceDescription = sink.description.length > 0 ? sink.description : sink.name;
        } else {
            root.volumeText = "\uf026  unavailable";
            root.volumeMuted = false;
            root.outputDeviceName = "";
            root.outputDeviceDescription = "";
            if (!volumeStatusProcess.running) {
                volumeStatusProcess.running = true;
            }
        }

        const source = root.audioSource;
        if (source !== null && source.ready && source.audio !== null) {
            root.micPercent = root.clampPercent(source.audio.volume * 100);
            root.micText = source.audio.muted ? "\uf131  Muted" : "\uf130  On";
        } else {
            root.micText = "\uf131  unavailable";
            if (!micStatusProcess.running) {
                micStatusProcess.running = true;
            }
        }
    }

    function open() {
        root.visible = true;
        root.refresh();
    }

    function close() {
        root.visible = false;
    }

    function toggle() {
        if (root.visible) {
            root.close();
        } else {
            root.open();
        }
    }

    function refresh() {
        root.refreshAudioStatus();
        root.refreshOutputDevices();
        root.refreshInputDevices();
        root.refreshMediaStatus();
        root.refreshBluetoothStatus();
        root.refreshBrightnessStatus();
        root.syncBatteryStatus();
        if (!batteryDetailsProcess.running)
            batteryDetailsProcess.running = true;
        if (!displayListProcess.running)
            displayListProcess.running = true;
    }

    function refreshOutputDevices() {
        if (!root.visible) {
            return;
        }
        if (!outputDevicesProcess.running) {
            outputDevicesProcess.running = true;
        }
    }

    function refreshInputDevices() {
        if (!root.visible) {
            return;
        }
        if (!inputDevicesProcess.running) {
            inputDevicesProcess.running = true;
        }
    }

    function refreshMediaStatus() {
        if (!mediaStatusProcess.running) {
            mediaStatusProcess.running = true;
        }
    }

    Timer {
        id: mediaWatchRestartTimer

        interval: 2000
        repeat: false
        onTriggered: mediaWatchProcess.running = true
    }

    function refreshBluetoothStatus() {
        if (!root.visible) {
            return;
        }
        if (!bluetoothStatusProcess.running) {
            bluetoothStatusProcess.running = true;
        }
    }

    function refreshBrightnessStatus() {
        brightnessMaxFile.reload();
        brightnessValueFile.reload();
        Qt.callLater(root.syncBrightnessStatus);
    }

    function syncBrightnessStatus() {
        const current = Number(brightnessValueFile.text().trim());
        const maximum = Number(brightnessMaxFile.text().trim());
        if (isFinite(current) && isFinite(maximum) && maximum > 0) {
            root.brightnessPercent = root.clampPercent((current / maximum) * 100);
            root.brightnessReady = true;
        } else if (!brightnessStatusProcess.running) {
            brightnessStatusProcess.running = true;
        }
    }

    function syncBatteryStatus() {
        const capacity = Number(batteryCapacityFile.text().trim());
        const status = batteryStatusFile.text().trim();
        if (!isFinite(capacity) || status.length === 0) {
            root.batteryPercent = 0;
            root.batteryCharging = false;
            return;
        }

        root.batteryPercent = root.clampPercent(capacity);
        root.batteryCharging = status !== "Discharging" && status !== "Unknown";
    }

    function parseMedia(text) {
        const trimmed = text.trim();

        if (trimmed.length === 0 || trimmed.indexOf("MEDIA ") === 0) {
            root.mediaText = trimmed.length > 0 ? trimmed : "MEDIA none";
            root.mediaPlayer = "";
            root.mediaState = "";
            root.mediaArtUrl = "";
            root.mediaLengthUs = 0;
            root.mediaPositionUs = 0;
            return;
        }

        const fields = trimmed.split("\t");

        root.mediaPlayer = fields.length > 0 ? fields[0] : "";
        root.mediaState = fields.length > 1 ? fields[1] : "";

        const artist = fields.length > 2 ? fields[2] : "";
        const title = fields.length > 3 ? fields[3] : "";
        root.mediaArtUrl = fields.length > 4 ? fields[4] : "";
        root.mediaLengthUs = fields.length > 5 ? Math.max(0, Number(fields[5])) : 0;
        root.mediaPositionUs = fields.length > 6 ? Math.max(0, Number(fields[6])) : 0;

        const titleParts = [];
        if (artist.length > 0) {
            titleParts.push(artist);
        }
        if (title.length > 0) {
            titleParts.push(title);
        }

        root.mediaText = titleParts.length > 0 ? titleParts.join(" - ") : "MEDIA none";
    }

    function parseBattery(text) {
        const batteryText = text.trim();
        const m = batteryText.match(/BATTERY\s+([0-9]+)%\s+(.+)/);
        if (m) {
            root.batteryPercent = parseInt(m[1], 10);
            root.batteryCharging = (m[2] !== "Discharging" && m[2] !== "unavailable");
        } else {
            root.batteryPercent = 0;
            root.batteryCharging = false;
        }
    }

    function parseBatteryDetails(text) {
        const lines = text.trim().split("\n");
        for (let i = 0; i < lines.length; i++) {
            const parts = lines[i].split("\t");
            if (parts.length < 2)
                continue;
            const key = parts[0];
            const val = parts[1];
            if (key === "size")
                root.batterySize = val;
            else if (key === "cycles")
                root.batteryCycles = val;
            else if (key === "time")
                root.batteryTime = val;
            else if (key === "rate")
                root.batteryRate = val;
            else if (key === "status")
                root.batteryStatusText = val;
            else if (key === "profile")
                root.powerProfile = val;
        }
    }

    function parseDisplayList(text) {
        const lines = text.trim().split("\n");
        let list = [];
        for (let i = 0; i < lines.length; i++) {
            const parts = lines[i].split("\t");
            if (parts.length >= 2) {
                const name = parts[0];
                const focused = (parts.length >= 3 && parts[2] === "1");
                if (focused)
                    root.focusedDisplay = name;
                list.push({
                    "name": name,
                    "focused": focused
                });
            }
        }
        if (list.length === 0) {
            list = [
                {
                    "name": "eDP-1",
                    "focused": true
                }
            ];
            root.focusedDisplay = "eDP-1";
        }
        root.displayList = list;
    }

    function setPowerProfile(profile) {
        root.powerProfile = profile.charAt(0).toUpperCase() + profile.slice(1).toLowerCase();
        if (profile.toLowerCase() === "power-saver" || profile.toLowerCase() === "powersave") {
            root.powerProfile = "Power-saver";
        }
        if (setPowerProfileProcess.running) {
            setPowerProfileProcess.running = false;
        }
        setPowerProfileProcess.command = Commands.controlsHelperCommand("set-power-profile", [profile.toLowerCase()]);
        setPowerProfileProcess.running = true;
    }

    function setDisplayScale(val) {
        root.displayScale = val;
        if (setDisplayScaleProcess.running) {
            setDisplayScaleProcess.running = false;
        }
        setDisplayScaleProcess.command = Commands.controlsHelperCommand("set-display-scale", [root.focusedDisplay, val]);
        setDisplayScaleProcess.running = true;
    }

    function setTextSize(val) {
        root.textSize = val;
        Theme.panelFontSize = val;
    }

    function parseVolume(text) {
        const trimmed = text.trim();

        if (trimmed.length > 0) {
            root.volumeText = trimmed;
        }

        const match = trimmed.match(/([0-9]+)%/);
        if (match !== null) {
            root.volumePercent = root.clampPercent(parseInt(match[1], 10));
        }
        root.volumeMuted = trimmed.indexOf("\uf026  Muted") !== -1 || trimmed.indexOf("Muted") !== -1 || trimmed.indexOf("muted") !== -1;
    }

    function parseBrightness(text) {
        const trimmed = text.trim();

        const match = trimmed.match(/([0-9]+)%/);
        if (match !== null) {
            root.brightnessPercent = root.clampPercent(parseInt(match[1], 10));
            root.brightnessReady = true;
        }
    }

    function parseOutputDevices(text) {
        const devices = [];
        const lines = text.trim().split("\n");
        let defaultName = "";
        let defaultDescription = "";

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();

            if (line.length === 0 || line === "OUTPUT unavailable") {
                continue;
            }

            const fields = line.split("\t");
            const name = fields.length > 0 ? fields[0] : "";

            if (name.length === 0) {
                continue;
            }

            const description = fields.length > 1 && fields[1].length > 0 ? fields[1] : name;
            const isDefault = fields.length > 2 && fields[2] === "1";

            devices.push({
                "name": name,
                "description": description,
                "isDefault": isDefault
            });
            if (isDefault) {
                defaultName = name;
                defaultDescription = description;
            }
        }

        root.outputDevices = devices;
        root.outputDeviceName = defaultName;
        root.outputDeviceDescription = defaultDescription;
    }

    function parseInputDevices(text) {
        const devices = [];
        const lines = text.trim().split("\n");
        let defaultName = "";

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();

            if (line.length === 0 || line === "INPUT unavailable") {
                continue;
            }

            const fields = line.split("\t");
            const name = fields.length > 0 ? fields[0] : "";

            if (name.length === 0) {
                continue;
            }

            const description = fields.length > 1 && fields[1].length > 0 ? fields[1] : name;
            const isDefault = fields.length > 2 && fields[2] === "1";

            devices.push({
                "name": name,
                "description": description,
                "isDefault": isDefault
            });
            if (isDefault) {
                defaultName = name;
            }
        }

        root.inputDevices = devices;
        root.inputDeviceName = defaultName;
    }

    function clampPercent(value) {
        const number = Math.round(Number(value));

        if (isNaN(number)) {
            return root.volumePercent;
        }

        return Math.max(0, Math.min(100, number));
    }

    function runAction(action, args) {
        if (root.busy) {
            return false;
        }

        root.busy = true;
        root.pendingAction = action;
        actionProcess.command = Commands.controlsHelperCommand(action, args || []);
        actionProcess.running = true;
        return true;
    }

    function volumeUp() {
        root.volumeSet((root.targetVolume >= 0 ? root.targetVolume : root.volumePercent) + 1);
    }

    function volumeDown() {
        root.volumeSet((root.targetVolume >= 0 ? root.targetVolume : root.volumePercent) - 1);
    }

    function volumeToggleMute() {
        root.runAction("volume-toggle-mute");
    }

    function micToggleMute() {
        root.runAction("mic-toggle-mute");
    }

    function micSet(percent) {
        const value = root.clampPercent(percent);
        root.micPercent = value;
        root.runAction("mic-set", [value.toString() + "%"]);
    }

    function volumeSet(percent) {
        const value = root.clampPercent(percent);
        root.targetVolume = value;
        root.volumePercent = value;
        root.volumeText = (root.volumeMuted ? "\uf026  Muted " : "\uf028  ") + value.toString() + "%";
        volumeTimer.restart();
    }

    function brightnessSet(percent) {
        const value = root.clampPercent(percent);
        root.targetBrightness = value;
        root.brightnessPercent = value;
        root.brightnessReady = true;
        brightnessTimer.restart();
    }

    function commitVolumeSet() {
        if (root.targetVolume < 0) {
            return;
        }

        if (root.runAction("volume-set", [root.targetVolume.toString() + "%"])) {
            root.targetVolume = -1;
        } else {
            volumeTimer.restart();
        }
    }

    function commitBrightnessSet() {
        if (root.targetBrightness < 0) {
            return;
        }

        if (root.runAction("brightness-set", [root.targetBrightness.toString() + "%"])) {
            root.targetBrightness = -1;
        } else {
            brightnessTimer.restart();
        }
    }

    function brightnessUp() {
        root.brightnessSet((root.targetBrightness >= 0 ? root.targetBrightness : root.brightnessPercent) + 1);
    }

    function brightnessDown() {
        root.brightnessSet((root.targetBrightness >= 0 ? root.targetBrightness : root.brightnessPercent) - 1);
    }

    function outputSetDefault(name) {
        if (name.length === 0 || name === root.outputDeviceName) {
            return;
        }

        root.runAction("output-set-default", [name]);
    }

    function inputSetDefault(name) {
        if (name.length === 0 || name === root.inputDeviceName) {
            return;
        }

        root.runAction("input-set-default", [name]);
    }

    function runMediaAction(action, args) {
        mediaActionProcess.command = Commands.controlsHelperCommand(action, args || []);
        mediaActionProcess.running = true;
    }

    function mediaPlayPause() {
        const player = root.mediaPlayer.length > 0 ? root.mediaPlayer : "";
        root.runMediaAction("media-play-pause", [player]);
    }

    function mediaNext() {
        const player = root.mediaPlayer.length > 0 ? root.mediaPlayer : "";
        root.runMediaAction("media-next", [player]);
    }

    function mediaPrevious() {
        const player = root.mediaPlayer.length > 0 ? root.mediaPlayer : "";
        root.runMediaAction("media-previous", [player]);
    }

    function mediaSeek(progress) {
        const player = root.mediaPlayer.length > 0 ? root.mediaPlayer : "";
        const clamped = Math.max(0, Math.min(1, Number(progress)));
        let positionSeconds = 0;
        if (root.mediaLengthUs > 0) {
            positionSeconds = Math.round((root.mediaLengthUs * clamped) / 1000000);
            root.mediaPositionUs = root.mediaLengthUs * clamped;
        }
        root.runMediaAction("media-seek", [player, positionSeconds.toString()]);
    }

    function mediaSeekBy(seconds) {
        const player = root.mediaPlayer.length > 0 ? root.mediaPlayer : "";
        const secStr = Math.round(Number(seconds)).toString();
        root.runMediaAction("media-seek-by", [player, secStr]);
    }

    PwObjectTracker {
        objects: [root.audioSink, root.audioSource]
    }

    FileView {
        id: brightnessValueFile
        path: root.backlightPath + "/brightness"
        preload: true
        watchChanges: true
        printErrors: false

        onLoaded: root.syncBrightnessStatus()
        onFileChanged: {
            brightnessValueFile.reload();
            Qt.callLater(root.syncBrightnessStatus);
        }
    }

    FileView {
        id: brightnessMaxFile
        path: root.backlightPath + "/max_brightness"
        preload: true
        watchChanges: true
        printErrors: false

        onLoaded: root.syncBrightnessStatus()
        onFileChanged: {
            brightnessMaxFile.reload();
            Qt.callLater(root.syncBrightnessStatus);
        }
    }

    FileView {
        id: batteryCapacityFile
        path: root.batteryPath + "/capacity"
        preload: true
        watchChanges: true
        printErrors: false

        onLoaded: root.syncBatteryStatus()
        onFileChanged: {
            batteryCapacityFile.reload();
            Qt.callLater(root.syncBatteryStatus);
        }
    }

    FileView {
        id: batteryStatusFile
        path: root.batteryPath + "/status"
        preload: true
        watchChanges: true
        printErrors: false

        onLoaded: root.syncBatteryStatus()
        onFileChanged: {
            batteryStatusFile.reload();
            Qt.callLater(root.syncBatteryStatus);
        }
    }

    Connections {
        target: Pipewire

        function onDefaultAudioSinkChanged() {
            root.refreshAudioStatus();
            root.refreshOutputDevices();
        }

        function onDefaultAudioSourceChanged() {
            root.refreshAudioStatus();
            root.refreshInputDevices();
        }

        function onReadyChanged() {
            root.refreshAudioStatus();
        }
    }

    Connections {
        target: Pipewire.nodes

        function onObjectInsertedPost(object, index) {
            if (root.visible) {
                root.refreshOutputDevices();
                root.refreshInputDevices();
            }
        }

        function onObjectRemovedPost(object, index) {
            if (root.visible) {
                root.refreshOutputDevices();
                root.refreshInputDevices();
            }
        }
    }

    Connections {
        target: root.audioSink

        function onReadyChanged() {
            root.refreshAudioStatus();
        }
    }

    Connections {
        target: root.audioSink !== null ? root.audioSink.audio : null

        function onMutedChanged() {
            root.refreshAudioStatus();
        }

        function onVolumesChanged() {
            root.refreshAudioStatus();
        }
    }

    Connections {
        target: root.audioSource

        function onReadyChanged() {
            root.refreshAudioStatus();
        }
    }

    Connections {
        target: root.audioSource !== null ? root.audioSource.audio : null

        function onMutedChanged() {
            root.refreshAudioStatus();
        }
    }

    Process {
        id: volumeStatusProcess

        command: Commands.controlsHelperCommand("volume-status")
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const sink = root.audioSink;
                if (sink === null || !sink.ready || sink.audio === null) {
                    root.parseVolume(this.text.length > 0 ? this.text : "\uf026  unavailable");
                }
            }
        }
    }

    Process {
        id: brightnessStatusProcess

        command: Commands.controlsHelperCommand("brightness-status")
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.parseBrightness(this.text.length > 0 ? this.text : "BRIGHTNESS unavailable");
            }
        }
    }

    Process {
        id: micStatusProcess

        command: Commands.controlsHelperCommand("mic-status")
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const source = root.audioSource;
                if (source === null || !source.ready || source.audio === null) {
                    const text = this.text.trim();
                    root.micText = text.length > 0 ? text : "\uf131  unavailable";
                    const match = text.match(/([0-9]+)%/);
                    if (match !== null) {
                        root.micPercent = root.clampPercent(parseInt(match[1], 10));
                    }
                }
            }
        }
    }

    Process {
        id: outputDevicesProcess

        command: Commands.controlsHelperCommand("output-devices")
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.parseOutputDevices(this.text)
        }
    }

    Process {
        id: inputDevicesProcess

        command: Commands.controlsHelperCommand("input-devices")
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.parseInputDevices(this.text)
        }
    }

    Process {
        id: mediaWatchProcess

        command: Commands.controlsHelperCommand("media-watch")
        running: true

        stdout: SplitParser {
            onRead: root.refreshMediaStatus()
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.length > 0) {
                    console.warn("Media watch error: " + this.text);
                }
            }
        }

        onRunningChanged: {
            if (!running) {
                mediaWatchRestartTimer.restart();
            }
        }
    }

    Process {
        id: mediaStatusProcess

        command: Commands.controlsHelperCommand("media-status")
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.parseMedia(this.text)
        }
    }

    Process {
        id: bluetoothStatusProcess

        command: Commands.controlsHelperCommand("bluetooth-status")
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim();

                root.bluetoothText = text.length > 0 ? text : "BT unavailable";
            }
        }
    }

    Process {
        id: actionProcess

        running: false

        onRunningChanged: {
            if (!running) {
                const action = root.pendingAction;
                root.busy = false;
                root.refreshAudioStatus();
                if (root.visible) {
                    root.refresh();
                } else if (action.indexOf("media-") === 0 && !mediaStatusProcess.running) {
                    mediaStatusProcess.running = true;
                }
                root.pendingAction = "";
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.length > 0)
                    console.warn("Controls action error: " + this.text);
            }
        }
    }

    Process {
        id: mediaActionProcess
        running: false
        onRunningChanged: {
            if (!running) {
                root.refreshMediaStatus();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.length > 0)
                    console.warn("Media action error: " + this.text);
            }
        }
    }

    Timer {
        interval: 500
        running: root.visible
        repeat: true
        onTriggered: root.refreshMediaStatus()
    }

    Process {
        id: batteryDetailsProcess
        command: Commands.controlsHelperCommand("battery-details")
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.parseBatteryDetails(this.text);
            }
        }
    }

    Process {
        id: setPowerProfileProcess
        command: Commands.controlsHelperCommand("set-power-profile", ["balanced"])
        running: false
        onRunningChanged: {
            if (!running && !batteryDetailsProcess.running) {
                batteryDetailsProcess.running = true;
            }
        }
    }

    Process {
        id: displayListProcess
        command: Commands.controlsHelperCommand("display-list")
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.parseDisplayList(this.text);
            }
        }
    }

    Process {
        id: setDisplayScaleProcess
        command: Commands.controlsHelperCommand("set-display-scale", [root.focusedDisplay, root.displayScale])
        running: false
        onRunningChanged: {
            if (!running && !displayListProcess.running) {
                displayListProcess.running = true;
            }
        }
    }

    Timer {
        interval: 1000
        running: root.mediaState === "Playing" && root.mediaLengthUs > 0
        repeat: true
        onTriggered: {
            root.mediaPositionUs = Math.min(root.mediaLengthUs, root.mediaPositionUs + 1000000);
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            batteryCapacityFile.reload();
            batteryStatusFile.reload();
            Qt.callLater(root.syncBatteryStatus);
            if (root.visible && !batteryDetailsProcess.running) {
                batteryDetailsProcess.running = true;
            }
        }
    }

    Timer {
        interval: 2000
        running: root.visible
        repeat: true
        onTriggered: root.refreshBrightnessStatus()
    }

    Component.onCompleted: {
        root.refreshAudioStatus();
        root.syncBatteryStatus();
        root.syncBrightnessStatus();
    }
}
