#!/usr/bin/env python3
"""Annotate Compose services with existing Cloudflare Access policies.

Read local Terraform state and Traefik labels. Preview by default; --write
backs up changed Compose files before inserting labels. No API or deploy calls.
Requires ruamel.yaml.
"""

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path
from urllib.parse import urlsplit

try:
    from ruamel.yaml import YAML
    from ruamel.yaml.error import YAMLError
except ImportError:
    sys.exit("Install ruamel.yaml in a virtual environment before running this script")

HOST_RE = re.compile(r"Host\(\s*`([^`]+)`\s*\)")
RULE_RE = re.compile(r"^traefik\.http\.routers\.[^.]+\.rule$")
SERVICE_RE = re.compile(r"^([^:]+):(?:\s|$)")


def attrs_of(state, kind):
    """Yield Terraform resource instance attributes of the requested type."""
    for resource in state.get("resources", []):
        if resource.get("type") == kind:
            for instance in resource.get("instances", []):
                attributes = instance.get("attributes")
                if isinstance(attributes, dict):
                    yield attributes


def host(value):
    """Normalize a host or URI to a DNS hostname, if recognizable."""
    if not isinstance(value, str) or not value.strip():
        return None
    value = value.strip().lower().rstrip(".")
    if "://" in value:
        value = urlsplit(value).hostname or ""
    else:
        value = value.split("/", 1)[0].split(":", 1)[0]
    return value if re.fullmatch(r"[a-z0-9.-]+", value) else None


def app_hosts(attrs):
    """Collect the hostnames exposed by an imported Access application."""
    found = set()
    for field in ("domain", "self_hosted_domain"):
        if val := host(attrs.get(field)):
            found.add(val)
    for item in attrs.get("destinations") or []:
        if isinstance(item, dict):
            for field in ("uri", "domain"):
                if val := host(item.get(field)):
                    found.add(val)
    return found


def ordered_policy_ids(app):
    """Return policy IDs sorted by precedence, or a validation failure."""
    policies = app.get("policies") or []
    if not isinstance(policies, list) or not policies:
        return None, "no attached policies"
    ordered = []
    for item in policies:
        if not isinstance(item, dict):
            return None, "invalid policy entry"
        ident = item.get("id") or item.get("policy_id")
        priority = item.get("precedence")
        if not ident or not isinstance(priority, int) or isinstance(priority, bool):
            return None, "policy missing id or integer precedence"
        ordered.append((priority, str(ident)))
    if len({priority for priority, _ in ordered}) != len(ordered):
        return None, "duplicate policy precedence"
    if len({ident for _, ident in ordered}) != len(ordered):
        return None, "duplicate policy ID"
    return [ident for _, ident in sorted(ordered)], None


def labels_dict(value):
    """Normalize Compose mapping- or list-style labels to a dictionary."""
    if isinstance(value, dict):
        return {str(key): str(label) for key, label in value.items()}
    if isinstance(value, list):
        return {
            item.split("=", 1)[0]: item.split("=", 1)[1]
            for item in value
            if isinstance(item, str) and "=" in item
        }
    return {}


def compose_hosts(labels):
    """Extract hostnames from Traefik router Host() rules."""
    return {
        name
        for key, value in labels.items()
        if RULE_RE.match(key)
        for raw in HOST_RE.findall(value)
        if (name := host(raw))
    }


def access_inventory(state):
    """Build policy and Access application indexes from Terraform state."""
    policies = {
        str(item["id"]): str(item["name"])
        for item in attrs_of(state, "cloudflare_zero_trust_access_policy")
        if item.get("id") and item.get("name")
    }
    applications = defaultdict(list)
    for app in attrs_of(state, "cloudflare_zero_trust_access_application"):
        ids, issue = ordered_policy_ids(app)
        for hostname in app_hosts(app):
            applications[hostname].append({"policy_ids": ids, "issue": issue})
    return policies, applications


def policy_for_hosts(hostnames, policies, applications):
    """Resolve a unique ordered policy list shared by every hostname."""
    issues = []
    assignments = []
    for hostname in sorted(hostnames):
        matches = applications.get(hostname, [])
        if len(matches) != 1:
            issues.append(f"{hostname}: {len(matches)} matching Access applications")
            continue
        app = matches[0]
        if app["issue"]:
            issues.append(f'{hostname}: {app["issue"]}')
            continue
        ids = app["policy_ids"]
        unknown = [ident for ident in ids if ident not in policies]
        if unknown:
            issues.append(
                f"{hostname}: {len(unknown)} policy IDs missing "
                "from imported reusable policies"
            )
            continue
        assignments.append(tuple(ids))
    if not issues and (
        not assignments or any(item != assignments[0] for item in assignments[1:])
    ):
        issues.append("hostnames have different ordered policy assignments")
    return (list(assignments[0]) if not issues else None), issues


def desired_labels(identifiers):
    """Build string-valued Compose labels retaining policy precedence."""
    return {
        "cf.access": "true",
        "cf.access.policies": json.dumps(identifiers, separators=(",", ":")),
    }


