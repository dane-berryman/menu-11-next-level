# SPDX-License-Identifier: GPL-2.0-or-later
"""Read local system information; no network requests are made."""
import json
import shutil
import subprocess
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


def collect():
    result = {'ip': local_ip(), 'disk': None, 'ram': None}
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
