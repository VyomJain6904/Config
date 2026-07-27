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
    property string volumeText: "VOL unavailable"
    property int volumePercent: 0
    property bool volumeMuted: false
    property string volumeDisplayText: volumeText + (outputDeviceDescription.length > 0 ? " - " + outputDeviceDescription : "")

    property int brightnessPercent: 0
    property bool brightnessReady: false
    property int targetVolume: -1
    property int targetBrightness: -1
    property int batteryPercent: 0
    property bool batteryCharging: false
    property var outputDevices: []
    property string outputDeviceName: ""
    property string outputDeviceDescription: ""
    property var inputDevices: []
    property string inputDeviceName: ""
    property string micText: "MIC unavailable"
    property string mediaText: "MEDIA none"
    property string mediaPlayer: ""
    property string mediaState: ""
    property string bluetoothText: "BT unavailable"
    property string pendingAction: ""
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property var audioSource: Pipewire.defaultAudioSource

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
            root.volumeText = (root.volumeMuted ? "VOL muted " : "VOL ") + root.volumePercent.toString() + "%";
            root.outputDeviceName = sink.name;
            root.outputDeviceDescription = sink.description.length > 0 ? sink.description : sink.name;
        } else {
            root.volumeText = "VOL unavailable";
            root.volumeMuted = false;
            root.outputDeviceName = "";
            root.outputDeviceDescription = "";
            if (!volumeStatusProcess.running) {
                volumeStatusProcess.running = true;
            }
        }

        const source = root.audioSource;
        if (source !== null && source.ready && source.audio !== null) {
            root.micText = source.audio.muted ? "MIC muted" : "MIC on";
        } else {
            root.micText = "MIC unavailable";
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
        if (!root.visible) {
            return;
        }
        if (!mediaStatusProcess.running) {
            mediaStatusProcess.running = true;
        }
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
        if (!brightnessStatusProcess.running) {
            brightnessStatusProcess.running = true;
        }
    }

    function parseMedia(text) {
        const trimmed = text.trim();

        if (trimmed.length === 0 || trimmed.indexOf("MEDIA ") === 0) {
            root.mediaText = trimmed.length > 0 ? trimmed : "MEDIA none";
            root.mediaPlayer = "";
            root.mediaState = "";
            return;
        }

        const fields = trimmed.split("\t");

        root.mediaPlayer = fields.length > 0 ? fields[0] : "";
        root.mediaState = fields.length > 1 ? fields[1] : "";

        const artist = fields.length > 2 ? fields[2] : "";
        const title = fields.length > 3 ? fields.slice(3).join("\t") : "";

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

    function parseVolume(text) {
        const trimmed = text.trim();

        if (trimmed.length > 0) {
            root.volumeText = trimmed;
        }

        const match = trimmed.match(/([0-9]+)%/);
        if (match !== null) {
            root.volumePercent = root.clampPercent(parseInt(match[1], 10));
        }
        root.volumeMuted = trimmed.indexOf("VOL muted") === 0;
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

    function volumeSet(percent) {
        const value = root.clampPercent(percent);
        root.targetVolume = value;
        root.volumePercent = value;
        root.volumeText = (root.volumeMuted ? "VOL muted " : "VOL ") + value.toString() + "%";
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

    function mediaPlayPause() {
        root.runAction("media-play-pause");
    }

    function mediaNext() {
        root.runAction("media-next");
    }

    function mediaPrevious() {
        root.runAction("media-previous");
    }

    PwObjectTracker {
        objects: [root.audioSink, root.audioSource]
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
                    root.parseVolume(this.text.length > 0 ? this.text : "VOL unavailable");
                }
            }
        }
    }

    Process {
        id: brightnessStatusProcess

        command: Commands.controlsHelperCommand("brightness-status")
        running: true

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
                    root.micText = text.length > 0 ? text : "MIC unavailable";
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
        id: batteryStatusProcess

        command: Commands.controlsHelperCommand("battery-status")
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                root.parseBattery(this.text);
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            if (!batteryStatusProcess.running) {
                batteryStatusProcess.running = true;
            }
        }
    }

    Component.onCompleted: root.refreshAudioStatus()
}
