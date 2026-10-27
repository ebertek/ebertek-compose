"""Unit tests for cloudflare-source-sync.py (no Docker/Cloudflare needed)."""

import importlib.util
import unittest
from pathlib import Path

path = Path(__file__).with_name("cloudflare-source-sync.py")
spec = importlib.util.spec_from_file_location("source_sync", path)
if spec is None or spec.loader is None:
    raise ImportError(f"Unable to load {path}")
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)

EXAMPLE = """resource "cloudflare_dns_record" "grafana_imported" {
  content = "10.4.21.82"
  name = "grafana.ygg.nu"
  type = "A"
  zone_id = "zone-demo"
  settings = {}
}
resource "cloudflare_dns_record" "pleiades_primary" {
  content = "10.4.21.1"
  name = "pleiades.ygg.nu"
  type = "A"
  zone_id = "zone-demo"
  settings = {}
}
resource "cloudflare_dns_record" "pleiades_secondary" {
  content = "10.4.20.20"
  name = "pleiades.ygg.nu"
  type = "A"
  zone_id = "zone-demo"
  settings = {}
}
"""


class SourceSyncTests(unittest.TestCase):
    """Verify DNS source changes are safe, unambiguous and idempotent."""
    def test_existing_single_a_changes_without_resource_rename(self):
        """Preserve the imported Terraform resource identifier on an IP change."""
        updated, changes = sync.update_existing(EXAMPLE, {"grafana": "10.4.21.99"})
        self.assertEqual(changes, [("grafana.ygg.nu", "10.4.21.82", "10.4.21.99")])
        self.assertIn('"grafana_imported"', updated)
        self.assertIn('content = "10.4.21.99"', updated)
        self.assertIn('content = "10.4.21.82"', EXAMPLE)

    def test_multi_a_host_untouched(self):
        """Never change a hostname with multiple A records."""
        updated, changes = sync.update_existing(EXAMPLE, {"pleiades": "10.4.21.42"})
        self.assertEqual((updated, changes), (EXAMPLE, []))

    def test_cross_subnet_existing_record_refused(self):
        """Reject changes when the existing record is not in Docker subnet."""
        with self.assertRaises(ValueError):
            sync.update_existing(
                EXAMPLE.replace("10.4.21.82", "10.4.20.82"),
                {"grafana": "10.4.21.55"},
            )

    def test_static_can_be_added_without_docker_collision(self):
        """Append a private static host without editing Docker records."""
        updated = sync.add_static(EXAMPLE, "new-sensor.ygg.nu", "10.4.20.177")
        self.assertIn('name     = "new-sensor.ygg.nu"', updated)
        self.assertIn('content  = "10.4.20.177"', updated)
        self.assertIn("proxied  = false", updated)

    def test_static_rejects_docker_subnet_and_duplicates(self):
        """Reject conflicting and Docker-owned static hostnames."""
        with self.assertRaises(ValueError):
            sync.add_static(EXAMPLE, "new-sensor.ygg.nu", "10.4.21.177")
        with self.assertRaises(ValueError):
            sync.add_static(EXAMPLE, "grafana.ygg.nu", "10.4.20.177")

    def test_idempotency(self):
        """Second reconciliation with the same address must be a no-op."""
        updated, _ = sync.update_existing(EXAMPLE, {"grafana": "10.4.21.99"})
        after, changes = sync.update_existing(updated, {"grafana": "10.4.21.99"})
        self.assertEqual((after, changes), (updated, []))


if __name__ == "__main__":
    unittest.main()
