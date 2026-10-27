#!/usr/bin/env python3
"""Propose private ygg.nu DNS source changes from the merged GitOps checkout.

Read-only by default. An optional source plan targets the private GitHub repo;
this script never edits ygg-compose, Terraform state, or Cloudflare resources.
"""

# Preserve established kebab-case CLI entry point filename.
# pylint: disable=invalid-name,duplicate-code

import argparse
import difflib
import hashlib
import ipaddress
import json
import re
import subprocess
import sys
from pathlib import Path

from cloudflare_source_plan import make_change, output_plan

A_RESOURCE = re.compile(r'(?m)^resource\s+"cloudflare_dns_record"\s+"([^"\n]+)"\s*\{')
FIELD = re.compile(r'(?m)^(\s*)(name|type|content|zone_id)\s*=\s*"([^"\n]*)"\s*$')
VALID_HOST = re.compile(r"^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.ygg\.nu$")
DOCKER_SUBNET = ipaddress.ip_network("10.4.21.0/24")


def records(text):  # pylint: disable=too-many-locals,too-many-branches
    """Return resource metadata and offsets, with balanced HCL braces and quoted strings."""
    result = []
    for match in A_RESOURCE.finditer(text):
        start = match.end() - 1
        depth = 0
        in_string = False
        escaped = False
        end = None
        for pos in range(start, len(text)):
            char = text[pos]
            if in_string:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == '"':
                    in_string = False
            elif char == '"':
                in_string = True
            elif char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    end = pos + 1
                    break
        if end is None:
            raise ValueError(f"Unbalanced HCL resource {match.group(1)}")
        body_start = start + 1
        body = text[body_start : end - 1]
        # Only exact, unique, top-level attribute matches are accepted.
        fields = {}
        positions = {}
        for found in FIELD.finditer(body):
            key = found.group(2)
            if key in fields:
                raise ValueError(f"Duplicate {key} in resource {match.group(1)}")
            fields[key] = found.group(3)
            positions[key] = (body_start + found.start(3), body_start + found.end(3))
        result.append(
            {
                "id": match.group(1),
                "start": match.start(),
                "end": end,
                "fields": fields,
                "positions": positions,
            }
        )
    return result


def docker_ipv4():
    """Discover unique Docker-subnet addresses for running containers."""

    ids = subprocess.check_output(["docker", "ps", "-q"], text=True).split()
    if not ids:
        return {}
    data = json.loads(subprocess.check_output(["docker", "inspect", *ids], text=True))
    result = {}
    for container in data:
        name = container.get("Name", "").lstrip("/")
        if not name or not re.fullmatch(r"[a-z0-9][a-z0-9-]*", name):
            continue
        addresses = set()
        for network in (
            container.get("NetworkSettings", {}).get("Networks") or {}
        ).values():
            raw = network.get("IPAddress")
            if raw:
                ip = ipaddress.ip_address(raw)
                if ip in DOCKER_SUBNET:
                    addresses.add(str(ip))
        if len(addresses) == 1:
            result[name] = next(iter(addresses))
    return result


def update_existing(text, inventory):
    """Return modified HCL and proposed address changes; no creates/deletes."""
    by_hostname = {}
    for record in records(text):
        f = record["fields"]
        if f.get("type") == "A":
            by_hostname.setdefault(f.get("name"), []).append(record)
    replacements = []
    changes = []
    for container, ip in sorted(inventory.items()):
        hostname = f"{container}.ygg.nu"
        found = by_hostname.get(hostname, [])
        if len(found) != 1:
            continue  # Missing or multi-A: never guess ownership.
        record = found[0]
        old = record["fields"].get("content")
        if "content" not in record["positions"]:
            continue
        if old == ip:
            continue
        if old is None or ipaddress.ip_address(old) not in DOCKER_SUBNET:
            raise ValueError(f"Refusing non-Docker-subnet origin for {hostname}: {old}")
        replacements.append((*record["positions"]["content"], ip))
        changes.append((hostname, old, ip))
    for start, end, ip in sorted(replacements, reverse=True):
        text = text[:start] + ip + text[end:]
    return text, changes


def add_static(text, hostname, ip):
    """Append one explicitly requested static LAN A record, if unambiguous."""
    hostname = hostname.lower().rstrip(".")
    if not VALID_HOST.fullmatch(hostname):
        raise ValueError("Static name must be a one-label hostname under ygg.nu")
    address = ipaddress.ip_address(ip)
    if address.version != 4 or not address.is_private:
        raise ValueError("Static record requires a private IPv4 address")
    if address in DOCKER_SUBNET:
        raise ValueError("10.4.21.0/24 is Docker-managed; static adds are blocked")
    existing = records(text)
    if any(r["fields"].get("name") == hostname for r in existing):
        raise ValueError(f"Name already has an A record: {hostname}")
    # Fail if any record of any type owns the same name (do not create CNAME conflict).
    if re.search(r'(?m)^\s*name\s*=\s*"' + re.escape(hostname) + r'"\s*$', text):
        raise ValueError(f"Name already exists in dns-ygg.tf: {hostname}")
    zones = {r["fields"].get("zone_id") for r in existing if r["fields"].get("zone_id")}
    if len(zones) != 1:
        raise ValueError("Could not unambiguously establish existing ygg.nu zone_id")
    identifier = "static_" + hashlib.sha256(hostname.encode()).hexdigest()[:16]
    if any(r["id"] == identifier for r in existing):
        raise ValueError("Terraform resource identifier collision")
    block = (
        '\nresource "cloudflare_dns_record" "' + identifier + '" {\n'
        f'  name     = "{hostname}"\n'
        f'  content  = "{address}"\n'
        '  type     = "A"\n'
        "  ttl      = 1\n"
        "  proxied  = false\n"
        "  tags     = []\n"
        f'  zone_id  = "{next(iter(zones))}"\n'
        "  settings = {}\n"
        "}\n"
    )
    return text.rstrip("\n") + "\n" + block


def main():
    """Audit merged DNS A records and optionally export a GitHub source plan."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path.home() / "ygg-compose",
        help="Merged GitOps checkout containing the private DNS source",
    )
    parser.add_argument(
        "--output-plan",
        type=Path,
        help="Save a source-update plan outside the merged Git checkout",
    )
    parser.add_argument(
        "--add-static",
        nargs=2,
        metavar=("NAME.YGG.NU", "PRIVATE_IPV4"),
        help="Explicitly propose a static LAN device record (not Docker subnet)",
    )
    args = parser.parse_args()
    root = args.root.expanduser().resolve()
    source = root / "terraform/cloudflare/dns-ygg.tf"
    if not source.is_file():
        raise ValueError(f"Missing merged Cloudflare DNS configuration: {source}")
    before = source.read_text()
    if args.add_static:
        after = add_static(before, *args.add_static)
        changes = [("static", *args.add_static)]
    else:
        after, changes = update_existing(before, docker_ipv4())
    if after == before:
        print("No DNS source changes required.")
        return

    print(
        "".join(
            difflib.unified_diff(
                before.splitlines(True),
                after.splitlines(True),
                fromfile="deployed/dns-ygg.tf",
                tofile="proposed/dns-ygg.tf",
            )
        )
    )
    print(f"Proposed operations: {len(changes)}")
    proposal = make_change("dns-ygg.tf", before, after)
    print(f"Source target: {proposal['repository']} / {proposal['path']}")
    if args.output_plan:
        saved = output_plan(args.output_plan, root, [proposal])
        print(f"Source plan saved: {saved}")
    else:
        print("DRY RUN. No files, Git repositories, or Cloudflare resources changed.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(2)
