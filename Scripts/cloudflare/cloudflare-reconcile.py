#!/usr/bin/env python3
"""Read-only audit of Docker/Traefik against Terraform-managed Cloudflare DNS."""

# Preserve established kebab-case CLI entry point filename.
# pylint: disable=invalid-name

import argparse
import ipaddress
import json
import re
import subprocess
import sys
from pathlib import Path

HOST = re.compile(r'\bHost\s*\(\s*[`"\']([^`"\']+)[`"\']\s*\)')
RESOURCE = re.compile(
    r'\bresource\s+"(cloudflare_dns_record|'
    r'cloudflare_zero_trust_access_application)"\s+"[^"]+"\s*\{'
)
ASSIGN = re.compile(
    r'^\s*(name|domain|type|content|proxied)\s*=\s*("[^"]*"|true|false)\s*$', re.MULTILINE
)
INGRESS_HOST = re.compile(r'^\s*hostname\s*=\s*"([^"]+)"\s*$', re.MULTILINE)


def resources(text):
    """Extract brace-balanced Terraform resources, ignoring braces inside strings."""
    for match in RESOURCE.finditer(text):
        start = match.end() - 1
        depth, quoted, escaped = 0, False, False
        for pos in range(start, len(text)):
            char = text[pos]
            if quoted:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == '"':
                    quoted = False
            elif char == '"':
                quoted = True
            elif char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    yield match.group(1), text[start + 1 : pos]
                    break
        else:
            raise ValueError("Unterminated Terraform resource block")


def fields(body):
    """Extract string-like fields from an imported Terraform resource."""
    return {key: raw.strip('"') for key, raw in ASSIGN.findall(body)}


def docker_inventory():  # pylint: disable=too-many-locals
    """Read running Docker containers, their Traefik hosts and IPv4 addresses."""
    ids = subprocess.check_output(["docker", "ps", "-q"], text=True).split()
    if not ids:
        return set(), {}, []
    containers = json.loads(
        subprocess.check_output(["docker", "inspect", *ids], text=True)
    )
    hosts, ips, warnings = set(), {}, []
    for container in containers:
        cname = container.get("Name", "").lstrip("/")
        labels = container.get("Config", {}).get("Labels") or {}
        for key, value in labels.items():
            if key.startswith("traefik.http.routers.") and key.endswith(".rule"):
                found = HOST.findall(value)
                if not found and "Host(" in value:
                    warnings.append(
                        f"Unsupported Host rule: container={cname} label={key}"
                    )
                hosts.update(host.lower().rstrip(".") for host in found)
        networks = container.get("NetworkSettings", {}).get("Networks") or {}
        ipv4s = set()
        for network in networks.values():
            raw = network.get("IPAddress", "")
            if raw:
                address = ipaddress.ip_address(raw)
                if address.version == 4:
                    ipv4s.add(str(address))
        if ipv4s:
            ips[cname] = sorted(ipv4s)
    return hosts, ips, warnings


