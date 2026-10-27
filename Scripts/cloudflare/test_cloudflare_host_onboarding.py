"""Offline tests for cloudflare-host-onboarding.py."""

import importlib.util
import json
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "onboarding", Path(__file__).with_name("cloudflare-host-onboarding.py")
)
if spec is None or spec.loader is None:
    raise ImportError("Unable to load cloudflare-host-onboarding.py")
onboarding = importlib.util.module_from_spec(spec)
spec.loader.exec_module(onboarding)


class OnboardingTests(unittest.TestCase):
    """Verify new hostname policy checks and ingress insertion order."""
    def labels(
        self, policies='["16079c5e-e6e7-469e-8df1-8a7e326d11d5"]', enabled="true"
    ):
        """Construct a labeled Docker container for discovery tests."""
        return [
            {
                "Name": "/example",
                "Config": {
                    "Labels": {
                        "traefik.enable": enabled,
                        "traefik.http.routers.example.rule": "Host(`example.ebi.nu`)",
                        "cf.access": "true",
                        "cf.access.policies": policies,
                    }
                },
            }
        ]

    def test_discover_valid(self):
        """Accept declared policy IDs for an enabled Traefik hostname."""
        policies = {"16079c5e-e6e7-469e-8df1-8a7e326d11d5"}
        hosts, errors = onboarding.discover(self.labels(), policies)
        self.assertEqual(
            hosts, {"example.ebi.nu": ["16079c5e-e6e7-469e-8df1-8a7e326d11d5"]}
        )
        self.assertEqual(errors, [])

    def test_unknown_policy_rejected(self):
        """Reject Access policy IDs that are not known."""
        _, errors = onboarding.discover(self.labels(), set())
        self.assertTrue(errors)

    def test_invalid_json_rejected(self):
        """Reject malformed JSON in policy labels."""
        _, errors = onboarding.discover(self.labels("not-json"), set())
        self.assertTrue(errors)

    def test_duplicate_policy_rejected(self):
        """Reject duplicate policy IDs."""
        policy = "16079c5e-e6e7-469e-8df1-8a7e326d11d5"
        _, errors = onboarding.discover(
            self.labels(json.dumps([policy, policy])), {policy}
        )
        self.assertTrue(errors)

    def test_ingress_precedes_fallback(self):
        """Add routes before the terminal 404 and avoid duplicates."""
        initial = """config = {
  ingress = [
      {
        hostname = "old.ebi.nu"
      },
      {
        service = "http_status:404"
      },
  ]
}"""
        proposed = onboarding.insert_ingress(initial, ["example.ebi.nu"])
        self.assertLess(
            proposed.index("example.ebi.nu"), proposed.index("http_status:404")
        )
        self.assertEqual(
            proposed, onboarding.insert_ingress(proposed, ["example.ebi.nu"])
        )

    def test_static_name_not_accepted(self):
        """Exclude internal ygg.nu names from public hostname onboarding."""
        self.assertIsNone(onboarding.HOST.fullmatch("example.ygg.nu"))


if __name__ == "__main__":
    unittest.main()
