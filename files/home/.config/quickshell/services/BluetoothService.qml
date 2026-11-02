pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Bluetooth
import QtQuick

Singleton {
    id: root

    Timer {
        interval: 2000
        repeat: false
        running: Bluetooth.defaultAdapter?.state === BluetoothAdapterState.Enabling
        onTriggered: {
            if (Bluetooth.defaultAdapter?.state === BluetoothAdapterState.Enabling) {
                Quickshell.execDetached(["sh", "-c", "rfkill block bluetooth; sleep 0.5; rfkill unblock bluetooth"]);
            }
        }
    }

    property bool bluetoothEnabled: Bluetooth.defaultAdapter?.state !== BluetoothAdapterState.Blocked
    property var devices: [...Bluetooth.devices.values].sort((a, b) => (b.connected - a.connected) || ((getState(b.state) === "Connecting") - (getState(a.state) === "Connecting")) || (b.paired - a.paired))
    property BluetoothDevice defaultDevice: Bluetooth?.devices?.values?.find(d => d.connected) ?? null
    property bool bluetoothConnected: defaultDevice !== null
    property string bluetoothDeviceName: defaultDevice?.name ?? ""
    property int bluetoothDeviceBattery: defaultDevice?.batteryAvailable ? Math.round(defaultDevice.battery * 100) : 0
    property string bluetoothDeviceIcon: defaultDevice?.icon ? defaultDevice.icon + "-symbolic" : ""

    function getMaterialSymbol(iconName) {
        if (!iconName)
            return "bluetooth";
        const icon = iconName.replace("-symbolic", "");
        const deviceIconMap = {
            "audio-headphones": "headphones",
            "audio-headset": "headset_mic",
            "input-keyboard": "keyboard",
            "input-mouse": "mouse",
            "input-gaming": "sports_esports",
            "phone": "smartphone",
            "computer": "desktop_windows",
            "audio-speakers": "speaker",
            "audio-card": "speaker"
        };
        return deviceIconMap[icon] || "bluetooth";
    }

    property string materialSymbol: {
        if (!root.bluetoothEnabled)
            return "bluetooth_disabled";

        if (root.bluetoothConnected) {
            const icon = root.getMaterialSymbol(root.bluetoothDeviceIcon);
            return icon === "bluetooth" ? "bluetooth_connected" : icon;
        }

        return "bluetooth";
    }

    property string symbolicIcon: {
        if (!root.bluetoothEnabled)
            return "bluetooth-disabled-symbolic";

        if (root.bluetoothDeviceIcon !== "")
            return root.bluetoothDeviceIcon;

        if (root.bluetoothConnected)
            return "bluetooth-paired-symbolic";
        else if (root.bluetoothEnabled)
            return "bluetooth-active-symbolic";

        return "bluetooth-symbolic";
    }

    function toggleBluetooth() {
        if (Bluetooth.defaultAdapter?.state !== BluetoothAdapterState.Blocked) {
            Quickshell.execDetached(["sh", "-c", "rfkill block bluetooth"]);
        } else {
            Quickshell.execDetached(["sh", "-c", "rfkill unblock bluetooth"]);
        }
    }

    function getState(state) {
        return BluetoothDeviceState.toString(state);
    }
}
