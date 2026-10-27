"""Offline tests for explicit, narrowly scoped Cloudflare writes."""

import copy
import unittest
from unittest.mock import patch

from cloudflare_guarded import (
    UnsafePlan,
    apply_actions,
    check_plan,
    fingerprint,
    preflight_compatibility,
)
from cloudflare_write_api import CloudflareWriter, policy_links

POLICY = "11111111-1111-1111-1111-111111111111"
TUNNEL = "52acd579-76f3-4b52-bec4-8c505258a7b1"
ACCOUNT = "a" * 32
ZONE = "b" * 32
CONTEXT = {"account": ACCOUNT, "ebi": ZONE, "ygg": ZONE, "tunnel": TUNNEL}
HOST = "new.ebi.nu"
TEMPLATE = "komodo.ebi.nu"


def report(*actions, blocked=None):
    """Build a minimal audit result for execution tests."""
    return {"actions": list(actions), "blocked": blocked or []}


def new_host_actions():
    """Return intentionally unordered operations for one hostname."""
    return report(
        {
            "kind": "create_dns_cname",
            "hostname": HOST,
            "content": TUNNEL + ".cfargotunnel.com",
            "policies": [POLICY],
        },
        {"kind": "add_tunnel_ingress", "hostname": HOST, "policies": [POLICY]},
        {
            "kind": "create_access_app",
            "hostname": HOST,
            "policies": [POLICY],
        },
    )


class FakeWriter:
    """In-memory stand-in for the narrowly scoped Cloudflare API."""

    def __init__(self):
        """Retain routes and records as detached mutable snapshots."""
        self.events = []
        self.apps = []
        self.dns = []
        self.policies = [{"id": POLICY}]
        self.configuration = {
            "warp-routing": {"enabled": True},
            "ingress": [
                {
                    "hostname": TEMPLATE,
                    "service": "https://traefik.ygg.nu:443",
                    "originRequest": {"http2Origin": True},
                },
                {"service": "http_status:404"},
            ]
        }
        self.private_record = {
            "id": "c" * 32,
            "name": "grafana.ygg.nu",
            "type": "A",
            "content": "10.4.21.5",
            "proxied": False,
        }

    def list_applications(self, account):
        """List current app snapshots."""
        assert account == ACCOUNT
        return copy.deepcopy(self.apps)

    def list_policies(self, account):
        """List reusable policy identifiers."""
        assert account == ACCOUNT
        return copy.deepcopy(self.policies)

    def get_application(self, account, app_id):
        """Resolve the full Access app."""
        assert account == ACCOUNT
        return copy.deepcopy(next(item for item in self.apps if item["id"] == app_id))

    def create_access_app(self, account, hostname, policies):
        """Create an Access app, retaining declared policy precedence."""
        self.events.append("access")
        assert account == ACCOUNT
        item = {
            "id": "d" * 32,
            "domain": hostname,
            "type": "self_hosted",
            "policies": policy_links(policies),
        }
        self.apps.append(item)
        return copy.deepcopy(item)

    def tunnel_configuration(self, account, tunnel):
        """Return the current complete remotely managed Tunnel config."""
        assert (account, tunnel) == (ACCOUNT, TUNNEL)
        return {"config": copy.deepcopy(self.configuration)}

    def put_tunnel_ingress(self, account, tunnel, config):
        """Record a complete Tunnel configuration replacement."""
        self.events.append("tunnel")
        assert (account, tunnel) == (ACCOUNT, TUNNEL)
        self.configuration = copy.deepcopy(config)

    def list_dns(self, zone):
        """Return current records from the public test zone."""
        assert zone == ZONE
        return copy.deepcopy(self.dns)

    def create_dns_cname(self, zone, hostname, target):
        """Create a proxied CNAME only after route verification."""
        assert zone == ZONE
        self.events.append("dns")
        self.dns.append(
            {
                "id": "e" * 32,
                "name": hostname,
                "type": "CNAME",
                "content": target,
                "proxied": True,
            }
        )

    def get_dns_record(self, zone, record_id):
        """Read a private-zone A record by its ID."""
        assert (zone, record_id) == (ZONE, "c" * 32)
        return copy.deepcopy(self.private_record)

    def patch_docker_a(self, zone, record_id, content):
        """Change the existing record without altering other settings."""
        self.events.append("docker_a")
        assert (zone, record_id) == (ZONE, "c" * 32)
        self.private_record["content"] = content


