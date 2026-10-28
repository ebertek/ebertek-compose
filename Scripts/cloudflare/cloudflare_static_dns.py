"""Read-only, private-inventory audit for non-Docker ygg.nu A records.

MAC addresses, device descriptions, serials, purchase dates and ports are
private inventory metadata. They are never sent to Cloudflare or logged.
"""

import ipaddress
import json
import re
from collections import Counter
from datetime import date

from cloudflare_live_diff import DOCKER_NETWORK, index_records

STATIC_NETWORK = ipaddress.ip_network("10.4.20.0/24")
HOST = re.compile(r"^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.ygg\.nu$")
MAC = re.compile(r"^(?:[0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}$")
INVENTORY = "Scripts/cloudflare/static-hosts.json"
MAX_HOSTS = 256


def validate_metadata(entry, hostname):
    """Reject invalid optional metadata without exposing its contents."""
    for field, maximum in (("description", 512), ("serial_number", 256)):
        value = entry.get(field)
        if value is not None and (
            not isinstance(value, str)
            or not value.strip()
            or len(value) > maximum
            or any(ord(character) < 32 for character in value)
        ):
            raise ValueError(f"{hostname}: invalid optional {field}")

    purchased = entry.get("purchase_date")
    if purchased is not None:
        if not isinstance(purchased, str) or not re.fullmatch(
            r"[0-9]{4}-[0-9]{2}-[0-9]{2}", purchased
        ):
            raise ValueError(f"{hostname}: invalid optional purchase_date")
        try:
            date.fromisoformat(purchased)
        except ValueError as error:
            raise ValueError(f"{hostname}: invalid optional purchase_date") from error

    ports = entry.get("open_ports")
    if ports is not None and (
        not isinstance(ports, list)
        or any(
            not isinstance(port, int)
            or isinstance(port, bool)
            or not 1 <= port <= 65535
            for port in ports
        )
        or len(set(ports)) != len(ports)
    ):
        raise ValueError(f"{hostname}: invalid optional open_ports")


def validated_entry(entry, index):
    """Validate one inventory entry and return DNS-only data."""
    if not isinstance(entry, dict) or not {"hostname", "ipv4"} <= set(entry):
        raise ValueError(f"Static DNS entry {index} requires hostname and ipv4")
    if set(entry) - {
        "hostname",
        "ipv4",
        "mac",
        "description",
        "serial_number",
        "purchase_date",
        "open_ports",
    }:
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
    validate_metadata(entry, hostname)
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


def check_static_target(hostname, address):
    """Validate an A record target against the private allocation policy."""
    return validated_entry({"hostname": hostname, "ipv4": address}, "DNS write")


def plan_static_dns(wanted, records):
    """Propose create/update for unambiguous active static A records only.

    Conflicts (including proxied A and CNAME) are never made writable.
    Existing records pointing outside the static address region are protected.
    """
    if wanted is None:
        return []
    from cloudflare_api import IDENTIFIER  # pylint: disable=import-outside-toplevel

    index = index_records(records, "name")
    actions = []
    for finding in compare_static_dns(wanted, records)["findings"]:
        hostname = finding["hostname"]
        if finding["status"] == "missing":
            actions.append(
                {
                    "kind": "create_static_dns_a",
                    "hostname": hostname,
                    "content": wanted[hostname],
                }
            )
        elif finding["status"] == "mismatch":
            matched = [
                item
                for item in index.get(hostname, [])
                if item.get("type") in {"A", "CNAME"}
            ]
            record = matched[0]
            previous = record.get("content")
            record_id = record.get("id")
            try:
                existing = ipaddress.IPv4Address(previous)
            except (ValueError, TypeError):
                continue
            if (
                existing not in STATIC_NETWORK
                or not isinstance(record_id, str)
                or not IDENTIFIER.fullmatch(record_id)
            ):
                continue
            actions.append(
                {
                    "kind": "update_static_dns_a",
                    "hostname": hostname,
                    "record_id": record_id,
                    "before": previous,
                    "content": wanted[hostname],
                }
            )
    return actions


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
