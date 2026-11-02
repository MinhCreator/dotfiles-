pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    property var pwDumpData: ({})
    property var _pwDumpDataInternal: ({})
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.isSink)

    readonly property var nodes: Pipewire.nodes.values.reduce((acc, node) => {
        if (!node.isStream) {
            if (node.isSink)
                acc.sinks.push(node);
            else if (node.audio)
                acc.sources.push(node);
        }
        return acc;
    }, {
        sources: [],
        sinks: []
    })
    readonly property list<PwNode> sinks: nodes.sinks
    readonly property list<PwNode> sources: nodes.sources
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property string symbolicIconSink: getSinkSymbolicIcon(root.sink)
    readonly property string symbolicIconSource: getSourceSymbolicIcon(root.source)
    readonly property string materialSymbolSink: getSinkMaterialSymbol(root.sink)
    readonly property string materialSymbolSource: getSourceMaterialSymbol(root.source)

    readonly property var unifiedList: {
        let items = [];

        for (let i = 0; i < sinks.length; i++) {
            let node = sinks[i];
            let dump = root.pwDumpData[node.id] || {};
            items.push({
                node: node,
                type: "device",
                section: "Output Devices",
                isInput: false,
                dump: dump,
                clientName: node.description
            });
        }
        for (let i = 0; i < streams.length; i++) {
            let node = streams[i];
            let dump = root.pwDumpData[node.id] || {};
            items.push({
                node: node,
                type: "stream",
                section: "Output Applications",
                isInput: false,
                dump: dump,
                clientName: root.getClientName(node, dump)
            });
        }
        for (let i = 0; i < sources.length; i++) {
            let node = sources[i];
            let dump = root.pwDumpData[node.id] || {};
            items.push({
                node: node,
                type: "device",
                section: "Input Devices",
                isInput: true,
                dump: dump,
                clientName: node.description
            });
        }
        return items;
    }

    function getClientName(node, dump) {
        const clientId = dump?.info?.props?.["client.id"];
        if (clientId !== undefined) {
            const clientDump = root.pwDumpData[clientId];
            if (clientDump && clientDump.info?.props?.["application.name"])
                return clientDump.info.props["application.name"];
        }
        return node.name;
    }

    function setDefaultSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }
    function setDefaultSource(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }
    function toggleSinkMuted() {
        root.sink.audio.muted = root.sink.audio.muted ? false : true;
    }
    function toggleSourceMuted() {
        root.source.audio.muted = root.source.audio.muted ? false : true;
    }

    function getSourceSymbolicIcon(source) {
        if (!source || !source.audio) {
            return "microphone-disabled-symbolic";
        }
        const volume = source.audio.volume;
        const isMuted = volume <= 0.01 || source.audio.muted;
        return isMuted ? "microphone-disabled-symbolic" : volume <= 0.5 ? "microphone-sensitivity-medium-symbolic" : "microphone-sensitivity-high-symbolic";
    }

    function getSinkSymbolicIcon(sink) {
        if (!sink || !sink.audio) {
            return "audio-volume-muted-symbolic";
        }
        const volume = sink?.audio?.volume;
        const isMuted = volume <= 0.01 || sink.audio.muted;
        let level = "muted";
        if (!isMuted) {
            if (volume < 0.33)
                level = "low";
            else if (volume < 0.66)
                level = "medium";
            else if (volume <= 1)
                level = "high";
            else if (volume > 1)
                level = "overamplified";
        }
        return `audio-volume-${level}-symbolic`;
    }

    function getSourceMaterialSymbol(source) {
        if (!source || !source.audio || source.audio.volume <= 0.01 || source.audio.muted)
            return "mic_off";
        return "mic";
    }

    function getSinkMaterialSymbol(sink) {
        if (!sink || !sink.audio)
            return "volume_off";
        const vol = sink.audio.volume ?? 0;
        if (sink.audio.muted || vol <= 0.01)
            return "volume_off";
        return "volume_up";
    }

    function clampVolumeTarget(current, val) {
        const next = current + val;
        if (next >= 1.5)
            return 1.5;
        if (val > 0 && current < 1.0 && next > 1.0 && next < 1.0 + val)
            return 1.0;
        if (val < 0 && next < 1.0 && next > 1.0 + val)
            return 1.0;
        return Math.max(0, next);
    }

    function increaseSinkVolume(val = 0.05) {
        if (root.sink?.ready && root.sink?.audio)
            root.sink.audio.volume = clampVolumeTarget(root.sink.audio.volume, val);
    }
    function decreaseSinkVolume(val = 0.05) {
        if (root.sink?.ready && root.sink?.audio)
            root.sink.audio.volume = clampVolumeTarget(root.sink.audio.volume, -val);
    }

    function increaseSourceVolume(val = 0.05) {
        if (root.source?.ready && root.source?.audio)
            root.source.audio.volume = clampVolumeTarget(root.source.audio.volume, val);
    }
    function decreaseSourceVolume(val = 0.05) {
        if (root.source?.ready && root.source?.audio)
            root.source.audio.volume = clampVolumeTarget(root.source.audio.volume, -val);
    }

    Process {
        id: pwDumpProcess
        command: ["sh", "-c", "pw-dump -m | jq -c --unbuffered ."]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    let hasChanged = false;
                    const updates = JSON.parse(data);
                    const newMap = Object.assign({}, root.pwDumpData);
                    for (const item of updates) {
                        const mask = item.info?.["change-mask"] ?? [];
                        if (mask.length === 1 && mask[0] === "params")
                            continue;
                        hasChanged = true;
                        newMap[item.id] = item;
                    }
                    if (hasChanged) {
                        const keys = Object.keys(newMap);
                        if (keys.length > 500) {
                            const fresh = {};
                            for (let i = keys.length - 500; i < keys.length; i++)
                                fresh[keys[i]] = newMap[keys[i]];
                            root.pwDumpData = fresh;
                        } else {
                            root.pwDumpData = newMap;
                        }
                    }
                } catch (e) {
                    console.error("Failed to parse pw-dump monitor update:", e);
                }
            }
        }
        onRunningChanged: {
            if (!running) {
                running = true;
            }
        }
    }

    PwObjectTracker {
        objects: [...root.sinks, ...root.sources, ...root.streams]
    }
}
