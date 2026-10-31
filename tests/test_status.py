import importlib.util
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('status', Path(__file__).resolve().parents[1] / 'status.py')
status = importlib.util.module_from_spec(spec)
spec.loader.exec_module(status)


@patch.object(status, 'read_service', return_value='active')
class StatusTests(unittest.TestCase):
    @patch.object(status.shutil, 'which', return_value=None)
    def test_missing_cli(self, *_):
        self.assertEqual(status.read_status()['state'], 'missing')

    @patch.object(status.shutil, 'which', return_value='/bin/easytier-cli')
    @patch.object(status, 'run', side_effect=subprocess.TimeoutExpired('cli', 4))
    def test_timeout(self, *_):
        self.assertEqual(status.read_status()['state'], 'unavailable')

    @patch.object(status.shutil, 'which', return_value='/bin/easytier-cli')
    @patch.object(status, 'run', side_effect=[json.dumps({'hostname': 'node', 'ipv4_addr': '10.0.0.1/24', 'config': {'secret': 'never-output'}}), json.dumps([{'hostname': 'peer', 'ipv4': '10.0.0.2', 'lat_ms': 12, 'password': 'never-output'}])])
    def test_whitelist_and_peers(self, *_):
        result = status.read_status()
        self.assertEqual(result['state'], 'ready')
        self.assertEqual(result['ip'], '10.0.0.1')
        self.assertEqual(result['peers'][0]['latency'], '12')
        self.assertNotIn('never-output', json.dumps(result))

    @patch.object(status.shutil, 'which', return_value='/bin/easytier-cli')
    @patch.object(status, 'run', side_effect=['{}', '{}'])
    def test_bad_peer_response(self, *_):
        self.assertEqual(status.read_status()['state'], 'unavailable')


if __name__ == '__main__':
    unittest.main()
