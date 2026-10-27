#!/usr/bin/env python3
"""Plan Cloudflare hostname and Access changes from the merged GitOps checkout.

The controller reads only ygg-compose and never edits that checkout.
An optional JSON plan routes proposed updates to their original GitHub repos.
Applying changes to GitHub or Cloudflare belongs to a separate gated runner.
"""

# Reused HCL parsing is intentional; preserve established kebab-case CLI name.
# pylint: disable=invalid-name,duplicate-code

import argparse
import difflib
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

from cloudflare_policy_sync import plan_access_policy_updates
from cloudflare_source_plan import make_change, output_plan

HOST = re.compile(r"^([a-z0-9](?:[a-z0-9-]*[a-z0-9])?)\.ebi\.nu$")
RULE = re.compile(r"^traefik\.http\.routers\.[^.]+\.rule$")
HOST_RULE = re.compile(r"Host\(\s*`([^`]+)`\s*\)")
UUID = re.compile(r"^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$")
RESOURCE = re.compile(
    r'(?m)^resource "cloudflare_(?:dns_record|zero_trust_access_application)"'
)


def compose_inventory(root):  # pylint: disable=too-many-locals,too-many-branches
    """Inspect source Compose services without requiring running containers."""
    try:
        from ruamel.yaml import YAML  # pylint: disable=import-outside-toplevel
    except ImportError as exc:
        raise RuntimeError("Install ruamel.yaml to read Compose source") from exc

    paths = sorted(set(root.rglob("compose.yaml")) | set(root.rglob("compose.yml")))
    if not paths:
        raise ValueError(f"No Compose files found under {root}")

    parser = YAML(typ="safe")
    containers = []
    for path in paths:
        document = parser.load(path.read_text())
        if not isinstance(document, dict):
            raise TypeError(f"Invalid Compose document: {path}")
        services = document.get("services")
        if services is None:
            continue
        if not isinstance(services, dict):
            raise TypeError(f"Invalid Compose services mapping: {path}")
        for service, config in services.items():
            if not isinstance(config, dict):
                raise TypeError(f"Invalid Compose service {service}: {path}")
            raw_labels = config.get("labels") or {}
            if isinstance(raw_labels, dict):
                labels = {str(key): str(value) for key, value in raw_labels.items()}
            elif isinstance(raw_labels, list):
                labels = {}
                for label in raw_labels:
                    if not isinstance(label, str) or "=" not in label:
                        raise ValueError(
                            f"Malformed Compose label in {path}: {service}"
                        )
                    key, value = label.split("=", 1)
                    if key in labels:
                        raise ValueError(f"Duplicate Compose label {key} in {path}")
                    labels[key] = value
            else:
                raise TypeError(f"Invalid Compose labels for {service}: {path}")
            containers.append(
                {
                    "Name": f"{path.relative_to(root)}/{service}",
                    "Config": {"Labels": labels},
                }
            )
    return containers


def discover(containers, known_policies):  # pylint: disable=too-many-branches
    """Validate policy declarations for Traefik-enabled Compose services."""
    result = {}
    errors = []
    for container in containers:
        labels = container.get("Config", {}).get("Labels") or {}
        if str(labels.get("traefik.enable", "")).lower() != "true":
            continue
        names = set()
        for key, rule in labels.items():
            if RULE.fullmatch(key):
                names.update(HOST_RULE.findall(str(rule)))
        if not names:
            continue
        ebi = {v.lower() for v in names if v.lower().endswith(".ebi.nu")}
        if not ebi:
            continue
        name = container.get("Name", "").lstrip("/")
        raw = labels.get("cf.access.policies")
        if labels.get("cf.access") != "true" or not raw:
            errors.append(f"{name}: missing cf.access=true or cf.access.policies")
            continue
        try:
            ids = json.loads(raw)
            if (
                not isinstance(ids, list)
                or not ids
                or not all(isinstance(v, str) and UUID.fullmatch(v) for v in ids)
            ):
                raise ValueError("expected nonempty JSON list of UUIDs")
            if len(ids) != len(set(ids)) or not set(ids).issubset(known_policies):
                raise ValueError("duplicate or unknown policy ID")
        except (ValueError, TypeError) as exc:
            errors.append(f"{name}: invalid cf.access.policies: {exc}")
            continue
        for hostname in sorted(ebi):
            if not HOST.fullmatch(hostname):
                errors.append(f"{name}: unsupported hostname {hostname}")
            elif hostname in result and result[hostname] != ids:
                errors.append(f"{hostname}: conflicting policy assignments")
            else:
                result[hostname] = ids
    return result, errors


