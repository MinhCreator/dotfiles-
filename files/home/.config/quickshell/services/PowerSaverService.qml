pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.services

Singleton {
    id: root

    function applyPowerSaverMode(enabled) {
        GlobalSettings.isPowerSaverEnabled = enabled;
        let powerSaverJson = HyprlandService.getPowerSaverJson();
        powerSaverJson.enabled = GlobalSettings.isPowerSaverEnabled;
        HyprlandService.setPowerSaverJson(powerSaverJson);
    }

    Connections {
        target: PowerProfiles
        enabled: !GlobalSettings.forcePowerSaver
        function onProfileChanged() {
            root.applyPowerSaverMode(PowerProfiles.profile === PowerProfile.PowerSaver);
        }
    }
}
