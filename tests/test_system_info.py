# SPDX-License-Identifier: GPL-2.0-or-later
import importlib.util
import json
import subprocess
import unittest
from pathlib import Path
from unittest.mock import patch, Mock

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

    def test_cpu_percentage_and_guest_accounting(self):
        self.assertEqual(system_info.cpu_counters('cpu 10 0 10 60 20 0 0 0 999 999'), (100, 80))
        self.assertEqual(system_info.cpu_usage((100, 80), (200, 130)), 50.0)
        self.assertIsNone(system_info.cpu_usage((100, 80), (100, 80)))

    def test_gpu_zero_is_valid(self):
        counter = Mock()
        counter.read_text.return_value = '0'
        with patch.object(system_info.Path, 'glob', return_value=[counter]):
            self.assertEqual(system_info.gpu_percent(), 0)

    def test_gpu_unavailable_is_not_reported_as_zero(self):
        with patch.object(system_info.Path, 'glob', return_value=[]), patch.object(system_info.shutil, 'which', return_value=None):
            self.assertIsNone(system_info.gpu_percent())

    def test_nvidia_gpu_fallback(self):
        result = subprocess.CompletedProcess([], 0, '12\n34\n')
        with patch.object(system_info.Path, 'glob', return_value=[]), patch.object(system_info.shutil, 'which', return_value='/usr/bin/nvidia-smi'), patch.object(system_info.subprocess, 'run', return_value=result):
            self.assertEqual(system_info.gpu_percent(), 34)


if __name__ == '__main__':
    unittest.main()
