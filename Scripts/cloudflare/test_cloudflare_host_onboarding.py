"""Offline tests for cloudflare-host-onboarding.py."""

# pylint: disable=duplicate-code

import importlib.util
import io
import json
import sys
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

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

    def test_named_policies_resolve_to_existing_uuid(self):
        """Names and legacy UUIDs resolve to the same canonical ordered IDs."""
        identifier = "16079c5e-e6e7-469e-8df1-8a7e326d11d5"
        policies = [{"id": identifier, "name": "1-Public bypass"}]
        for declared in ('["1-Public bypass"]', f'["{identifier}"]'):
            with self.subTest(declared=declared):
                hosts, errors = onboarding.discover(self.labels(declared), policies)
                self.assertEqual(hosts, {"example.ebi.nu": [identifier]})
                self.assertFalse(errors)

    def test_named_policies_keep_order(self):
        """Resolve mixed labels without changing Access precedence."""
        first = "16079c5e-e6e7-469e-8df1-8a7e326d11d5"
        second = "792a444d-afde-4854-92d1-b0af5df74486"
        policies = [
            {"id": first, "name": "1-Public bypass"},
            {"id": second, "name": "2-Home"},
        ]
        hosts, errors = onboarding.discover(
            self.labels(json.dumps(["2-Home", first])), policies
        )
        self.assertEqual(hosts, {"example.ebi.nu": [second, first]})
        self.assertEqual(errors, [])

    def test_unknown_policy_name_is_rejected(self):
        """Unknown names must fail closed, not create unprotected apps."""
        hosts, errors = onboarding.discover(
            self.labels('["Renamed policy"]'),
            [{"id": "16079c5e-e6e7-469e-8df1-8a7e326d11d5", "name": "Known"}],
        )
        self.assertEqual(hosts, {})
        self.assertIn("unknown or ambiguous policy name", errors[0])

    def test_duplicate_policy_names_are_ambiguous(self):
        """Cloudflare does not promise unique policy names."""
        records = [
            {"id": "16079c5e-e6e7-469e-8df1-8a7e326d11d5", "name": "Same"},
            {"id": "792a444d-afde-4854-92d1-b0af5df74486", "name": "Same"},
        ]
        hosts, errors = onboarding.discover(self.labels('["Same"]'), records)
        self.assertEqual(hosts, {})
        self.assertIn("unknown or ambiguous policy name", errors[0])

    def test_duplicate_policy_assignment_via_name_and_uuid(self):
        """A mixed label cannot list the same reusable policy twice."""
        identifier = "16079c5e-e6e7-469e-8df1-8a7e326d11d5"
        declared = json.dumps(["Known", identifier])
        hosts, errors = onboarding.discover(
            self.labels(declared), [{"id": identifier, "name": "Known"}]
        )
        self.assertEqual(hosts, {})
        self.assertIn("duplicate policy assignment", errors[0])

    def test_malformed_ebi_host_rule_is_not_silently_ignored(self):
        """An unquoted Host rule must block onboarding rather than disappear."""
        containers = self.labels()
        containers[0]["Config"]["Labels"][
            "traefik.http.routers.example.rule"
        ] = "Host(example.ebi.nu)"
        hosts, errors = onboarding.discover(
            containers, {"16079c5e-e6e7-469e-8df1-8a7e326d11d5"}
        )
        self.assertEqual(hosts, {})
        self.assertEqual(len(errors), 1)
        self.assertIn("malformed Traefik Host()", errors[0])

    def test_double_quoted_host_rule_is_valid(self):
        """Traefik also accepts double-quoted Host arguments."""
        containers = self.labels()
        containers[0]["Config"]["Labels"][
            "traefik.http.routers.example.rule"
        ] = 'Host("example.ebi.nu")'
        hosts, errors = onboarding.discover(
            containers, {"16079c5e-e6e7-469e-8df1-8a7e326d11d5"}
        )
        self.assertEqual(
            hosts, {"example.ebi.nu": ["16079c5e-e6e7-469e-8df1-8a7e326d11d5"]}
        )
        self.assertEqual(errors, [])

    def test_mixed_valid_and_malformed_ebi_host_rules_fail_closed(self):
        """Partially parsed multi-host rules must not permit writes."""
        containers = self.labels()
        containers[0]["Config"]["Labels"][
            "traefik.http.routers.example.rule"
        ] = "Host(`example.ebi.nu`) || Host(unpackerr.ebi.nu)"
        _, errors = onboarding.discover(
            containers, {"16079c5e-e6e7-469e-8df1-8a7e326d11d5"}
        )
        self.assertEqual(len(errors), 1)
        self.assertIn("malformed Traefik Host()", errors[0])

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

    def test_compose_inventory_reads_source_labels(self):
        """Discover hostnames from Compose source before containers exist."""
        policy = "16079c5e-e6e7-469e-8df1-8a7e326d11d5"
        with TemporaryDirectory() as directory:
            root = Path(directory)
            project = root / "ygg-example"
            project.mkdir()
            (project / "compose.yaml").write_text(
                "services:\n"
                "  example:\n"
                "    labels:\n"
                '      traefik.enable: "true"\n'
                '      traefik.http.routers.example.rule: "Host(`example.ebi.nu`)"\n'
                '      cf.access: "true"\n'
                f"      cf.access.policies: '[\"{policy}\"]'\n"
            )
            containers = onboarding.compose_inventory(root)
            self.assertEqual(containers[0]["Name"], "ygg-example/compose.yaml/example")
            hosts, errors = onboarding.discover(containers, {policy})
            self.assertEqual(hosts, {"example.ebi.nu": [policy]})
            self.assertFalse(errors)

    def test_compose_inventory_does_not_require_access_on_other_domains(self):
        """Ignore public Nginx domains that are not managed under ebi.nu."""
        with TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "compose.yaml").write_text(
                "services:\n"
                "  nginx:\n"
                "    labels:\n"
                '      traefik.enable: "true"\n'
                '      traefik.http.routers.nginx.rule: "Host(`ebertek.com`)"\n'
            )
            hosts, errors = onboarding.discover(
                onboarding.compose_inventory(root), set()
            )
            self.assertEqual((hosts, errors), ({}, []))

    def test_compose_inventory_rejects_missing_access_on_new_host(self):
        """Fail closed for any ebi.nu hostname missing its Access labels."""
        with TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "compose.yaml").write_text(
                "services:\n"
                "  new-app:\n"
                "    labels:\n"
                '      traefik.enable: "true"\n'
                '      traefik.http.routers.new.rule: "Host(`new.ebi.nu`)"\n'
            )
            hosts, errors = onboarding.discover(
                onboarding.compose_inventory(root), set()
            )
            self.assertEqual(hosts, {})
            self.assertEqual(len(errors), 1)
            self.assertIn("missing cf.access", errors[0])

    def test_merged_runtime_produces_public_and_private_source_plan(self):
        """Plan a new hostname from merged-only files without modifying them."""
        policy = "16079c5e-e6e7-469e-8df1-8a7e326d11d5"
        tick = chr(96)
        with TemporaryDirectory() as directory:
            root = Path(directory) / "ygg-compose"
            root.mkdir()
            tf = root / "terraform/cloudflare"
            tf.mkdir(parents=True)
            (root / "compose.yaml").write_text(
                "services:\n"
                "  example:\n"
                "    labels:\n"
                '      traefik.enable: "true"\n'
                f'      traefik.http.routers.example.rule: "Host({tick}new.ebi.nu{tick})"\n'
                '      cf.access: "true"\n'
                f"      cf.access.policies: '[\"{policy}\"]'\n"
            )
            (tf / "access-policies.tf").write_text(f'  id = "{policy}"\n')
            (tf / "access-self-hosted.tf").write_text(
                'resource "cloudflare_zero_trust_access_application" "existing" {\n'
                '  account_id = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"\n'
                '  domain = "existing.ebi.nu"\n'
                '  type = "self_hosted"\n'
                "  policies = [\n"
                f'    {{ id = "{policy}", precedence = 1 }}\n'
                "  ]\n"
                "}\n"
            )
            (tf / "dns-ebi.tf").write_text(
                'resource "cloudflare_dns_record" "existing" {\n'
                '  zone_id = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"\n'
                '  name = "existing.ebi.nu"\n'
                '  content = "52acd579-76f3-4b52-bec4-8c505258a7b1.cfargotunnel.com"\n'
                '  type = "CNAME"\n'
                "}\n"
            )
            tunnel = (
                "ingress = [\n"
                "      {\n"
                '        hostname = "existing.ebi.nu"\n'
                '        service = "https://traefik.ygg.nu:443"\n'
                "      },\n"
                "      {\n"
                '        service = "http_status:404"\n'
                "      },\n"
                "]\n"
            )
            (tf / "tunnel-config.tf").write_text(tunnel)
            output = Path(directory) / "plans/cloudflare.json"
            with patch.object(
                sys,
                "argv",
                [
                    "cloudflare-host-onboarding.py",
                    "--root",
                    str(root),
                    "--output-plan",
                    str(output),
                ],
            ), redirect_stdout(io.StringIO()):
                onboarding.main()
            proposals = json.loads(output.read_text())["files"]
            self.assertEqual(len(proposals), 3)
            self.assertEqual(
                {entry["path"] for entry in proposals},
                {
                    "terraform/cloudflare/access-auto.tf",
                    "terraform/cloudflare/dns-ebi-auto.tf",
                    "terraform/cloudflare/tunnel-config.tf",
                },
            )
            tunnel_plan = next(
                item for item in proposals if item["path"].endswith("tunnel-config.tf")
            )
            self.assertEqual(
                tunnel_plan["repository"],
                "ebertek/ebertek-compose-secrets",
            )
            self.assertIn('hostname = "new.ebi.nu"', tunnel_plan["content"])
            self.assertEqual((tf / "tunnel-config.tf").read_text(), tunnel)
            self.assertFalse((tf / "access-auto.tf").exists())
            self.assertFalse((tf / "dns-ebi-auto.tf").exists())

    def test_static_name_not_accepted(self):
        """Exclude internal ygg.nu names from public hostname onboarding."""
        self.assertIsNone(onboarding.HOST.fullmatch("example.ygg.nu"))


if __name__ == "__main__":
    unittest.main()
