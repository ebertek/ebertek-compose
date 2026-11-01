"""Offline regression tests for opt-in service probing and inventory proposals."""

import importlib.util
import unittest
from pathlib import Path


def load(module_name, file_name):
    """Import same-directory CLI modules without executing their entry points."""
    spec = importlib.util.spec_from_file_location(
        module_name, Path(__file__).with_name(file_name)
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


PROBE = load("probe_services", "probe_services.py")
PROPOSAL = load("propose_ports", "propose_ports.py")


class ServiceDiscoveryTests(unittest.TestCase):
    """Inspect only observed service metadata and approved inventory changes."""

    def test_version_identification_only_for_open_ports(self):
        """Retain probed service identities while excluding closed ports."""
        xml = """<nmaprun><host><status state="up"/>
        <address addrtype="ipv4" addr="10.4.20.33"/>
        <ports><port protocol="tcp" portid="6444">
        <state state="open"/>
        <service name="unknown" product="Midea" method="probed" conf="8"/>
        </port><port protocol="tcp" portid="22">
        <state state="filtered"/></port></ports></host></nmaprun>"""
        self.assertEqual(
            PROBE.parse_services(xml),
            [
                {
                    "ip": "10.4.20.33",
                    "protocol": "tcp",
                    "port": 6444,
                    "name": "unknown",
                    "product": "Midea",
                    "method": "probed",
                    "conf": "8",
                }
            ],
        )

    def test_port_proposal_is_repeatable_and_preserves_mac(self):
        """Adding a discovered service twice must not create duplicates."""
        document = {
            "version": 1,
            "hosts": [
                {
                    "hostname": "aircon-sunroom.ygg.nu",
                    "ipv4": "10.4.20.33",
                    "mac": "84:7c:9b:24:5d:9a",
                    "ports": [],
                },
                {"hostname": "doorbell.ygg.nu", "open_ports": [80]},
            ],
        }
        proposed, added, missing = PROPOSAL.propose(document)
        self.assertIn("aircon-sunroom.ygg.nu: tcp/6444", added)
        self.assertIn("doorbell.ygg.nu: tcp/8554 (legacy format)", added)
        self.assertIn("sub.ygg.nu", missing)
        self.assertEqual(document["hosts"][0]["ports"], [])
        second, again, _ = PROPOSAL.propose(proposed)
        self.assertEqual(again, [])
        self.assertEqual(second, proposed)
        self.assertEqual(proposed["hosts"][0]["mac"], "84:7c:9b:24:5d:9a")


if __name__ == "__main__":
    unittest.main()
