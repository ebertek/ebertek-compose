"""Read-only, private-inventory audit for non-Docker ygg.nu A records.

MAC addresses are validated as optional inventory metadata. They are never
sent to Cloudflare, included in audit output, or used to infer DNS ownership.
"""

import ipaddress
import json
import re
from collections import Counter

from cloudflare_live_diff import DOCKER_NETWORK, index_records

STATIC_NETWORK = ipaddress.ip_network("10.4.20.0/24")
HOST = re.compile(r"^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.ygg\.nu$")
MAC = re.compile(r"^(?:[0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}$")
INVENTORY = "Scripts/cloudflare/static-hosts.json"
MAX_HOSTS = 256


def validated_entry(entry, index):
    """Validate one inventory entry and return DNS-only data."""
    if not isinstance(entry, dict) or not {"hostname", "ipv4"} <= set(entry):
        raise ValueError(f"Static DNS entry {index} requires hostname and ipv4")
    if set(entry) - {"hostname", "ipv4", "mac"}:
        raise ValueError(f"Static DNS entry {index} has unknown fields")
    hostname = entry["hostname"]
    if not isinstance(hostname, str) or not HOST.fullmatch(hostname):
        raise ValueError(f"Static DNS entry {index} has invalid ygg.nu hostname")
    value = entry["ipv4"]
    if not isinstance(value, str):
        raise TypeError(f"{hostname}: invalid IPv4 address")
    try:
        address = ipaddress.IPv4Address(value)
    except ValueError as error:
        raise ValueError(f"{hostname}: invalid IPv4 address") from error
    allocation_group = ipaddress.ip_network(f"{address}/27", strict=False)
    edges = (allocation_group.network_address, allocation_group.broadcast_address)
    if (
        str(address) != value
        or address not in STATIC_NETWORK
        or address in edges
        or address in DOCKER_NETWORK
    ):
        raise ValueError(f"{hostname}: address is outside the static host subnet")
    mac = entry.get("mac")
    if mac is not None and (not isinstance(mac, str) or not MAC.fullmatch(mac)):
        raise ValueError(f"{hostname}: invalid optional MAC address")
    return hostname, value


def load_inventory(path, required=False):
    """Load a checked, nonempty static inventory, or None if not enabled."""
    if not path.is_file():
        if required:
            raise ValueError(f"Required static DNS inventory is absent: {path}")
        return None
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or set(data) != {"version", "hosts"}:
        raise ValueError("Static DNS inventory requires version and hosts")
    if (
        not isinstance(data["version"], int)
        or isinstance(data["version"], bool)
        or data["version"] != 1
    ):
        raise ValueError("Unsupported static DNS inventory version")
    entries = data["hosts"]
    if not isinstance(entries, list) or not 1 <= len(entries) <= MAX_HOSTS:
        raise ValueError("Static DNS inventory must contain 1-256 host entries")
    wanted = {}
    for index, entry in enumerate(entries, 1):
        hostname, value = validated_entry(entry, index)
        if hostname in wanted:
            raise ValueError(f"Duplicate static DNS hostname: {hostname}")
        wanted[hostname] = value
    return wanted


def compare_static_dns(wanted, records):
    """Report static IPv4 drift without proposing any Cloudflare mutations."""
    if wanted is None:
        return {
            "enabled": False,
            "counts": {"hosts": 0, "matched": 0, "drift": 0},
            "findings": [],
        }

    index = index_records(records, "name")
    findings = []
    matched = 0
    for hostname, expected in sorted(wanted.items()):
        matches = [
            record
            for record in index.get(hostname, [])
            if record.get("type") in {"A", "CNAME"}
        ]
        a_records = [record for record in matches if record.get("type") == "A"]
        if not matches:
            findings.append(
                {"hostname": hostname, "status": "missing", "expected": expected}
            )
            continue
        if len(matches) != 1 or len(a_records) != 1:
            findings.append(
                {
                    "hostname": hostname,
                    "status": "conflict",
                    "reason": "ambiguous A/CNAME records",
                }
            )
            continue
        record = a_records[0]
        if record.get("proxied") is not False:
            findings.append(
                {
                    "hostname": hostname,
                    "status": "conflict",
                    "reason": "static A is proxied",
                }
            )
        elif record.get("content") != expected:
            findings.append(
                {
                    "hostname": hostname,
                    "status": "mismatch",
                    "expected": expected,
                    "actual": record.get("content"),
                }
            )
        else:
            matched += 1

    status = Counter(finding["status"] for finding in findings)
    return {
        "enabled": True,
        "counts": {
            "hosts": len(wanted),
            "matched": matched,
            "missing": status["missing"],
            "mismatch": status["mismatch"],
            "conflict": status["conflict"],
            "drift": len(findings),
        },
        "findings": findings,
    }
