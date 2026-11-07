# SPDX-License-Identifier: GPL-2.0-or-later
"""Read local system information; no network requests are made."""
import json
import shutil
import subprocess
import time
from pathlib import Path


def memory_usage(text):
    values = {}
    for line in text.splitlines():
        key, _, value = line.partition(':')
        if value.strip():
            values[key] = int(value.split()[0]) * 1024
    total = values.get('MemTotal', 0)
    available = values.get('MemAvailable', values.get('MemFree', 0))
    return {'total': total, 'used': max(0, total - available)}


def local_ip():
    # Ask the kernel which source address its default route would use; send no packets.
    for address in ('1.1.1.1', '2606:4700:4700::1111'):
        try:
            result = subprocess.run(['ip', '-j', 'route', 'get', address],
                                    capture_output=True, text=True, timeout=2, check=True)
            for route in json.loads(result.stdout):
                source = route.get('prefsrc') or route.get('src')
                if source:
                    return source
        except (OSError, subprocess.SubprocessError, ValueError):
            continue
    return None


def cpu_counters(text):
    values = [int(value) for value in text.splitlines()[0].split()[1:9]]
    return sum(values), values[3] + values[4]


def cpu_usage(before, after):
    total = after[0] - before[0]
    idle = after[1] - before[1]
    if total <= 0:
        return None
    return round(max(0, min(100, 100 * (total - idle) / total)), 1)


def cpu_percent():
    try:
        before = cpu_counters(Path('/proc/stat').read_text())
        time.sleep(0.2)
        return cpu_usage(before, cpu_counters(Path('/proc/stat').read_text()))
    except (OSError, ValueError, IndexError):
        return None


def gpu_percent():
    # AMD and other drivers exposing the standard DRM busy counter.
    readings = []
    for counter in Path('/sys/class/drm').glob('card[0-9]*/device/gpu_busy_percent'):
        try:
            value = float(counter.read_text().strip())
            if 0 <= value <= 100:
                readings.append(value)
        except (OSError, ValueError):
            pass
    if readings:
        return round(max(readings), 1)
    if shutil.which('nvidia-smi'):
        try:
            result = subprocess.run(['nvidia-smi', '--query-gpu=utilization.gpu',
                                     '--format=csv,noheader,nounits'], capture_output=True,
                                    text=True, check=True, timeout=2)
            readings = [float(line.strip()) for line in result.stdout.splitlines()]
            readings = [value for value in readings if 0 <= value <= 100]
            return round(max(readings), 1) if readings else None
        except (OSError, subprocess.SubprocessError, ValueError):
            pass
    return None


def collect():
    result = {'ip': local_ip(), 'disk': None, 'ram': None, 'cpu': cpu_percent(), 'gpu': gpu_percent()}
    try:
        disk = shutil.disk_usage(Path.home())
        result['disk'] = {'total': disk.total, 'free': disk.free}
    except OSError:
        pass
    try:
        result['ram'] = memory_usage(Path('/proc/meminfo').read_text())
    except (OSError, ValueError):
        pass
    return result


if __name__ == '__main__':
    print(json.dumps(collect()))
