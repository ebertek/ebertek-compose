#!/usr/bin/env python3
"""Offline tests for cloudflare-host-onboarding.py."""

import importlib.util
import json
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "onboarding", Path(__file__).with_name("cloudflare-host-onboarding.py")
)
onboarding = importlib.util.module_from_spec(spec)
spec.loader.exec_module(onboarding)


class OnboardingTests(unittest.TestCase):
    def labels(
        self, policies='["16079c5e-e6e7-469e-8df1-8a7e326d11d5"]', enabled="true"
    ):
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
        policies = {"16079c5e-e6e7-469e-8df1-8a7e326d11d5"}
        hosts, errors = onboarding.discover(self.labels(), policies)
        self.assertEqual(
            hosts, {"example.ebi.nu": ["16079c5e-e6e7-469e-8df1-8a7e326d11d5"]}
        )
        self.assertEqual(errors, [])

    def test_unknown_policy_rejected(self):
        _, errors = onboarding.discover(self.labels(), set())
        self.assertTrue(errors)

    def test_invalid_json_rejected(self):
        _, errors = onboarding.discover(self.labels("not-json"), set())
        self.assertTrue(errors)

    def test_duplicate_policy_rejected(self):
        policy = "16079c5e-e6e7-469e-8df1-8a7e326d11d5"
        _, errors = onboarding.discover(
            self.labels(json.dumps([policy, policy])), {policy}
        )
        self.assertTrue(errors)

    def test_ingress_precedes_fallback(self):
        initial = """config = {\n  ingress = [\n      {\n        hostname = "old.ebi.nu"\n      },\n      {\n        service = "http_status:404"\n      },\n  ]\n}"""
        proposed = onboarding.insert_ingress(initial, ["example.ebi.nu"])
        self.assertLess(
            proposed.index("example.ebi.nu"), proposed.index("http_status:404")
        )
        self.assertEqual(
            proposed, onboarding.insert_ingress(proposed, ["example.ebi.nu"])
        )

    def test_static_name_not_accepted(self):
        self.assertIsNone(onboarding.HOST.fullmatch("example.ygg.nu"))


if __name__ == "__main__":
    unittest.main()
