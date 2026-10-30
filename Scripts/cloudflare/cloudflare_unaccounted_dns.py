"""Read-only reporting of ygg.nu records without an inventory owner.

Findings are review hints only. Never add them to Cloudflare mutation plans.
"""

import re

NAME = re.compile(r"^[a-z0-9][a-z0-9-]*$")
ADDRESS_TYPES = frozenset({"A", "AAAA", "CNAME"})


def audit_unaccounted_dns(records, static_hosts, static_aliases, compose_services, running):
    """Find live subdomain records absent from static and Docker declarations.

    The zone apex is intentionally excluded: its records are managed separately.
    A service's Compose name counts even if its container is currently stopped.
    Alias declarations count as inventory ownership, not as desired CNAMEs.
    """
    if records is None or static_hosts is None:
        return {
            "enabled": False,
            "counts": {"records": 0, "hostnames": 0, "address_records": 0, "other_records": 0},
            "findings": [],
        }

    owned = set(static_hosts) | set(static_aliases)
    for service in compose_services:
        name = service.get("Name", "").rsplit("/", 1)[-1]
        if NAME.fullmatch(name):
            owned.add(name + ".ygg.nu")
        custom = service.get("ContainerName")
        if isinstance(custom, str) and NAME.fullmatch(custom):
            owned.add(custom + ".ygg.nu")
    for name in running:
        if NAME.fullmatch(name):
            owned.add(name + ".ygg.nu")

    findings = []
    for record in records:
        name = record.get("name")
        if not isinstance(name, str):
            continue
        name = name.lower().rstrip(".")
        if name == "ygg.nu" or not name.endswith(".ygg.nu") or name in owned:
            continue
        kind = record.get("type")
        kind = kind.upper() if isinstance(kind, str) else "UNKNOWN"
        category = "address" if kind in ADDRESS_TYPES else "other"
        finding = {"hostname": name, "type": kind, "category": category}
        if isinstance(record.get("proxied"), bool):
            finding["proxied"] = record["proxied"]
        # Do not print TXT/MX/SRV payloads or other potentially sensitive contents.
        content = record.get("content")
        if (
            category == "address"
            and isinstance(content, str)
            and len(content) <= 255
            and all(32 <= ord(char) <= 126 for char in content)
        ):
            finding["content"] = content
        findings.append(finding)
    findings.sort(key=lambda item: (item["hostname"], item["type"], item.get("content", "")))
    return {
        "enabled": True,
        "counts": {
            "records": len(findings),
            "hostnames": len({item["hostname"] for item in findings}),
            "address_records": sum(item["category"] == "address" for item in findings),
            "other_records": sum(item["category"] == "other" for item in findings),
        },
        "findings": findings,
    }