def existing_hosts(root, kind):
    """Collect already declared access applications or DNS hostnames."""
    text = "\n".join(f.read_text() for f in root.glob("*.tf"))
    if kind == "access":
        return set(re.findall(r'(?m)^\s*domain\s*=\s*"([^"\n]+\.ebi\.nu)"', text))
    if kind == "dns":
        return set(re.findall(r'(?m)^\s*name\s*=\s*"([^"\n]+\.ebi\.nu)"', text))
    return set()


def singleton_regex(text, pattern, description):
    """Require exactly one unique Terraform setting matching a pattern."""
    matches = re.findall(pattern, text, re.MULTILINE)
    unique = set(matches)
    if len(unique) != 1:
        raise ValueError(f"Expected one {description}, found {len(unique)}")
    return next(iter(unique))


def access_block(host, ids, account):
    """Build a Terraform Access application with ordered policies."""
    slug = HOST.fullmatch(host).group(1)
    ident = "auto_" + hashlib.sha256(host.encode()).hexdigest()[:16]
    policies = "\n".join(
        f'    {{ id = "{p}", precedence = {i} }},' for i, p in enumerate(ids, 1)
    )
    return f"""resource "cloudflare_zero_trust_access_application" "{ident}" {{
  account_id                = "{account}"
  name                      = "{slug}"
  domain                    = "{host}"
  type                      = "self_hosted"
  session_duration          = "24h"
  auto_redirect_to_identity = false
  destinations = [{{
    type = "public"
    uri  = "{host}"
  }}]
  policies = [
{policies}
  ]
}}
"""


def dns_block(host, zone, tunnel):
    """Build a proxied DNS CNAME pointing to the existing tunnel."""
    ident = "auto_" + hashlib.sha256(host.encode()).hexdigest()[:16]
    return f"""resource "cloudflare_dns_record" "{ident}" {{
  zone_id = "{zone}"
  name    = "{host}"
  type    = "CNAME"
  content = "{tunnel}"
  proxied = true
  ttl     = 1
}}
"""


def ingress_block(host):
    """Build a verified-TLS ingress entry for the hostname."""
    return f"""      {{
        hostname = "{host}"
        service  = "https://traefik.ygg.nu:443"
        origin_request = {{
          http2_origin  = true
          no_tls_verify = false
        }}
      }},
"""


def insert_ingress(text, hosts):
    """Insert new ingress entries before the terminal 404 fallback."""
    # Require one explicit fallback as the last tunnel route; insert immediately before it.
    anchor = re.compile(
        r'(?m)^\s*\{\s*\n\s*service\s*=\s*"http_status:404"\s*\n\s*\},?'
    )
    match = anchor.search(text)
    if not match or anchor.search(text, match.end()):
        raise ValueError(
            "Expected exactly one standalone http_status:404 tunnel fallback"
        )
    # Refuse duplicate hostnames across all ingress entries.
    existing = set(re.findall(r'(?m)^\s*hostname\s*=\s*"([^"\n]+)"', text))
    needed = sorted(set(hosts) - existing)
    if not needed:
        return text
    return (
        text[: match.start()]
        + "".join(ingress_block(host) for host in needed)
        + text[match.start() :]
    )


def render(before, addition):
    """Append generated resources without rewriting the existing HCL."""
    if not addition:
        return before
    return before.rstrip() + "\n\n" + addition if before.strip() else addition


