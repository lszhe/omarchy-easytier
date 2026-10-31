"""Regression checks for the panel's Item default property and copy action."""
from pathlib import Path
import unittest

PANEL = (Path(__file__).resolve().parents[1] / 'Panel.qml').read_text()


class PanelTests(unittest.TestCase):
    def test_status_does_not_override_item_data(self):
        self.assertNotIn('property var data:', PANEL)
        self.assertIn('property var statusData:', PANEL)
        self.assertIn('statusData = JSON.parse(raw)', PANEL)

    def test_copy_uses_argument_vector_and_requires_ip(self):
        self.assertIn('if (ip) Quickshell.execDetached(["wl-copy", "--", String(ip)])', PANEL)
        self.assertIn('onClicked: root.copyIp(root.statusData.ip)', PANEL)
        self.assertIn('onClicked: root.copyIp(modelData.ip)', PANEL)


if __name__ == '__main__':
    unittest.main()
