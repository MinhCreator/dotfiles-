pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Networking
import Quickshell.Io
import QtQuick
import qs.components

Singleton {
    id: root

    readonly property int speedHistorySize: 60

    property bool wifiOn: Networking.wifiEnabled

    property WifiDevice wifiInterface: (Networking.devices?.values || []).find(n => n.type === DeviceType.Wifi) ?? null
    property WiredDevice ethernetInterface: (Networking.devices?.values || []).find(n => n.type === DeviceType.Wired) ?? null

    property bool wifiConnected: wifiInterface?.connected ?? false
    property bool ethernetConnected: ethernetInterface?.connected ?? false

    property string activeInterfaceName: (ethernetConnected ? ethernetInterface?.name : wifiInterface?.name) ?? ""

    property list<WifiNetwork> wifiNetworks: (wifiInterface?.networks?.values ? [...wifiInterface.networks.values].sort((a, b) => (b?.connected - a?.connected) || ((b?.state === ConnectionState.Connecting) - (a?.state === ConnectionState.Connecting)) || (b?.signalStrength - a?.signalStrength)) : [])
    property list<Network> ethernetNetworks: (ethernetInterface?.networks?.values ? [...ethernetInterface.networks.values].sort((a, b) => (b?.connected - a?.connected) || ((b?.state === ConnectionState.Connecting) - (a?.state === ConnectionState.Connecting)) || (b?.signalStrength - a?.signalStrength)) : [])

    property WifiNetwork connectedWifiNetwork: wifiNetworks.find(n => n.state === ConnectionState.Connected || n.state === ConnectionState.Connecting) ?? null
    property Network connectedEthernetNetwork: ethernetNetworks.find(n => n.state === ConnectionState.Connected || n.state === ConnectionState.Connecting) ?? null

    property Network wiredNetwork: connectedEthernetNetwork ?? ethernetInterface?.network ?? null

    property list<Network> allNetworks: [...(wiredNetwork ? [wiredNetwork] : []), ...(wifiOn ? wifiNetworks : [])]

    property bool wifiConnecting: connectedWifiNetwork?.state === ConnectionState.Connecting

    property string networkName: ethernetConnected ? (connectedEthernetNetwork?.name ?? "") : (connectedWifiNetwork?.name ?? "")

    property string localIpAddress: ""
    property var ipByInterface: ({})

    property int networkStrength: (connectedWifiNetwork?.signalStrength ?? 0) * 100

    property var connectivity: Networking.connectivity // NetworkConnectivity as type doesn't work (23/04/2026 - Thusday)

    property real downloadSpeed: 0
    property real uploadSpeed: 0
    property real prevRxBytes: 0
    property real prevTxBytes: 0

    property var downloadSpeedHistory: new Array(speedHistorySize).fill(0)
    property var uploadSpeedHistory: new Array(speedHistorySize).fill(0)

    InfiniteTimer {
        interval: 300000
        onTriggered: Networking.checkConnectivity()
    }

    Process {
        id: ipProbeProcess
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of text.split("\n")) {
                    const m = line.match(/^\d+:\s+(\S+)\s+inet\s+(\d+\.\d+\.\d+\.\d+)/);
                    if (m && !(m[1] in map))
                        map[m[1]] = m[2];
                }
                root.ipByInterface = map;
                const ip = map[root.activeInterfaceName] ?? "";
                if (root.localIpAddress !== ip)
                    root.localIpAddress = ip;
            }
        }
    }

    function refreshLocalIp() {
        if (ipProbeProcess.running)
            return;
        ipProbeProcess.exec(["ip", "-4", "-o", "addr", "show", "scope", "global"]);
    }

    function ipFor(network) {
        return root.ipByInterface[network?.device?.name ?? ""] ?? "";
    }

    onActiveInterfaceNameChanged: refreshLocalIp()
    onNetworkNameChanged: refreshLocalIp()

    InfiniteTimer {
        interval: 30000
        onTriggered: root.refreshLocalIp()
    }

    property string materialSymbol: {
        if (ethernetConnected && connectivity !== NetworkConnectivity.Full)
            return "settings_ethernet";
        if (ethernetConnected)
            return "lan";
        if (!wifiOn)
            return "signal_wifi_off";
        if (wifiConnecting)
            return "wifi_find";
        if (!wifiConnected)
            return "signal_wifi_statusbar_not_connected";
        if (connectivity !== NetworkConnectivity.Full)
            return "signal_wifi_bad";
        if (networkStrength >= 75)
            return "signal_wifi_4_bar";
        if (networkStrength >= 50)
            return "network_wifi_3_bar";
        if (networkStrength >= 25)
            return "network_wifi_2_bar";
        if (networkStrength > 0)
            return "network_wifi_1_bar";
        return "signal_wifi_0_bar";
    }

    property string symbolicIcon: {
        if (ethernetConnected && connectivity !== NetworkConnectivity.Full)
            return "network-wired-no-route-symbolic";
        if (ethernetConnected)
            return "network-wired-symbolic";
        if (!wifiOn)
            return "network-wireless-disabled-symbolic";
        if (wifiConnecting)
            return "network-wireless-acquiring-symbolic";
        if (!wifiConnected)
            return "network-wireless-offline-symbolic";
        if (connectivity !== NetworkConnectivity.Full)
            return "network-wireless-no-route-symbolic";

        if (networkStrength >= 75)
            return "network-wireless-signal-good-symbolic";
        if (networkStrength >= 40)
            return "network-wireless-signal-ok-symbolic";
        if (networkStrength >= 20)
            return "network-wireless-signal-weak-symbolic";
        return "network-wireless-signal-none-symbolic";
    }

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function setWifi(state) {
        Networking.wifiEnabled = state;
    }

    function isSecured(securityType) {
        return WifiSecurityType.Open !== securityType;
    }

    function getConnectionState(state) {
        return ConnectionState.toString(state);
    }

    FileView {
        id: rxBytesFile
        path: root.activeInterfaceName ? "/sys/class/net/" + root.activeInterfaceName + "/statistics/rx_bytes" : ""
        watchChanges: false
        preload: true
    }

    FileView {
        id: txBytesFile
        path: root.activeInterfaceName ? "/sys/class/net/" + root.activeInterfaceName + "/statistics/tx_bytes" : ""
        watchChanges: false
        preload: true
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.activeInterfaceName !== ""

        onTriggered: {
            if (!root.activeInterfaceName)
                return;

            rxBytesFile.reload();
            txBytesFile.reload();

            const currentRxBytes = parseInt(rxBytesFile.text().trim()) || 0;
            const currentTxBytes = parseInt(txBytesFile.text().trim()) || 0;

            if (root.prevRxBytes > 0) {
                const dl = Math.max(0, (currentRxBytes - root.prevRxBytes) / 1024).toFixed(1);
                const ul = Math.max(0, (currentTxBytes - root.prevTxBytes) / 1024).toFixed(1);

                root.downloadSpeed = dl;
                root.uploadSpeed = ul;

                const newDlHistory = [...root.downloadSpeedHistory.slice(1), parseFloat(dl)];
                const newUlHistory = [...root.uploadSpeedHistory.slice(1), parseFloat(ul)];
                root.downloadSpeedHistory = newDlHistory;
                root.uploadSpeedHistory = newUlHistory;
            }

            root.prevRxBytes = currentRxBytes;
            root.prevTxBytes = currentTxBytes;
        }
    }
}