def main():  # pylint: disable=too-many-locals,too-many-branches,too-many-statements
    """Inspect the merged checkout and optionally save a source-update plan."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root", type=Path, default=Path.home() / "ygg-compose",
        help="Merged GitOps checkout containing Compose and Terraform files",
    )
    parser.add_argument(
        "--output-plan", type=Path,
        help="Write a source-repository plan outside the merged checkout",
    )
    args = parser.parse_args()
    root = args.root.expanduser().resolve()
    merged = root / "terraform/cloudflare"
    if not merged.is_dir():
        raise ValueError(f"Missing merged Cloudflare configuration: {merged}")

    policy_data = (merged / "access-policies.tf").read_text()
    known = set(re.findall(r'(?m)^\s*id\s*=\s*"([0-9a-f-]{36})"', policy_data))
    # Existing assignments are valid policy identifiers, even when imported
    # reusable policy definitions don't expose their IDs in Terraform HCL.
    for path in merged.glob("access-*.tf"):
        if path.name != "access-policies.tf":
            known.update(
                re.findall(
                    r'\{\s*id\s*=\s*"([0-9a-f-]{36})"\s*,\s*precedence',
                    path.read_text(),
                )
            )
    hosts, errors = discover(compose_inventory(root), known)
    if errors:
        raise ValueError(
            "Label validation failed; no changes proposed:\n" + "\n".join(errors)
        )

    access_present = existing_hosts(merged, "access")
    dns_present = existing_hosts(merged, "dns")
    tunnel_path = merged / "tunnel-config.tf"
    tunnel_text = tunnel_path.read_text()
    ingress_present = set(
        re.findall(r'(?m)^\s*hostname\s*=\s*"([^"\n]+)"', tunnel_text)
    )
    new = sorted(
        host for host in hosts
        if host not in access_present
        or host not in dns_present
        or host not in ingress_present
    )
    policy_writes, changed_policies = plan_access_policy_updates(merged, hosts)
    if not new and not policy_writes:
        print(
            f"No new hostnames or policy changes. Inspected {len(hosts)} labeled hostnames."
        )
        return

    writes = dict(policy_writes)
    if new:
        sample_access = (merged / "access-self-hosted.tf").read_text()
        sample_dns = (merged / "dns-ebi.tf").read_text()
        account = singleton_regex(
            sample_access,
            r'^\s*account_id\s*=\s*"([0-9a-f]{32})"',
            "Access account_id",
        )
        zone = singleton_regex(
            sample_dns, r'^\s*zone_id\s*=\s*"([0-9a-f]{32})"',
            "ebi.nu zone_id",
        )
        tunnel = singleton_regex(
            sample_dns,
            r'^\s*content\s*=\s*"([0-9a-f-]{36}\.cfargotunnel\.com)"',
            "tunnel CNAME target",
        )
        for filename, present, factory in (
            ("access-auto.tf", access_present,
             lambda host: access_block(host, hosts[host], account)),
            ("dns-ebi-auto.tf", dns_present,
             lambda host: dns_block(host, zone, tunnel)),
        ):
            path = merged / filename
            before = path.read_text() if path.is_file() else None
            current = before or ""
            additions = "\n".join(
                factory(host) for host in new if host not in present
            )
            after = render(current, additions)
            if after != current:
                writes[path] = (before, after)

        updated_tunnel = insert_ingress(
            tunnel_text, [host for host in new if host not in ingress_present]
        )
        if updated_tunnel != tunnel_text:
            writes[tunnel_path] = (tunnel_text, updated_tunnel)

    proposals = []
    for path, (before, after) in sorted(writes.items()):
        plan = make_change(path.name, before, after)
        proposals.append(plan)
        print(f"Proposed: {plan['repository']} / {plan['path']}")
        if plan["repository"] == "ebertek/ebertek-compose":
            print(
                "".join(
                    difflib.unified_diff(
                        (before or "").splitlines(True),
                        after.splitlines(True),
                        fromfile=f"deployed/{path.name}",
                        tofile=f"proposed/{path.name}",
                    )
                )
            )
    print(
        f"New/incomplete hostnames: {len(new)}; "
        f"existing policy updates: {len(changed_policies)}; "
        f"source files to update: {len(proposals)}"
    )
    if args.output_plan:
        saved = output_plan(args.output_plan, root, proposals)
        print(f"Source plan saved: {saved}")
    else:
        print("DRY RUN. No files, Git repositories, or Cloudflare resources changed.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, TypeError, OSError, subprocess.CalledProcessError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(2)
