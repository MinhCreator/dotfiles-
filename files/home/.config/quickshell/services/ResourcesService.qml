pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // CPU
    property real cpuUsage: 0          // 0.0 → 1.0
    property real cpuTempC: 0          // °C
    property real cpuFreqGHz: 0        // avg across all cores in GHz
    property real cpuMaxFreqGHz: 0     // read once at startup
    property real cpuPowerW: 0         // Watts, CPU package power (RAPL)

    // RAM
    property real ramUsedGiB: 0
    property real ramTotalGiB: 0
    property real ramUsedPercent: ramTotalGiB > 0 ? ramUsedGiB / ramTotalGiB : 0  // 0.0 → 1.0

    // SWAP
    property bool swapActive: false
    property real swapUsedGiB: 0
    property real swapTotalGiB: 0
    property real swapUsedPercent: swapTotalGiB > 0 ? swapUsedGiB / swapTotalGiB : 0  // 0.0 → 1.0

    // GPU
    property real gpuUsage: 0          // 0.0 → 1.0
    property real gpuTempC: 0          // °C
    property real gpuMemUsedGiB: 0
    property real gpuMaxMemGiB: 0

    // Partitions
    property var partitions: []        // [{ path, totalGiB, usedGiB, availGiB, usedPercent }] — binary GiB

    // internal
    property var _prevCpu: null
    property var _prevEnergy: null     // { uj, ts }
    property string _dfBuf: ""
    property real _lastDfUpdate: 0

    // FileViews (cheap scalar reads, reloaded on each poll tick)
    FileView {
        id: fMeminfo
        path: "/proc/meminfo"
    }
    FileView {
        id: fStat
        path: "/proc/stat"
    }
    FileView {
        id: fCpuMaxFreq
        path: "/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq"
    }
    FileView {
        id: fCpuTemp
        path: "/sys/class/hwmon/hwmon4/temp1_input"
    }
    FileView {
        id: fCpuEnergy
        path: "/sys/class/powercap/intel-rapl:0/energy_uj"
    }
    FileView {
        id: fCpuEnergyMax
        path: "/sys/class/powercap/intel-rapl:0/max_energy_range_uj"
    }
    FileView {
        id: fGpuBusy
        path: "/sys/class/drm/card1/device/gpu_busy_percent"
    }
    FileView {
        id: fGpuTemp
        path: "/sys/class/hwmon/hwmon3/temp1_input"
    }
    FileView {
        id: fGpuMaxMem
        path: "/sys/class/drm/card1/device/mem_info_vram_total"
    }
    FileView {
        id: fGpuMem
        path: "/sys/class/drm/card1/device/mem_info_vram_used"
    }

    // avg CPU freq — persistent loop, one line per interval
    // Prints one space-separated value every 2s, restarts automatically if it dies
    Process {
        id: cpuFreqProc
        running: true
        command: ["sh", "-c", "while true; do awk '{s+=$1;c++} END{printf \"%.0f\\n\",s/c}' /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; sleep 2; done"]
        stdout: SplitParser {
            onRead: data => {
                const khz = parseFloat(data.trim());
                if (!isNaN(khz) && khz > 0)
                    root.cpuFreqGHz = +(khz / 1e6).toFixed(2);
            }
        }
        onRunningChanged: if (!running)
            running = true
    }

    // partitions via df — persistent loop, one batch per interval
    // timeout guards against df hanging on a stalled mount (would freeze updates)
    Process {
        id: dfProc
        running: true
        command: ["sh", "-c", "while true; do timeout 5 df -B1 -l --output=source,target,size,used,avail -x tmpfs -x devtmpfs -x efivarfs -x squashfs -x overlay -x iso9660 | tail -n +2; echo '---'; sleep 2; done"]
        stdout: SplitParser {
            onRead: data => {
                if (data.trim() === "---") {
                    root._flushPartitions(root._dfBuf);
                    root._dfBuf = "";
                } else {
                    root._dfBuf += data + "\n";
                }
            }
        }
        onRunningChanged: {
            root._dfBuf = "";
            if (!running)
                running = true;
        }
    }

    // Watchdog: if no fresh df batch arrived within 10s, restart the process
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            if (root._lastDfUpdate > 0 && Date.now() - root._lastDfUpdate > 10000 && dfProc.running)
                dfProc.running = false; // auto-restarts via onRunningChanged
        }
    }

    function _flushPartitions(buf) {
        const lines = buf.trim().split("\n").filter(l => l.trim() !== "");
        const seen = new Set();
        const parsed = [];
        for (const line of lines) {
            const tok = line.trim().split(/\s+/);
            // source ... target size used avail — parsed right-to-left so
            // targets containing spaces stay intact
            if (tok.length < 5)
                continue;
            const size = parseInt(tok[tok.length - 3]);
            const used = parseInt(tok[tok.length - 2]);
            const avail = parseInt(tok[tok.length - 1]);
            if (!isFinite(size) || !isFinite(used) || !isFinite(avail))
                continue;
            if (seen.has(tok[0]))
                continue;
            seen.add(tok[0]);
            const path = tok.slice(1, tok.length - 3).join(" ");
            const usable = used + avail;
            parsed.push({
                path,
                totalGiB: +(size / 1073741824).toFixed(1),
                usedGiB: +(used / 1073741824).toFixed(1),
                availGiB: +(avail / 1073741824).toFixed(1),
                usedPercent: usable > 0 ? Math.min(+(used / usable).toFixed(3), 1) : 0
            });
        }
        parsed.sort((a, b) => {
            if (a.path === "/")
                return -1;
            if (b.path === "/")
                return 1;
            if (a.path === "/home")
                return -1;
            if (b.path === "/home")
                return 1;
            return b.usedPercent - a.usedPercent;
        });
        root.partitions = parsed;
        root._lastDfUpdate = Date.now();
    }

    // startup
    Component.onCompleted: {
        // Prime _prevCpu so the first timer tick yields a real cpuUsage
        fStat.reload();
        const cpu = root._parseCpuStat(fStat.text());
        if (cpu)
            _prevCpu = cpu;

        // Prime _prevEnergy so the first timer tick yields a real cpuPowerW
        fCpuEnergy.reload();
        const ej = parseFloat(fCpuEnergy.text().trim());
        if (!isNaN(ej))
            _prevEnergy = {
                uj: ej,
                ts: Date.now()
            };
    }

    // poll
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root._poll()
    }

    // Parse aggregate "cpu ..." line from /proc/stat
    // total sums all fields (user..guest_nice), idle counts idle + iowait
    // to match htop/btop accounting
    function _parseCpuStat(text) {
        const m = text.match(/^cpu\s+(.+)/m);
        if (!m)
            return null;
        const s = m[1].trim().split(/\s+/).map(Number);
        if (s.length < 4 || s.some(v => isNaN(v)))
            return null;
        return {
            total: s.reduce((a, b) => a + b, 0),
            idle: s[3] + (s[4] || 0)
        };
    }

    function _poll() {
        // RAM & Swap
        fMeminfo.reload();
        const mi = fMeminfo.text();
        const memTotalKB = +(mi.match(/MemTotal:\s*(\d+)/)?.[1] ?? 0);
        const memAvailKB = +(mi.match(/MemAvailable:\s*(\d+)/)?.[1] ?? 0);
        const swapTotalKB = +(mi.match(/SwapTotal:\s*(\d+)/)?.[1] ?? 0);
        const swapFreeKB = +(mi.match(/SwapFree:\s*(\d+)/)?.[1] ?? 0);
        const swapUsedKB = swapTotalKB - swapFreeKB;

        // kB → GiB (meminfo reports kibibytes; binary units to match free/GParted)
        ramTotalGiB = +(memTotalKB / 1048576).toFixed(2);
        ramUsedGiB = +((memTotalKB - memAvailKB) / 1048576).toFixed(2);
        swapTotalGiB = +(swapTotalKB / 1048576).toFixed(2);
        swapUsedGiB = +(swapUsedKB / 1048576).toFixed(2);
        swapActive = swapTotalGiB > 0;

        // CPU max freq
        fCpuMaxFreq.reload();
        const khz = parseFloat(fCpuMaxFreq.text().trim());
        if (!isNaN(khz) && khz > 0)
            cpuMaxFreqGHz = +(khz / 1e6).toFixed(2);

        // CPU usage
        fStat.reload();
        const cur = root._parseCpuStat(fStat.text());
        if (cur) {
            if (_prevCpu) {
                const dt = cur.total - _prevCpu.total;
                const di = cur.idle - _prevCpu.idle;
                if (dt > 0)
                    cpuUsage = +(1 - di / dt).toFixed(3);
            }
            _prevCpu = cur;
        }

        // CPU temp
        fCpuTemp.reload();
        cpuTempC = +(fCpuTemp.text().trim() / 1000).toFixed(1);

        // CPU power (RAPL package energy delta → watts)
        fCpuEnergy.reload();
        const nowUj = parseFloat(fCpuEnergy.text().trim());
        const nowTs = Date.now();
        if (!isNaN(nowUj) && _prevEnergy) {
            let deltaUj = nowUj - _prevEnergy.uj;
            const deltaMs = nowTs - _prevEnergy.ts;
            if (deltaUj < 0) {
                // counter wrapped around; correct using max_energy_range_uj
                fCpuEnergyMax.reload();
                const maxUj = parseFloat(fCpuEnergyMax.text().trim());
                if (!isNaN(maxUj))
                    deltaUj += maxUj;
                else
                    deltaUj = 0; // can't correct, drop this sample
            }
            if (deltaMs > 0)
                cpuPowerW = +((deltaUj / 1e6) / (deltaMs / 1000)).toFixed(1);
        }
        _prevEnergy = {
            uj: nowUj,
            ts: nowTs
        };

        // GPU
        fGpuBusy.reload();
        gpuUsage = +(parseInt(fGpuBusy.text().trim()) / 100).toFixed(2) || 0;

        fGpuTemp.reload();
        gpuTempC = +(fGpuTemp.text().trim() / 1000).toFixed(1);

        fGpuMem.reload();
        gpuMemUsedGiB = +(parseFloat(fGpuMem.text().trim()) / 1073741824).toFixed(2);

        fGpuMaxMem.reload();
        gpuMaxMemGiB = +(parseFloat(fGpuMaxMem.text().trim()) / 1073741824).toFixed(2);
    }
}
