#!/usr/bin/env python3
"""Generate Terraform for NEW cf.access-labeled Traefik applications.

Read-only by default. --write-source writes ONLY ebertek-compose source and
 ebertek-compose-secrets source; never the merged ygg-compose or Cloudflare API.
Existing resources are untouched. Deployment/apply is a separate gated step.
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

HOST = re.compile(r"^([a-z0-9](?:[a-z0-9-]*[a-z0-9])?)\.ebi\.nu$")
RULE = re.compile(r"^traefik\.http\.routers\.[^.]+\.rule$")
HOST_RULE = re.compile(r"Host\(\s*`([^`]+)`\s*\)")
UUID = re.compile(r"^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$")
RESOURCE = re.compile(
    r'(?m)^resource "cloudflare_(?:dns_record|zero_trust_access_application)"'
)


def inventory():
    """Inspect running Docker containers and return their metadata."""
    ids = subprocess.check_output(["docker", "ps", "-q"], text=True).split()
    if not ids:
        return []
    return json.loads(subprocess.check_output(["docker", "inspect", *ids], text=True))


def discover(containers, known_policies):  # pylint: disable=too-many-branches
    """Find valid hostname-to-policy declarations on Traefik containers."""
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
    return before.rstrip() + "\n\n" + addition if addition else before


def main():  # pylint: disable=too-many-locals,too-many-branches,too-many-statements
    """Generate and optionally write source-only Cloudflare Terraform changes."""
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--write-source", action="store_true")
    args = p.parse_args()
    home = Path.home()
    public = home / "ebertek-compose/terraform/cloudflare"
    private = home / "ebertek-compose-secrets/terraform/cloudflare"
    merged = home / "ygg-compose/terraform/cloudflare"
    if not all(v.is_dir() for v in (public, private, merged)):
        raise ValueError("Missing public/private/merged Cloudflare Terraform directory")
    policy_data = (merged / "access-policies.tf").read_text()
    policies = set(re.findall(r'(?m)^\s*id\s*=\s*"([0-9a-f-]{36})"', policy_data))
    # Imported reusable policy resources may have IDs only in state. Also permit IDs
    # that are ALREADY used by imported Access applications (verified baseline).
    for file in merged.glob("access-*.tf"):
        if file.name != "access-policies.tf":
            policies.update(
                re.findall(
                    r'\{\s*id\s*=\s*"([0-9a-f-]{36})"\s*,\s*precedence',
                    file.read_text(),
                )
            )
    hosts, errors = discover(inventory(), policies)
    if errors:
        raise ValueError(
            "Label validation failed; nothing written:\n" + "\n".join(errors)
        )
    access_present = existing_hosts(merged, "access")
    dns_present = existing_hosts(merged, "dns")
    tunnel_text = (private / "tunnel-config.tf").read_text()
    existing_ingress = set(
        re.findall(r'(?m)^\s*hostname\s*=\s*"([^"\n]+)"', tunnel_text)
    )
    new = sorted(
        host
        for host in hosts
        if host not in access_present
        or host not in dns_present
        or host not in existing_ingress
    )
    if not new:
        print(f"No new hostnames. Inspected {len(hosts)} labeled hostnames.")
        return
    sample_access = (merged / "access-self-hosted.tf").read_text()
    sample_dns = (merged / "dns-ebi.tf").read_text()
    account = singleton_regex(
        sample_access, r'^\s*account_id\s*=\s*"([0-9a-f]{32})"', "Access account_id"
    )
    zone = singleton_regex(
        sample_dns, r'^\s*zone_id\s*=\s*"([0-9a-f]{32})"', "ebi.nu zone_id"
    )
    tunnel = singleton_regex(
        sample_dns,
        r'^\s*content\s*=\s*"([0-9a-f-]{36}\.cfargotunnel\.com)"',
        "tunnel CNAME target",
    )
    # Each source should match the currently deployed equivalent before editing.
    writes = {}
    access_source = public / "access-auto.tf"
    dns_source = public / "dns-ebi-auto.tf"
    for path, filename, kind, factory in (
        (
            access_source,
            "access-auto.tf",
            "access",
            lambda h: access_block(h, hosts[h], account),
        ),
        (dns_source, "dns-ebi-auto.tf", "dns", lambda h: dns_block(h, zone, tunnel)),
    ):
        before = path.read_text() if path.exists() else ""
        deployed = merged / filename
        if deployed.exists() and deployed.read_text() != before:
            raise ValueError(f"GitOps deployed/source mismatch for {filename}")
        additions = "\n".join(
            factory(h)
            for h in new
            if h not in (access_present if kind == "access" else dns_present)
        )
        after = render(before, additions)
        if after != before:
            writes[path] = (before, after)
    source_tunnel = tunnel_text
    deployed_tunnel = (merged / "tunnel-config.tf").read_text()
    if source_tunnel != deployed_tunnel:
        raise ValueError("GitOps deployed/source mismatch for tunnel-config.tf")
    next_tunnel = insert_ingress(
        source_tunnel, [h for h in new if h not in existing_ingress]
    )
    if next_tunnel != source_tunnel:
        writes[private / "tunnel-config.tf"] = (source_tunnel, next_tunnel)
    for path, (before, after) in writes.items():
        print(
            "".join(
                difflib.unified_diff(
                    before.splitlines(True),
                    after.splitlines(True),
                    fromfile=str(path),
                    tofile=str(path) + " (proposed)",
                )
            )
        )
    print(
        f"New/incomplete hostname definitions: {len(new)}; files to change: {len(writes)}"
    )
    if not args.write_source:
        print(
            "DRY RUN; add --write-source to update SOURCE files only. "
            "No commits or Terraform apply."
        )
        return
    for path in writes:
        repo = (
            public.parent.parent
            if path.is_relative_to(public)
            else private.parent.parent
        )
        status = subprocess.check_output(
            ["git", "-C", str(repo), "status", "--porcelain", "--", str(path)],
            text=True,
        )
        if status.strip():
            raise ValueError(f"Source path already dirty: {path}")
    for path, (_, after) in writes.items():
        path.write_text(after)
    print(
        "Wrote source files. Validate/commit both source repos, merge GitOps, "
        "then run reviewed Terraform plan/apply."
    )


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(2)
