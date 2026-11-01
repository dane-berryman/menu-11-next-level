# SPDX-License-Identifier: GPL-2.0-or-later
import importlib.util
import json
import subprocess
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('system_info', Path(__file__).parents[1] / 'contents/ui/code/system_info.py')
system_info = importlib.util.module_from_spec(spec)
spec.loader.exec_module(system_info)


class SystemInfoTest(unittest.TestCase):
    def test_ram_uses_available_memory(self):
        self.assertEqual(system_info.memory_usage('MemTotal: 1000 kB\nMemAvailable: 250 kB\n'),
                         {'total': 1024000, 'used': 768000})

    def test_address_from_local_routing_table(self):
        result = subprocess.CompletedProcess([], 0, json.dumps([{'prefsrc': '192.0.2.20'}]))
        with patch.object(system_info.subprocess, 'run', return_value=result) as run:
            self.assertEqual(system_info.local_ip(), '192.0.2.20')
            self.assertEqual(run.call_args.args[0][:4], ['ip', '-j', 'route', 'get'])

    def test_disconnected_network(self):
        with patch.object(system_info.subprocess, 'run', side_effect=OSError('offline')):
            self.assertIsNone(system_info.local_ip())


if __name__ == '__main__':
    unittest.main()
