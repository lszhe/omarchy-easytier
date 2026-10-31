import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('status_service', Path(__file__).resolve().parents[1] / 'status.py')
status = importlib.util.module_from_spec(spec)
spec.loader.exec_module(status)


class ServiceTests(unittest.TestCase):
    @patch.object(status, 'run', return_value='LoadState=loaded\nActiveState=active\n')
    def test_loaded_service(self, run):
        self.assertEqual(status.read_service('easytier.service'), 'active')
        run.assert_called_once_with('systemctl', 'show', '--property=LoadState', '--property=ActiveState', '--', 'easytier.service')

    @patch.object(status, 'run', return_value='LoadState=not-found\nActiveState=inactive\n')
    def test_missing_service(self, _):
        self.assertEqual(status.read_service('missing.service'), 'missing')

    @patch.object(status, 'run')
    def test_invalid_service_never_runs_command(self, run):
        for name in ['--help', 'x.service;touch /tmp/bad', '../x.service', 'x.target']:
            self.assertEqual(status.read_service(name), 'invalid')
        run.assert_not_called()

    @patch.object(status, 'run', side_effect=subprocess.TimeoutExpired('systemctl', 4))
    def test_timeout_is_unknown(self, _):
        self.assertEqual(status.read_service('easytier.service'), 'unknown')


if __name__ == '__main__':
    unittest.main()