class GuardedTests(unittest.TestCase):
    """Ensure Cloudflare mutations cannot bypass declared safety checks."""

    def test_preflight_validates_live_template_without_writes(self):
        """Verify existing Tunnel, Access and DNS without mutating anything."""
        client = FakeWriter()
        client.apps = [
            {
                "id": "d" * 32,
                "domain": TEMPLATE,
                "type": "self_hosted",
                "policies": policy_links([POLICY]),
                "destinations": [{"type": "public", "uri": TEMPLATE}],
            }
        ]
        client.dns = [
            {
                "name": TEMPLATE,
                "type": "CNAME",
                "content": TUNNEL + ".cfargotunnel.com",
                "proxied": True,
            }
        ]
        result = preflight_compatibility(client, CONTEXT)
        self.assertEqual(result["trusted_template"], TEMPLATE)
        self.assertEqual(result["tunnel_routes"], 2)
        self.assertEqual(result["template_access_policies"], 1)
        self.assertTrue(result["template_cname_verified"])
        self.assertEqual(client.events, [])
        self.assertEqual(client.configuration["warp-routing"], {"enabled": True})

    def test_preflight_refuses_unknown_tunnel_fields(self):
        """Do not allow unknown top-level keys in a full Tunnel replacement."""
        client = FakeWriter()
        client.configuration["unexpected-option"] = {"enabled": True}
        with self.assertRaisesRegex(UnsafePlan, "unexpected-option"):
            preflight_compatibility(client, CONTEXT)
        with self.assertRaisesRegex(UnsafePlan, "unexpected-option"):
            apply_actions(client, new_host_actions(), CONTEXT)
        self.assertEqual(client.events, [])

    def test_put_preserves_warp_routing_verbatim(self):
        """Pass the complete remotely managed Tunnel config to Cloudflare."""
        client = CloudflareWriter("test-token")
        config = copy.deepcopy(FakeWriter().configuration)
        with patch.object(client, "_write", return_value={}) as sender:
            client.put_tunnel_ingress(ACCOUNT, TUNNEL, config)
        self.assertEqual(sender.call_args.args[0], "PUT")
        self.assertEqual(sender.call_args.args[2], {"config": config})
        self.assertEqual(config["warp-routing"], {"enabled": True})

    def test_invalid_warp_routing_is_refused(self):
        """Avoid replacing a Tunnel when warp-routing has an invalid shape."""
        client = CloudflareWriter("test-token")
        config = copy.deepcopy(FakeWriter().configuration)
        config["warp-routing"] = "invalid"
        with patch.object(client, "_write") as sender:
            with self.assertRaises(TypeError):
                client.put_tunnel_ingress(ACCOUNT, TUNNEL, config)
        sender.assert_not_called()

    def test_preflight_refuses_incompatible_tunnel_template(self):
        """Reject unexpected existing origin before any write."""
        client = FakeWriter()
        client.configuration["ingress"][0]["service"] = "http://unknown:9000"
        with self.assertRaises(UnsafePlan):
            preflight_compatibility(client, CONTEXT)
        self.assertEqual(client.events, [])

    def test_preflight_refuses_missing_access_application(self):
        """Reject missing trusted Access reference application."""
        client = FakeWriter()
        with self.assertRaises(UnsafePlan):
            preflight_compatibility(client, CONTEXT)
        self.assertEqual(client.events, [])

    def test_preflight_refuses_wrong_dns_target(self):
        """Do not trust an Access-protected hostname with conflicting DNS."""
        client = FakeWriter()
        client.apps = [
            {
                "id": "d" * 32,
                "domain": TEMPLATE,
                "type": "self_hosted",
                "policies": policy_links([POLICY]),
            }
        ]
        client.dns = [
            {
                "name": TEMPLATE,
                "type": "CNAME",
                "content": "other.cfargotunnel.com",
                "proxied": True,
            }
        ]
        with self.assertRaises(UnsafePlan):
            preflight_compatibility(client, CONTEXT)
        self.assertEqual(client.events, [])

    def test_empty_report_requires_no_action(self):
        """An already synchronized account produces an empty execution list."""
        client = FakeWriter()
        self.assertEqual(apply_actions(client, report(), CONTEXT), [])
        self.assertEqual(client.events, [])

    def test_unknown_policy_update_blocks_all_writes(self):
        """Never partially run a plan containing unsupported policy PUT."""
        actions = new_host_actions()["actions"]
        actions.append(
            {
                "kind": "update_access_policies",
                "hostname": "grafana.ebi.nu",
            }
        )
        with self.assertRaises(UnsafePlan):
            apply_actions(FakeWriter(), report(*actions), CONTEXT)

    def test_blocked_and_duplicate_actions_refused(self):
        """Reject blocked or duplicate mutations before contacting Cloudflare."""
        with self.assertRaises(UnsafePlan):
            check_plan(report(blocked=[{"hostname": HOST, "reason": "conflict"}]))
        candidate = new_host_actions()["actions"][0]
        with self.assertRaises(UnsafePlan):
            check_plan(report(candidate, candidate))

    def test_fingerprint_depends_on_plan_and_scope(self):
        """Approval must change with targets, resources or desired operations."""
        original = new_host_actions()
        key = fingerprint(original, CONTEXT)
        self.assertEqual(len(key), 16)
        self.assertEqual(key, fingerprint(original, CONTEXT))
        changed = {**CONTEXT, "ebi": "f" * 32}
        self.assertNotEqual(key, fingerprint(original, changed))
        self.assertNotEqual(key, fingerprint(report(), CONTEXT))

    def test_host_is_protected_before_tunnel_and_dns(self):
        """Access creation and verification precede publication."""
        client = FakeWriter()
        done = apply_actions(client, new_host_actions(), CONTEXT)
        self.assertEqual(
            [entry["kind"] for entry in done],
            ["create_access_app", "add_tunnel_ingress", "create_dns_cname"],
        )
        self.assertEqual(client.events, ["access", "tunnel", "dns"])
        ingress = client.configuration["ingress"]
        self.assertEqual(ingress[-1]["service"], "http_status:404")
        self.assertEqual(ingress[-2]["hostname"], HOST)
        self.assertEqual(ingress[-2]["originRequest"], {"http2Origin": True})
        self.assertEqual(ingress[0]["hostname"], TEMPLATE)
        self.assertEqual(client.configuration["warp-routing"], {"enabled": True})

    def test_resume_after_access_was_already_created(self):
        """Complete ingress and DNS safely after an interrupted first apply."""
        client = FakeWriter()
        client.apps = [
            {
                "id": "d" * 32,
                "domain": HOST,
                "type": "self_hosted",
                "policies": policy_links([POLICY]),
            }
        ]
        changes = new_host_actions()["actions"][:2]
        done = apply_actions(client, report(*changes), CONTEXT)
        self.assertEqual(
            [value["kind"] for value in done],
            ["add_tunnel_ingress", "create_dns_cname"],
        )
        self.assertEqual(client.events, ["tunnel", "dns"])

    def test_publish_dns_if_access_and_tunnel_already_exist(self):
        """Never require recreation of an existing, correctly protected host."""
        client = FakeWriter()
        client.apps = [
            {
                "id": "d" * 32,
                "domain": HOST,
                "type": "self_hosted",
                "policies": policy_links([POLICY]),
            }
        ]
        client.configuration["ingress"].insert(
            -1, {"hostname": HOST, "service": "https://traefik.ygg.nu:443"}
        )
        change = new_host_actions()["actions"][0]
        done = apply_actions(client, report(change), CONTEXT)
        self.assertEqual(done[0]["kind"], "create_dns_cname")
        self.assertEqual(client.events, ["dns"])

    def test_conflicting_access_app_fails_without_writes(self):
        """Do not recreate an existing Access application."""
        client = FakeWriter()
        client.apps = [
            {
                "id": "d" * 32,
                "domain": HOST,
                "type": "self_hosted",
                "policies": policy_links([POLICY]),
            }
        ]
        with self.assertRaises(UnsafePlan):
            apply_actions(client, new_host_actions(), CONTEXT)
        self.assertEqual(client.events, [])

    def test_incompatible_tunnel_template_blocks_before_create(self):
        """Fail before any mutation if the trusted route is absent."""
        client = FakeWriter()
        client.configuration["ingress"][0]["service"] = "http://unknown:8000"
        with self.assertRaises(UnsafePlan):
            apply_actions(client, new_host_actions(), CONTEXT)
        self.assertEqual(client.events, [])

    def test_docker_a_requires_live_container_match(self):
        """Do not update if the container changed address after approval."""
        client = FakeWriter()
        actions = report(
            {
                "kind": "update_docker_dns_a",
                "hostname": "grafana.ygg.nu",
                "record_id": "c" * 32,
                "before": "10.4.21.5",
                "content": "10.4.21.6",
            }
        )
        with self.assertRaises(UnsafePlan):
            apply_actions(
                client,
                actions,
                CONTEXT,
                docker_addresses=lambda: {"grafana": "10.4.21.7"},
            )
        self.assertEqual(client.events, [])
        done = apply_actions(
            client,
            actions,
            CONTEXT,
            docker_addresses=lambda: {"grafana": "10.4.21.6"},
        )
        self.assertEqual(len(done), 1)
        self.assertEqual(client.events, ["docker_a"])
        self.assertEqual(client.private_record["proxied"], False)

    def test_non_docker_existing_address_blocked(self):
        """Do not change static or non-Docker A records."""
        client = FakeWriter()
        client.private_record["content"] = "10.4.20.5"
        with self.assertRaises(UnsafePlan):
            apply_actions(
                client,
                report(
                    {
                        "kind": "update_docker_dns_a",
                        "hostname": "grafana.ygg.nu",
                        "record_id": "c" * 32,
                        "before": "10.4.20.5",
                        "content": "10.4.21.6",
                    }
                ),
                CONTEXT,
                docker_addresses=lambda: {"grafana": "10.4.21.6"},
            )
        self.assertEqual(client.events, [])

    def test_write_api_disallows_unknown_method(self):
        """Refuse DELETE and all unsupported HTTP method names."""
        client = CloudflareWriter("test-token")
        # pylint: disable=protected-access
        with self.assertRaises(ValueError):
            client._write("DELETE", "/accounts/a", {})
        # pylint: enable=protected-access

    def test_policy_links_are_ordered_and_unique(self):
        """Reusable policy references maintain explicit precedence."""
        self.assertEqual(policy_links([POLICY]), [{"id": POLICY, "precedence": 1}])
        with self.assertRaises(ValueError):
            policy_links([POLICY, POLICY])


if __name__ == "__main__":
    unittest.main()
