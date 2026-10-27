"""Offline Cloudflare client and merged-runtime audit integration tests."""

import importlib.util
import io
import json
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch
from urllib.error import HTTPError

from cloudflare_api import CloudflareClient, CloudflareError

ACCOUNT = "a" * 32
ZONE = "b" * 32
POLICY = "11111111-1111-1111-1111-111111111111"
TUNNEL = "52acd579-76f3-4b52-bec4-8c505258a7b1"

spec = importlib.util.spec_from_file_location(
    "cloudflare_live", Path(__file__).with_name("cloudflare-live.py")
)
if spec is None or spec.loader is None:
    raise ImportError("Unable to load cloudflare-live.py")
live = importlib.util.module_from_spec(spec)
spec.loader.exec_module(live)


class ClientTests(unittest.TestCase):
    """Cloudflare API safety and pagination behavior."""

    def test_get_and_pagination(self):
        """Read all API pages and send the bearer token in headers only."""
        responses = [
            {
                "success": True,
                "result": [{"id": "one"}],
                "result_info": {"total_pages": 2},
            },
            {
                "success": True,
                "result": [{"id": "two"}],
                "result_info": {"total_pages": 2},
            },
        ]
        calls = []

        def fake_open(request, timeout):
            """Return a harmless fake API response."""
            self.assertEqual(timeout, 25)
            self.assertEqual(
                request.get_header("Authorization"), "Bearer dummy-token"
            )
            calls.append(request.full_url)
            return io.BytesIO(json.dumps(responses.pop(0)).encode())

        client = CloudflareClient("dummy-token")
        with patch("cloudflare_api.urlopen", side_effect=fake_open):
            results = client.pages("/accounts/example/access/policies")
        self.assertEqual([entry["id"] for entry in results], ["one", "two"])
        self.assertIn("page=2", calls[1])
        self.assertNotIn("dummy-token", str(calls))

    def test_api_error_does_not_echo_credentials(self):
        """Discard Cloudflare error bodies that could contain secrets."""
        error = HTTPError(
            "https://api.cloudflare.com/example", 403, "SECRET", {}, io.BytesIO()
        )
        with patch("cloudflare_api.urlopen", side_effect=error):
            with self.assertRaises(CloudflareError) as caught:
                CloudflareClient("secret-token").get("/accounts/example")
        message = str(caught.exception)
        self.assertNotIn("SECRET", message)
        self.assertNotIn("secret-token", message)
        self.assertIn("HTTP 403", message)

    def test_invalid_token_and_identifiers(self):
        """Reject requests with no token and malformed identifiers."""
        with self.assertRaises(ValueError):
            CloudflareClient("")
        with self.assertRaises(ValueError):
            CloudflareClient("test").list_dns("not-a-zone-id")


class FakeCloudflare:
    """A self-contained, entirely offline Cloudflare API snapshot."""

    def zone_id(self, name, account):
        """Resolve zones by their exact expected names."""
        assert account == ACCOUNT
        assert name in {"ebi.nu", "ygg.nu"}
        return ZONE

    def tunnel_id(self, account, name):
        """Find the correct existing Tunnel."""
        assert (account, name) == (ACCOUNT, "pleiades")
        return TUNNEL

    def list_policies(self, account):
        """Return a known reusable Access policy."""
        assert account == ACCOUNT
        return [{"id": POLICY, "name": "5-Keycloak"}]

    def list_applications(self, account):
        """Provide an existing protected application."""
        assert account == ACCOUNT
        return [
            {
                "id": "cccccccc-cccc-cccc-cccc-cccccccccccc",
                "type": "self_hosted",
                "domain": "example.ebi.nu",
                "policies": [{"id": POLICY, "precedence": 1}],
            }
        ]

    def list_dns(self, zone):
        """Provide a correctly routed Cloudflare record."""
        assert zone == ZONE
        return [
            {
                "name": "example.ebi.nu",
                "type": "CNAME",
                "content": TUNNEL + ".cfargotunnel.com",
                "proxied": True,
            }
        ]

    def tunnel_configuration(self, account, tunnel):
        """Return the pre-existing Tunnel ingress and fallback."""
        assert (account, tunnel) == (ACCOUNT, TUNNEL)
        return {
            "config": {
                "ingress": [
                    {
                        "hostname": "example.ebi.nu",
                        "service": "https://traefik.ygg.nu:443",
                    },
                    {"service": "http_status:404"},
                ]
            }
        }


class LiveIntegrationTests(unittest.TestCase):
    """Execute audit against a Compose fixture and fake live API."""

    def test_run_audit_reads_no_terraform(self):
        """One clean hostname requires no Terraform files or state."""
        with TemporaryDirectory() as directory:
            root = Path(directory)
            tick = chr(96)
            (root / "compose.yaml").write_text(
                "services:\n"
                "  example:\n"
                "    labels:\n"
                '      traefik.enable: "true"\n'
                f'      traefik.http.routers.example.rule: "Host({tick}example.ebi.nu{tick})"\n'
                '      cf.access: "true"\n'
                f"      cf.access.policies: '[\"{POLICY}\"]'\n"
            )
            settings = {
                "account_id": ACCOUNT,
                "ebi_zone": "ebi.nu",
                "ygg_zone": "ygg.nu",
                "tunnel_name": "pleiades",
            }
            report = live.run_audit(
                FakeCloudflare(), root, settings, skip_docker=True
            )
            self.assertEqual(report["counts"]["desired_hosts"], 1)
            self.assertEqual(report["actions"], [])
            self.assertEqual(report["blocked"], [])
            self.assertEqual(report["mode"], "READ_ONLY_LIVE_API")


if __name__ == "__main__":
    unittest.main()
