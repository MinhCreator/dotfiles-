pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import Quickshell.Services.UPower
import qs.services
import qs

Singleton {
    id: root

    property real lowBatteryThreshold: 0.25

    property var currentPowerProfile: PowerProfiles.profile
    property string currentPowerProfileString: PowerProfile.toString(currentPowerProfile)

    readonly property UPowerDevice batteryDevice: UPower.devices.values.length > 0 ? UPower.devices.values[0] : null
    readonly property int batteryDeviceState: batteryDevice?.state ?? 0
    readonly property real batteryDevicePercentage: batteryDevice?.percentage ?? 0

    readonly property bool lowBatteryNotified: GlobalCache.lowBatteryNotified ?? false
    property bool enableSwitching: false

    Component.onCompleted: {
        const savedProfile = GlobalCache.powerProfile;
        if (savedProfile !== undefined && savedProfile !== null)
            PowerProfiles.profile = parseInt(savedProfile);

        const savedInhibit = GlobalCache.wasInhibitActive ?? false;
        if (savedInhibit && !InhibitorService.inhibit)
            InhibitorService.toggleInhibit();
    }

    Timer {
        interval: 500
        running: true
        repeat: false
        onTriggered: root.enableSwitching = true
    }

    onBatteryDevicePercentageChanged: {
        if (!enableSwitching)
            return;
        if (batteryDevicePercentage <= lowBatteryThreshold && batteryDeviceState === UPowerDeviceState.Discharging) {
            setPowerProfile(PowerProfile.PowerSaver);
            if (InhibitorService.inhibit) {
                GlobalCache.wasInhibitActive = true;
                InhibitorService.toggleInhibit();
            }

            if (!lowBatteryNotified) {
                Quickshell.execDetached(["notify-send", "-a", "System Monitor", "-r", "999", "-i", "utilities-energy-monitor", "-t", "30000", "Battery Alert", "Battery level at <b>" + Math.round(batteryDevicePercentage * 100) + "%</b>"]);
                GlobalCache.lowBatteryNotified = true;
            }
        } else if (batteryDevicePercentage > lowBatteryThreshold) {
            GlobalCache.lowBatteryNotified = false;
        }
    }

    onBatteryDeviceStateChanged: {
        if (!enableSwitching)
            return;
        switch (batteryDeviceState) {
        case UPowerDeviceState.Discharging:
            setPowerProfile(PowerProfile.PowerSaver);
            if (InhibitorService.inhibit) {
                GlobalCache.wasInhibitActive = true;
                InhibitorService.toggleInhibit();
            }
            break;
        default:
            setPowerProfile(PowerProfile.Balanced);
            GlobalCache.lowBatteryNotified = false;
            restoreInhibit();
            break;
        }
    }

    function restoreInhibit() {
        const shouldRestore = GlobalCache.wasInhibitActive ?? false;
        if (shouldRestore && !InhibitorService.inhibit) {
            InhibitorService.toggleInhibit();
        }
        GlobalCache.wasInhibitActive = false;
    }

    property string materialSymbol: {
        switch (currentPowerProfile) {
        case PowerProfile.PowerSaver:
            return "eco";
        case PowerProfile.Balanced:
            return "balance";
        case PowerProfile.Performance:
            return "electric_bolt";
        default:
            return "balance";
        }
    }

    property string symbolicIcon: {
        switch (currentPowerProfile) {
        case PowerProfile.PowerSaver:
            return "power-profile-power-saver-symbolic";
        case PowerProfile.Balanced:
            return "power-profile-balanced-symbolic";
        case PowerProfile.Performance:
            return "power-profile-performance-symbolic";
        default:
            return "power-profile-balanced-symbolic";
        }
    }

    function setPowerProfile(profile) {
        if (PowerProfiles.profile !== profile) {
            PowerProfiles.profile = profile;
            GlobalCache.powerProfile = PowerProfiles.profile;
        }
    }

    function toggleBalancedPowersaver() {
        if (PowerProfiles.profile === PowerProfile.Balanced) {
            setPowerProfile(PowerProfile.PowerSaver);
        } else {
            setPowerProfile(PowerProfile.Balanced);
        }
    }
}
