"""Offline fixtures for network discovery and repeat-alert suppression."""

import importlib.util
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location(
    "network_audit", Path(__file__).with_name("audit.py")
)
if SPEC is None or SPEC.loader is None:
    raise ImportError("Cannot load audit.py")
audit = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(audit)

XML = """<?xml version="1.0"?>
<nmaprun>
  <host><status state="up"/><address addr="10.4.20.33" addrtype="ipv4"/>
    <address addr="84:7C:9B:24:5D:9A" addrtype="mac"/>
    <ports>
      <port protocol="tcp" portid="6444"><state state="open"/></port>
      <port protocol="tcp" portid="22"><state state="closed"/></port>
      <port protocol="udp" portid="5550"><state state="open|filtered"/></port>
    </ports>
  </host>
  <host><status state="down"/><address addr="10.4.20.34" addrtype="ipv4"/></host>
</nmaprun>"""


class NetworkAuditTests(unittest.TestCase):
    """Scanners must not infer open services from uncertainty."""

    def test_xml_only_counts_confirmed_open(self):
        hosts = audit.parse_nmap_xml(XML)
        self.assertEqual(list(hosts), ["10.4.20.33"])
        self.assertEqual(hosts["10.4.20.33"]["mac"], "84:7c:9b:24:5d:9a")
        self.assertEqual(hosts["10.4.20.33"]["ports"], ["tcp/6444"])

    def test_avahi_deduplicates_ip_versions_and_interfaces(self):
        line = "=;eth0;IPv4;Aircon;_example._tcp;local;air.local;10.4.20.33;6444;data"
        another = "=;eth1;IPv6;Aircon;_example._tcp;local;air.local;fd00::1;6444;data"
        records = audit.parse_avahi(line + "\n" + another)
        self.assertEqual(len(records), 1)
        self.assertEqual(records[0]["port"], 6444)

    def test_new_service_alert_once_until_it_disappears(self):
        inventory = {
            "10.4.20.33": {
                "name": "aircon-sunroom.ygg.nu",
                "mac": "84:7c:9b:24:5d:9a",
                "ports": set(),
            }
        }
        hosts = audit.parse_nmap_xml(XML)
        events, reported, services = audit.calculate_events(
            inventory, hosts, [], {}, set()
        )
        self.assertEqual(len(events), 1)
        self.assertIn("tcp/6444", events[0])
        previous = {
            "initialized": True,
            "reported": reported,
            "advertisements": services,
        }
        events, _, _ = audit.calculate_events(inventory, hosts, [], previous, set())
        self.assertEqual(events, [])

    def test_unknown_device_and_identity_drift(self):
        inventory = {
            "10.4.20.33": {
                "name": "aircon-sunroom.ygg.nu",
                "mac": "84:7c:9b:24:5d:9a",
                "ports": set(),
            }
        }
        hosts = {
            "10.4.20.33": {"mac": "00:11:22:33:44:55", "ports": []},
            "10.4.20.118": {"mac": "18:48:be:cf:90:3d", "ports": []},
        }
        events, _, _ = audit.calculate_events(inventory, hosts, [], {}, set())
        self.assertEqual(len(events), 2)
        self.assertTrue(any("CHANGED MAC" in event for event in events))
        self.assertTrue(any("NEW DEVICE" in event for event in events))

    def test_known_mac_on_new_ip_is_address_change(self):
        """An appliance moving to another LAN address is not an unknown device."""
        inventory = {
            "10.4.20.33": {
                "name": "aircon-sunroom.ygg.nu",
                "mac": "84:7c:9b:24:5d:9a",
                "ports": set(),
            }
        }
        hosts = {
            "10.4.21.242": {
                "mac": "84:7c:9b:24:5d:9a",
                "ports": ["tcp/6444"],
            }
        }
        events, _, _ = audit.calculate_events(inventory, hosts, [], {}, set())
        self.assertTrue(any("CHANGED IP" in item for item in events))
        self.assertTrue(any("NEW PORT" in item for item in events))
        self.assertFalse(any("NEW DEVICE" in item for item in events))

    def test_unavailable_dns_sd_does_not_clear_history(self):
        previous = {
            "initialized": True,
            "reported": {},
            "advertisements": ["air.local|_example._tcp|6444"],
        }
        _, _, recorded = audit.calculate_events(
            {}, {}, [], previous, set(), dns_sd_complete=False
        )
        self.assertEqual(recorded, previous["advertisements"])


if __name__ == "__main__":
    unittest.main()