def audit(config):  # pylint: disable=too-many-locals,too-many-branches
    """Compare Docker inventory with source-backed Cloudflare records."""
    tf_files = sorted(config.glob("*.tf"))
    if not tf_files:
        raise ValueError("No Terraform .tf files found")
    dns, access, ingress = {}, set(), set()
    for path in tf_files:
        content = path.read_text()
        if "tunnel_cloudflared_config" in content:
            ingress.update(h.lower() for h in INGRESS_HOST.findall(content))
        for kind, body in resources(content):
            data = fields(body)
            if kind == "cloudflare_dns_record":
                name = data.get("name", "").lower()
                if name:
                    dns.setdefault(name, []).append(
                        {
                            "type": data.get("type"),
                            "content": data.get("content"),
                            "file": path.name,
                        }
                    )
            else:
                domain = data.get("domain", "").lower()
                if domain:
                    access.add(domain)
    if not dns or not access or not ingress:
        raise ValueError("Incomplete DNS, Access or ingress discovery")
    hosts, ips, warnings = docker_inventory()
    traefik = {h for h in hosts if h.endswith(".ebi.nu") and h.count(".") == 2}
    dns_names = set(dns)
    special = {"ucg.ebi.nu", "yggdrasil.ebi.nu"}
    orphan_dns = sorted(
        h
        for h, records in dns.items()
        if h.endswith(".ebi.nu")
        and h not in traefik | special
        and any(
            record["type"] == "CNAME"
            and (record["content"] or "").endswith(".cfargotunnel.com")
            for record in records
        )
    )

    # Explicit safety rule: infer ownership ONLY from an exact, single-A DNS name
    # matching a running container name. Never infer A record ownership from IP.
    matched, mismatches, missing, ambiguous = [], [], [], []
    for container, docker_ips in sorted(ips.items()):
        hostname = f"{container}.ygg.nu"
        records = [r for r in dns.get(hostname, []) if r["type"] == "A"]
        local_ips = [ip for ip in docker_ips if ipaddress.ip_address(ip).is_private]
        if not local_ips:
            continue
        if not records:
            missing.append(
                {"container": container, "name": hostname, "docker_ipv4": local_ips}
            )
            continue
        if len(records) != 1 or len(local_ips) != 1:
            ambiguous.append(
                {
                    "container": container,
                    "name": hostname,
                    "docker_ipv4": local_ips,
                    "cloudflare_a": [r["content"] for r in records],
                }
            )
            continue
        result = {
            "container": container,
            "name": hostname,
            "docker_ipv4": local_ips[0],
            "cloudflare_ipv4": records[0]["content"],
            "source": records[0]["file"],
        }
        if local_ips[0] != records[0]["content"]:
            mismatches.append(result)
        else:
            matched.append(result)

    # A records absent from running Docker cannot be considered obsolete:
    # they may belong to physical devices or intentionally stopped containers.
    unmatched_docker_network_records = sorted(
        (
            {"name": hostname, "ipv4": r["content"]}
            for hostname, records in dns.items()
            for r in records
            if hostname.endswith(".ygg.nu")
            and r["type"] == "A"
            and (r["content"] or "").startswith("10.4.21.")
            and hostname[:-7] not in ips
        ),
        key=lambda x: (x["name"], x["ipv4"]),
    )
    return {
        "mode": "READ_ONLY_DRY_RUN",
        "terraform_dir": str(config),
        "counts": {
            "docker_ebi_hosts": len(traefik),
            "terraform_access_all": len(access),
            "terraform_dns_all": len(dns),
            "tunnel_ingress_hosts": len(ingress),
            "docker_ipv4_dns_matched": len(matched),
            "docker_ipv4_dns_mismatched": len(mismatches),
        },
        "new_hosts_missing_dns_REVIEW_REQUIRED": sorted(traefik - dns_names),
        "docker_hosts_missing_access_REVIEW_REQUIRED": sorted(traefik - access),
        "docker_hosts_missing_tunnel_ingress": (
            [] if "*.ebi.nu" in ingress else sorted(traefik - ingress - special)
        ),
        "existing_tunnel_dns_not_on_running_docker_REVIEW_ONLY": orphan_dns,
        "docker_ipv4_dns_mismatches_REVIEW_REQUIRED": mismatches,
        "docker_ipv4_dns_missing_REVIEW_ONLY": missing,
        "docker_ipv4_dns_ambiguous_REVIEW_ONLY": ambiguous,
        "cloudflare_10_4_21_records_without_running_container_REVIEW_ONLY": (
            unmatched_docker_network_records
        ),
        "docker_ipv4_dns_matched": matched,
        "container_ipv4_inventory": ips,
        "warnings": warnings,
        "notes": [
            "No source files, merged files, Terraform state or Cloudflare resources were modified.",
            "Cloudflare DNS values are read from Terraform source, not live Cloudflare API.",
            "Container ownership is inferred only by exact container-name.ygg.nu matching.",
            "Multiple A records and multi-network containers are never automatically reconciled.",
            "Stopped containers and physical devices may appear as unmatched DNS entries.",
            "Access application existence is not proof of effective policy protection.",
        ],
    }


def main():
    """Run the audit and print a human-readable or JSON report."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--config", type=Path, default=Path.home() / "ygg-compose/terraform/cloudflare"
    )
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    if not args.config.is_dir():
        parser.error(f"Terraform configuration directory not found: {args.config}")
    report = audit(args.config)
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print("Cloudflare/Traefik + IPv4 reconciliation — READ ONLY")
        print("Counts:", json.dumps(report["counts"], sort_keys=True))
        for key in (
            "new_hosts_missing_dns_REVIEW_REQUIRED",
            "docker_hosts_missing_access_REVIEW_REQUIRED",
            "docker_hosts_missing_tunnel_ingress",
            "existing_tunnel_dns_not_on_running_docker_REVIEW_ONLY",
            "docker_ipv4_dns_mismatches_REVIEW_REQUIRED",
            "docker_ipv4_dns_missing_REVIEW_ONLY",
            "docker_ipv4_dns_ambiguous_REVIEW_ONLY",
            "cloudflare_10_4_21_records_without_running_container_REVIEW_ONLY",
            "warnings",
        ):
            items = report[key]
            print(f"\n{key} ({len(items)}):")
            for item in items:
                print(
                    "  -",
                    (
                        json.dumps(item, sort_keys=True)
                        if isinstance(item, dict)
                        else item
                    ),
                )
        print("\nNo changes made. Use --json for full matched and container inventory.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (
        OSError,
        subprocess.CalledProcessError,
        ValueError,
        json.JSONDecodeError,
    ) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(2)
