"""Offline tests for source-only Cloudflare Access policy reconciliation."""

import tempfile
import unittest
from pathlib import Path

from cloudflare_policy_sync import plan_access_policy_updates, sync_access_policies

ONE = "11111111-1111-1111-1111-111111111111"
TWO = "22222222-2222-2222-2222-222222222222"
THREE = "33333333-3333-3333-3333-333333333333"

SAMPLE = f"""resource "cloudflare_zero_trust_access_application" "imported_grafana" {{
  account_id = "account"
  domain = "grafana.ebi.nu"
  name = "Grafana"
  type = "self_hosted"
  destinations = [{{
    type = "public"
    uri = "grafana.ebi.nu"
  }}]
  policies = [
    {{ id = "{ONE}", precedence = 1 }},
    {{ id = "{TWO}", precedence = 2 }}
  ]
  session_duration = "24h"
}}
"""


class PolicySyncTests(unittest.TestCase):
    """Ensure policy changes are minimal, deterministic and safe."""

    def test_unchanged(self):
        """Do not rewrite pre-existing policy assignments."""
        updated, changed, found = sync_access_policies(
            SAMPLE, {"grafana.ebi.nu": [ONE, TWO]}
        )
        self.assertEqual((updated, changed, found), (SAMPLE, [], {"grafana.ebi.nu"}))

    def test_policy_replacement_preserves_resource(self):
        """Replace only ordered policies, retaining unrelated settings."""
        updated, changed, found = sync_access_policies(
            SAMPLE, {"grafana.ebi.nu": [TWO, THREE]}
        )
        self.assertEqual(changed, ["grafana.ebi.nu"])
        self.assertEqual(found, {"grafana.ebi.nu"})
        self.assertIn('"imported_grafana"', updated)
        self.assertIn('session_duration = "24h"', updated)
        self.assertIn('type = "public"', updated)
        self.assertNotIn(ONE, updated)
        self.assertIn(f'{{ id = "{THREE}", precedence = 2 }}', updated)
        again, changes, _ = sync_access_policies(
            updated, {"grafana.ebi.nu": [TWO, THREE]}
        )
        self.assertEqual((again, changes), (updated, []))

    def test_other_hosts_untouched(self):
        """Do not edit an unrelated Access application."""
        result, changed, found = sync_access_policies(
            SAMPLE, {"other.ebi.nu": [THREE]}
        )
        self.assertEqual((result, changed, found), (SAMPLE, [], set()))

    def test_nonconsecutive_precedence_refused(self):
        """Reject malformed imported policy ordering."""
        corrupted = SAMPLE.replace("precedence = 2", "precedence = 5")
        with self.assertRaises(ValueError):
            sync_access_policies(corrupted, {"grafana.ebi.nu": [THREE]})

    def test_unknown_policy_structure_refused(self):
        """Reject unexpected HCL rather than rewriting it."""
        corrupted = SAMPLE.replace(
            f'{{ id = "{ONE}", precedence = 1 }}',
            "local.policy_reference",
        )
        with self.assertRaises(ValueError):
            sync_access_policies(corrupted, {"grafana.ebi.nu": [THREE]})

    def test_duplicate_hostname_refused(self):
        """Do not guess which imported resource owns a hostname."""
        with self.assertRaises(ValueError):
            sync_access_policies(SAMPLE + SAMPLE, {"grafana.ebi.nu": [THREE]})

    def test_planning_requires_matching_deployed_source(self):
        """Write plans only for files matching the deployed GitOps copy."""
        with tempfile.TemporaryDirectory() as directory:
            public = Path(directory) / "source"
            merged = Path(directory) / "deployed"
            public.mkdir()
            merged.mkdir()
            (public / "access-self-hosted.tf").write_text(SAMPLE)
            writes, changed = plan_access_policy_updates(
                public, merged, {"grafana.ebi.nu": [THREE]}
            )
            self.fail("Expected a missing deployment check") if writes else None
            self.assertEqual(changed, [])

    def test_planning_rejects_mismatched_deployed_source(self):
        """Reject plans if merged Terraform differs from its source."""
        with tempfile.TemporaryDirectory() as directory:
            public = Path(directory) / "source"
            merged = Path(directory) / "deployed"
            public.mkdir()
            merged.mkdir()
            (public / "access-self-hosted.tf").write_text(SAMPLE)
            (merged / "access-self-hosted.tf").write_text(SAMPLE + "\n# drift\n")
            with self.assertRaises(ValueError):
                plan_access_policy_updates(
                    public, merged, {"grafana.ebi.nu": [THREE]}
                )


if __name__ == "__main__":
    unittest.main()
