#!/usr/bin/env python3
"""Annotate Compose services with existing Cloudflare Access policy assignments.

Reads local Terraform state and Traefik labels. Defaults to a read-only preview.
With --write, backs up each changed Compose file before inserting labels.
Does not call Cloudflare or deploy services. Requires ruamel.yaml.
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
except ImportError:
    sys.exit('Install ruamel.yaml in a virtual environment before running this script')

HOST_RE = re.compile(r'Host\(\s*`([^`]+)`\s*\)')
RULE_RE = re.compile(r'^traefik\.http\.routers\.[^.]+\.rule$')


def attrs_of(state, kind):
    for resource in state.get('resources', []):
        if resource.get('type') == kind:
            for instance in resource.get('instances', []):
                attributes = instance.get('attributes')
                if isinstance(attributes, dict):
                    yield attributes


def host(value):
    if not isinstance(value, str) or not value.strip():
        return None
    value = value.strip().lower().rstrip('.')
    if '://' in value:
        value = urlsplit(value).hostname or ''
    else:
        value = value.split('/', 1)[0].split(':', 1)[0]
    return value if re.fullmatch(r'[a-z0-9.-]+', value) else None


def app_hosts(attrs):
    found = set()
    for field in ('domain', 'self_hosted_domain'):
        if val := host(attrs.get(field)):
            found.add(val)
    for item in attrs.get('destinations') or []:
        if isinstance(item, dict):
            for field in ('uri', 'domain'):
                if val := host(item.get(field)):
                    found.add(val)
    return found


def ordered_policy_ids(app):
    policies = app.get('policies') or []
    if not isinstance(policies, list) or not policies:
        return None, 'no attached policies'
    ordered = []
    for item in policies:
        if not isinstance(item, dict):
            return None, 'invalid policy entry'
        ident = item.get('id') or item.get('policy_id')
        priority = item.get('precedence')
        if not ident or not isinstance(priority, int) or isinstance(priority, bool):
            return None, 'policy missing id or integer precedence'
        ordered.append((priority, str(ident)))
    if len({p for p, _ in ordered}) != len(ordered):
        return None, 'duplicate policy precedence'
    if len({ident for _, ident in ordered}) != len(ordered):
        return None, 'duplicate policy ID'
    return [ident for _, ident in sorted(ordered)], None


def labels_dict(value):
    if isinstance(value, dict):
        return {str(k): str(v) for k, v in value.items()}
    if isinstance(value, list):
        return {v.split('=', 1)[0]: v.split('=', 1)[1] for v in value if isinstance(v, str) and '=' in v}
    return {}


def apply_text_insert(text, service, additions):
    # Support existing mapping-style, 2-space-indented Compose services and labels.
    lines = text.splitlines(keepends=True)
    in_services = in_service = False
    label_seen = False
    for idx in range(len(lines) + 1):
        line = lines[idx] if idx < len(lines) else ''
        stripped = line.strip()
        if idx < len(lines) and (not stripped or stripped.startswith('#')):
            continue
        indent = len(line) - len(line.lstrip(' '))
        if label_seen and (idx == len(lines) or indent <= 4):
            # Match the repository's Prettier convention: simple strings use
            # double quotes; JSON policy arrays use single quotes to avoid
            # escaping all the embedded double quotes.
            new = (
                f'      cf.access: "{additions["cf.access"]}"\n'
                f'      cf.access.policies: \'{additions["cf.access.policies"]}\'\n'
            )
            lines.insert(idx, new)
            return ''.join(lines)
        if indent == 0:
            in_services = stripped == 'services:'
            in_service = False
        elif in_services and indent == 2 and re.match(r'^([^:]+):(?:\s|$)', stripped):
            in_service = stripped.partition(':')[0].strip('"\'') == service
            label_seen = False
        elif in_service and indent == 4 and stripped == 'labels:':
            label_seen = True
    raise ValueError(f'No mapping-style labels section for service {service!r}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compose-root', required=True, type=Path)
    parser.add_argument('--state', required=True, type=Path)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()

    state = json.loads(args.state.read_text())
    policy_by_id = {str(p['id']): str(p['name']) for p in attrs_of(state, 'cloudflare_zero_trust_access_policy')
                    if p.get('id') and p.get('name')}
    applications = defaultdict(list)
    for app in attrs_of(state, 'cloudflare_zero_trust_access_application'):
        ids, issue = ordered_policy_ids(app)
        for hostname in app_hosts(app):
            applications[hostname].append({'name': app.get('name'), 'id': app.get('id'),
                                           'policy_ids': ids, 'issue': issue})

    print(f'Imported: {len(policy_by_id)} reusable policies; '
          f'{sum(map(len, applications.values()))} app-host mappings')
    yaml = YAML(typ='safe')
    accepted = existing = skipped = 0
    paths = sorted(set(args.compose_root.rglob('compose.yaml')) | set(args.compose_root.rglob('compose.yml')))
    for path in paths:
        original = path.read_text()
        try:
            doc = yaml.load(original)
        except Exception as ex:
            print(f'ERROR {path}: invalid YAML: {ex}')
            skipped += 1
            continue
        if not isinstance(doc, dict) or not isinstance(doc.get('services'), dict):
            continue
        edits = []
        for svc, definition in doc['services'].items():
            if not isinstance(definition, dict):
                continue
            labels = labels_dict(definition.get('labels'))
            if labels.get('traefik.enable', '').lower() != 'true':
                continue
            hostnames = {h for k, v in labels.items() if RULE_RE.match(k)
                         for raw in HOST_RE.findall(v) if (h := host(raw))}
            if not hostnames:
                continue
            issues = []
            policy_sets = []
            for hostname in sorted(hostnames):
                matches = applications.get(hostname, [])
                if len(matches) != 1:
                    issues.append(f'{hostname}: {len(matches)} matching Access applications')
                    continue
                app = matches[0]
                if app['issue']:
                    issues.append(f'{hostname}: {app["issue"]}')
                    continue
                ids = app['policy_ids']
                unknown = [pid for pid in ids if pid not in policy_by_id]
                if unknown:
                    issues.append(f'{hostname}: {len(unknown)} policy IDs missing from imported reusable policies')
                    continue
                policy_sets.append(tuple(ids))
            if not issues and (not policy_sets or any(ps != policy_sets[0] for ps in policy_sets[1:])):
                issues.append('hostnames have different ordered policy assignments')
            rel = path.relative_to(args.compose_root)
            if issues:
                print(f'SKIP {rel} / {svc} [{", ".join(sorted(hostnames))}]: {"; ".join(issues)}')
                skipped += 1
                continue
            ids = list(policy_sets[0])
            named = ', '.join(policy_by_id[p] for p in ids)
            # JSON array is a string Docker label, preserving policy precedence.
            desired = {'cf.access': 'true',
                       'cf.access.policies': json.dumps(ids, separators=(',', ':'))}
            current = {k: labels[k] for k in desired if k in labels}
            if current:
                if current == desired:
                    print(f'EXISTS {rel} / {svc} -> {named}')
                    existing += 1
                else:
                    print(f'SKIP {rel} / {svc}: conflicting existing labels {current}')
                    skipped += 1
                continue
            print(f'ADD {rel} / {svc} [{", ".join(sorted(hostnames))}] -> {named}')
            edits.append((svc, desired))
            accepted += 1
        if args.write and edits:
            updated = original
            for svc, desired in edits:
                updated = apply_text_insert(updated, svc, desired)
            validated = yaml.load(updated)
            for svc, desired in edits:
                actual = labels_dict(validated['services'][svc].get('labels'))
                if any(actual.get(key) != val for key, val in desired.items()):
                    raise RuntimeError(f'Validation failed for {path}, service {svc}')
            backup = path.with_name(path.name + '.cf-labels.bak')
            if backup.exists():
                raise RuntimeError(f'Refusing to overwrite existing backup: {backup}')
            backup.write_text(original)
            path.write_text(updated)
    print(f'\nSummary: {accepted} eligible additions, {existing} already labeled, '
          f'{skipped} need review; mode={"WRITE" if args.write else "DRY RUN"}')
    print('No containers were redeployed; no Cloudflare API calls were made.')


if __name__ == '__main__':
    main()
