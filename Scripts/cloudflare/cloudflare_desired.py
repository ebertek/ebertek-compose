"""Discover desired Cloudflare applications from merged Compose source files."""

import json
import re

HOST = re.compile(r"^([a-z0-9](?:[a-z0-9-]*[a-z0-9])?)\.ebi\.nu$")
RULE = re.compile(r"^traefik\.http\.routers\.[^.]+\.rule$")
HOST_RULE = re.compile(r'Host\(\s*([`"])([^`"]+)\1\s*\)')
UUID = re.compile(r"^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$")


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


def router_hosts(labels, name):
    """Extract quoted Traefik Host rules and report unsupported ebi.nu syntax."""
    hosts = set()
    errors = []
    for key, rule in labels.items():
        if not RULE.fullmatch(key):
            continue
        expression = str(rule)
        matches = list(HOST_RULE.finditer(expression))
        hosts.update(match.group(2) for match in matches)
        if ".ebi.nu" in expression.lower() and (
            not matches or expression.count("Host(") != len(matches)
        ):
            errors.append(f"{name}: malformed Traefik Host() rule in {key}")
    return hosts, errors


def discover(containers, known_policies):  # pylint: disable=too-many-branches
    """Validate policy declarations for Traefik-enabled Compose services."""
    result = {}
    errors = []
    for container in containers:
        labels = container.get("Config", {}).get("Labels") or {}
        if str(labels.get("traefik.enable", "")).lower() != "true":
            continue
        name = container.get("Name", "").lstrip("/")
        names, router_errors = router_hosts(labels, name)
        errors.extend(router_errors)
        if not names:
            continue
        ebi = {v.lower() for v in names if v.lower().endswith(".ebi.nu")}
        if not ebi:
            continue
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