def eligible_labels(definition):
    """Return Traefik-enabled labels, or None for an ineligible service."""
    if not isinstance(definition, dict):
        return None
    labels = labels_dict(definition.get("labels"))
    return labels if labels.get("traefik.enable", "").lower() == "true" else None


def check_service(service, definition, rel, policies, applications):
    """Classify one service and return its optional proposed label edit."""
    labels = eligible_labels(definition)
    if labels is None:
        return "IGNORE", None
    hosts = compose_hosts(labels)
    if not hosts:
        return "IGNORE", None
    identifiers, issues = policy_for_hosts(hosts, policies, applications)
    if issues:
        print(
            f'SKIP {rel} / {service} [{", ".join(sorted(hosts))}]: {"; ".join(issues)}'
        )
        return "SKIP", None
    wanted = desired_labels(identifiers)
    current = {key: labels[key] for key in wanted if key in labels}
    if current == wanted:
        named = ", ".join(policies[ident] for ident in identifiers)
        print(f"EXISTS {rel} / {service} -> {named}")
        return "EXISTS", None
    if current:
        print(f"SKIP {rel} / {service}: conflicting existing labels {current}")
        return "SKIP", None
    named = ", ".join(policies[ident] for ident in identifiers)
    print(f'ADD {rel} / {service} [{", ".join(sorted(hosts))}] -> {named}')
    return "ADD", (service, wanted)


def apply_text_insert(text, service, additions):
    """Insert mapping-style labels with the repository's Prettier quoting."""
    lines = text.splitlines(keepends=True)
    in_services = False
    in_service = False
    label_seen = False
    for index in range(len(lines) + 1):
        line = lines[index] if index < len(lines) else ""
        stripped = line.strip()
        if index < len(lines) and (not stripped or stripped.startswith("#")):
            continue
        indent = len(line) - len(line.lstrip(" "))
        if label_seen and (index == len(lines) or indent <= 4):
            new = (
                f'      cf.access: "{additions["cf.access"]}"\n'
                f'      cf.access.policies: \'{additions["cf.access.policies"]}\'\n'
            )
            lines.insert(index, new)
            return "".join(lines)
        if indent == 0:
            in_services = stripped == "services:"
            in_service = False
        elif in_services and indent == 2 and SERVICE_RE.match(stripped):
            in_service = stripped.partition(":")[0].strip("\"'") == service
            label_seen = False
        elif in_service and indent == 4 and stripped == "labels:":
            label_seen = True
    raise ValueError(f"No mapping-style labels section for service {service!r}")


def write_changes(path, original, edits, yaml):
    """Validate edits and preserve an original backup before writing."""
    updated = original
    for service, additions in edits:
        updated = apply_text_insert(updated, service, additions)
    validated = yaml.load(updated)
    for service, additions in edits:
        actual = labels_dict(validated["services"][service].get("labels"))
        if any(actual.get(key) != val for key, val in additions.items()):
            raise RuntimeError(f"Validation failed for {path}, service {service}")
    backup = path.with_name(path.name + ".cf-labels.bak")
    if backup.exists():
        raise RuntimeError(f"Refusing to overwrite existing backup: {backup}")
    backup.write_text(original)
    path.write_text(updated)


def process_file(path, root, policies, applications, execution):
    """Examine one Compose document, optionally applying validated edits."""
    original = path.read_text()
    try:
        doc = execution[0].load(original)
    except YAMLError as exc:
        print(f"ERROR {path}: invalid YAML: {exc}")
        return 0, 0, 1
    if not isinstance(doc, dict) or not isinstance(doc.get("services"), dict):
        return 0, 0, 0
    counts = {"ADD": 0, "EXISTS": 0, "SKIP": 0}
    edits = []
    for service, definition in doc["services"].items():
        result, edit = check_service(
            service, definition, path.relative_to(root), policies, applications
        )
        if result in counts:
            counts[result] += 1
        if edit:
            edits.append(edit)
    if execution[1] and edits:
        write_changes(path, original, edits, execution[0])
    return counts["ADD"], counts["EXISTS"], counts["SKIP"]


def main():
    """Load the inventory and report or apply labels to Compose files."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compose-root", required=True, type=Path)
    parser.add_argument("--state", required=True, type=Path)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()

    state = json.loads(args.state.read_text())
    policies, applications = access_inventory(state)
    print(
        f"Imported: {len(policies)} reusable policies; "
        f"{sum(map(len, applications.values()))} app-host mappings"
    )
    paths = sorted(
        set(args.compose_root.rglob("compose.yaml"))
        | set(args.compose_root.rglob("compose.yml"))
    )
    yaml = YAML(typ="safe")
    totals = [0, 0, 0]
    for path in paths:
        counts = process_file(
            path, args.compose_root, policies, applications, (yaml, args.write)
        )
        totals = [previous + value for previous, value in zip(totals, counts)]
    accepted, existing, skipped = totals
    mode = "WRITE" if args.write else "DRY RUN"
    print(
        f"\nSummary: {accepted} eligible additions, {existing} already labeled, "
        f"{skipped} need review; mode={mode}"
    )
    print("No containers were redeployed; no Cloudflare API calls were made.")


if __name__ == "__main__":
    main()
