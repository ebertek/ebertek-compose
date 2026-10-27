#!/usr/bin/env python3
"""Safely propose/update existing Docker IPv4 A records in Cloudflare Terraform source.

No Cloudflare API calls, git commits, or Terraform apply actions are performed.
Only a Git source repository's dns-ygg.tf may be written; deployed ygg-compose is read-only.
"""

# Preserve established kebab-case CLI entry point filename.
# pylint: disable=invalid-name

import argparse
import difflib
import fcntl
import hashlib
import ipaddress
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

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


def main():  # pylint: disable=too-many-locals,too-many-branches,too-many-statements
    """Preview or explicitly write Terraform source DNS updates."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source",
        type=Path,
        help="Source dns-ygg.tf (autodetected in public/private repos)",
    )
    parser.add_argument(
        "--deployed",
        type=Path,
        default=Path.home() / "ygg-compose/terraform/cloudflare/dns-ygg.tf",
    )
    parser.add_argument(
        "--write-source",
        action="store_true",
        help="Explicitly write ONLY the source file",
    )
    parser.add_argument(
        "--add-static",
        nargs=2,
        metavar=("NAME.YGG.NU", "PRIVATE_IPV4"),
        help="Explicitly add a static LAN device A record (not Docker subnet)",
    )
    args = parser.parse_args()
    candidates = [
        Path.home() / name / "terraform/cloudflare/dns-ygg.tf"
        for name in ("ebertek-compose", "ebertek-compose-secrets")
    ]
    sources = [p for p in candidates if p.is_file()]
    if args.source:
        source = args.source.expanduser().resolve()
    elif len(sources) == 1:
        source = sources[0].resolve()
    else:
        raise ValueError(
            f"Expected exactly one source dns-ygg.tf, found {len(sources)}; use --source"
        )
    deployed = args.deployed.expanduser().resolve()
    if source == deployed or "ygg-compose" in source.parts:
        raise ValueError("Refusing to modify the merged ygg-compose checkout")
    if source.name != "dns-ygg.tf" or not source.is_file() or not deployed.is_file():
        raise ValueError("Source/deployed dns-ygg.tf files must exist")
    repo = subprocess.check_output(
        ["git", "-C", str(source.parent), "rev-parse", "--show-toplevel"], text=True
    ).strip()
    allowed = {
        (Path.home() / item).resolve()
        for item in ("ebertek-compose", "ebertek-compose-secrets")
    }
    if Path(repo).resolve() not in allowed:
        raise ValueError(
            "Source must belong to ebertek-compose or ebertek-compose-secrets"
        )
    # Serialize local writers. A separate lock survives atomic replacement of the file.
    lock = Path(repo) / ".git/cloudflare-source-sync.lock"
    with lock.open("a+") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        before = source.read_text()
        if deployed.read_text() != before:
            raise ValueError("Source and deployed DNS files differ; sync GitOps first")
        if subprocess.check_output(
            ["git", "-C", repo, "status", "--porcelain", "--", str(source)], text=True
        ).strip():
            raise ValueError(
                "Source dns-ygg.tf has uncommitted changes; refusing to modify"
            )
        if args.add_static:
            after = add_static(before, *args.add_static)
            changes = [("static", *args.add_static)]
        else:
            after, changes = update_existing(before, docker_ipv4())
        if after == before:
            print("No source changes required.")
            return
        diff = "".join(
            difflib.unified_diff(
                before.splitlines(True),
                after.splitlines(True),
                fromfile="source/dns-ygg.tf",
                tofile="proposed/dns-ygg.tf",
            )
        )
        print(diff)
        print(f"Proposed operations: {len(changes)}")
        if not args.write_source:
            print(
                "DRY RUN. Add --write-source to modify the detected source repository only."
            )
            return
        fd, tempname = tempfile.mkstemp(
            dir=source.parent, prefix=".dns-ygg.", suffix=".tmp"
        )
        try:
            with os.fdopen(fd, "w") as temp:
                temp.write(after)
                temp.flush()
                os.fsync(temp.fileno())
            os.chmod(tempname, source.stat().st_mode & 0o777)
            os.replace(tempname, source)
        finally:
            if os.path.exists(tempname):
                os.unlink(tempname)
        print(
            "Updated source only. Review git diff, commit/push, deploy merge, then plan/apply."
        )


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(2)
