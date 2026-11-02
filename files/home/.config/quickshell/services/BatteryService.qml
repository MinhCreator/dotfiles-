pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.UPower
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property UPowerDevice battery: UPower.devices.values.length > 0 ? UPower.devices.values[0] : null
    readonly property int batteryState: battery.state
    readonly property real batteryPercentage: battery.percentage

    property bool autoManageEnabled: false

    Component.onCompleted: _getProcess.running = true

    // Read current state
    Process {
        id: _getProcess
        command: ["gdbus", "call", "--system", "--dest", "org.freedesktop.UPower", "--object-path", `/org/freedesktop/UPower/devices/battery_${root.battery.nativePath}`, "--method", "org.freedesktop.DBus.Properties.Get", "org.freedesktop.UPower.Device", "ChargeThresholdEnabled"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                root.autoManageEnabled = data.includes("true");
            }
        }
    }

    Process {
        id: _setProcess
        running: false
    }

    function enableAutoManage() {
        _setProcess.command = ["gdbus", "call", "--system", "--dest", "org.freedesktop.UPower", "--object-path", `/org/freedesktop/UPower/devices/battery_${root.battery.nativePath}`, "--method", "org.freedesktop.UPower.Device.EnableChargeThreshold", "true"];
        _setProcess.running = true;
        autoManageEnabled = true;
    }

    function disableAutoManage() {
        _setProcess.command = ["gdbus", "call", "--system", "--dest", "org.freedesktop.UPower", "--object-path", `/org/freedesktop/UPower/devices/battery_${root.battery.nativePath}`, "--method", "org.freedesktop.UPower.Device.EnableChargeThreshold", "false"];
        _setProcess.running = true;
        autoManageEnabled = false;
    }

    function toggleAutoManage() {
        autoManageEnabled ? disableAutoManage() : enableAutoManage();
    }
}
