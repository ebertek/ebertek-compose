"""Offline validation of private static DNS inventory and Cloudflare drift."""

import json
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from cloudflare_static_dns import compare_static_dns, load_inventory

HOST = "device.ygg.nu"
ADDRESS = "10.4.20.10"
MAC = "aa:bb:cc:dd:ee:ff"


def inventory(hosts=None):
    """Construct only synthetic private-device fixtures."""
    return {
        "version": 1,
        "hosts": (
            hosts
            if hosts is not None
            else [{"hostname": HOST, "ipv4": ADDRESS, "mac": MAC}]
        ),
    }


def record(name=HOST, address=ADDRESS, kind="A", proxied=False):
    """Return a fake Cloudflare DNS record."""
    return {
        "name": name,
        "type": kind,
        "content": address,
        "proxied": proxied,
    }


class InventoryTests(unittest.TestCase):
    """Require explicit schema and safe static-only IPv4 addresses."""

    def load(self, contents, required=True):
        """Write and read a temporary private JSON source."""
        with TemporaryDirectory() as temporary:
            path = Path(temporary) / "static-hosts.json"
            path.write_text(json.dumps(contents))
            return load_inventory(path, required=required)

    def test_valid_file_does_not_publish_mac(self):
        """MAC metadata is permitted but absent from DNS comparison data."""
        self.assertEqual(self.load(inventory()), {HOST: ADDRESS})
        self.assertNotIn(MAC, str(compare_static_dns({HOST: ADDRESS}, [])))

    def test_description_is_preserved_in_source_but_not_audit_output(self):
        """Device model details remain private and do not change DNS semantics."""
        description = "Asus NUC 15 Pro (RNUC15CRKU500000I)"
        row = {
            "hostname": HOST,
            "ipv4": ADDRESS,
            "mac": MAC,
            "description": description,
        }
        expected = {HOST: ADDRESS}
        self.assertEqual(self.load(inventory([row])), expected)
        self.assertNotIn(description, str(expected))
        self.assertNotIn(description, str(compare_static_dns(expected, [])))

    def test_invalid_optional_descriptions_are_rejected(self):
        """Reject malformed metadata without disclosing it in errors."""
        for description in ("", "  ", 23, "line" + chr(10) + "break", "x" * 513):
            with self.subTest(description=type(description).__name__):
                row = {"hostname": HOST, "ipv4": ADDRESS, "description": description}
                with self.assertRaisesRegex(ValueError, "invalid optional description"):
                    self.load(inventory([row]))

    def test_optional_missing_file_and_required_missing_file(self):
        """A phased rollout is optional until the private merge is ready."""
        with TemporaryDirectory() as temporary:
            path = Path(temporary) / "not-configured.json"
            self.assertIsNone(load_inventory(path))
            with self.assertRaisesRegex(ValueError, "Required"):
                load_inventory(path, required=True)

    def test_duplicate_hostname_refused(self):
        """Never silently override a duplicate inventory entry."""
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            self.load(inventory([inventory()["hosts"][0]] * 2))

    def test_invalid_schema_and_ipv4_are_rejected(self):
        """Fail closed on invalid versions, public IPs and Docker addresses."""
        for candidate in (
            {"version": 2, "hosts": inventory()["hosts"]},
            {"version": 1, "hosts": []},
            inventory([{"hostname": HOST, "ipv4": "10.4.21.10"}]),
            inventory([{"hostname": HOST, "ipv4": "8.8.8.8"}]),
            inventory([{"hostname": HOST, "ipv4": "10.4.20.0"}]),
            inventory([{"hostname": "device.ebi.nu", "ipv4": ADDRESS}]),
            inventory([{"hostname": HOST, "ipv4": ADDRESS, "mac": "bad"}]),
            inventory([{"hostname": HOST, "ipv4": ADDRESS, "unknown": 4}]),
            inventory([{"hostname": HOST, "ipv4": "10.4.20.999"}]),
        ):
            with self.subTest(candidate=candidate), self.assertRaises(ValueError):
                self.load(candidate)

    def test_all_planned_27_allocation_boundaries_are_reserved(self):
        """A /23 LAN still reserves network/broadcast offsets for future /27s."""
        for base in range(0, 256, 32):
            for offset in (0, 31):
                address = f"10.4.20.{base + offset}"
                with self.subTest(address=address), self.assertRaises(ValueError):
                    self.load(inventory([{"hostname": HOST, "ipv4": address}]))

    def test_27_allocation_interiors_are_allowed(self):
        """Unassigned /27 segments remain valid for future static devices."""
        for last in (1, 30, 33, 62, 65, 94, 97, 126, 129, 158, 161, 190):
            address = f"10.4.20.{last}"
            with self.subTest(address=address):
                self.assertEqual(
                    self.load(inventory([{"hostname": HOST, "ipv4": address}])),
                    {HOST: address},
                )

    def test_invalid_json_rejected(self):
        """Do not continue the audit with an unreadable source."""
        with TemporaryDirectory() as temporary:
            path = Path(temporary) / "static-hosts.json"
            path.write_text("{broken")
            with self.assertRaises(ValueError):
                load_inventory(path)


class StaticDiffTests(unittest.TestCase):
    """No static DNS finding can become an automated write proposal."""

    def test_not_configured(self):
        """The existing controller continues normally before private rollout."""
        report = compare_static_dns(None, [])
        self.assertFalse(report["enabled"])
        self.assertEqual(report["counts"]["drift"], 0)

    def test_matching_unproxied_a_with_aaaa_and_unmanaged_records(self):
        """IPv6 and other non-inventory names remain completely unmanaged."""
        report = compare_static_dns(
            {HOST: ADDRESS},
            [
                record(),
                record(kind="AAAA", address="fd00::1"),
                record(name="other.ygg.nu", address="10.4.20.20"),
            ],
        )
        self.assertTrue(report["enabled"])
        self.assertEqual(report["counts"]["matched"], 1)
        self.assertEqual(report["counts"]["drift"], 0)
        self.assertEqual(report["findings"], [])

    def test_missing_and_wrong_ip(self):
        """Distinguish missing A records from stale IPv4 values."""
        missing = compare_static_dns({HOST: ADDRESS}, [])
        self.assertEqual(missing["findings"][0]["status"], "missing")
        changed = compare_static_dns({HOST: ADDRESS}, [record(address="10.4.20.11")])
        self.assertEqual(changed["findings"][0]["status"], "mismatch")
        self.assertEqual(changed["findings"][0]["actual"], "10.4.20.11")

    def test_conflicting_cname_duplicate_and_proxy(self):
        """Flag unsafe record shapes without changing any of them."""
        for records in (
            [record(kind="CNAME", address="example.com")],
            [record(), record()],
            [record(proxied=True)],
            [record(), record(kind="CNAME", address="example.com")],
        ):
            with self.subTest(records=records):
                report = compare_static_dns({HOST: ADDRESS}, records)
                self.assertEqual(report["findings"][0]["status"], "conflict")
                self.assertEqual(report["counts"]["drift"], 1)


if __name__ == "__main__":
    unittest.main()
