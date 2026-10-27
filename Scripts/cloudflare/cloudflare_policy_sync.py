"""Safely reconcile existing Cloudflare Access policies in Terraform source.

Only the ordered policies list of uniquely identified, self-hosted applications
is modified. Existing resource IDs and unrelated attributes remain unchanged.
"""

import re

RESOURCE = re.compile(
    r'(?m)^resource\s+"cloudflare_zero_trust_access_application"\s+"[^"]+"\s*\{'
)
DOMAIN = re.compile(r'(?m)^  domain\s*=\s*"([^"\n]+)"\s*$')
TYPE = re.compile(r'(?m)^  type\s*=\s*"([^"\n]+)"\s*$')
POLICIES = re.compile(r"(?m)^  policies[ \t]*=[ \t]*\[")
ENTRY = re.compile(r'\{\s*id\s*=\s*"([^"]+)"\s*,\s*precedence\s*=\s*(\d+)\s*\}\s*,?')


def balanced_end(text, opening, left, right):
    """Locate the closing delimiter, respecting quoted HCL strings."""
    depth = 0
    quoted = False
    escaped = False
    for offset in range(opening, len(text)):
        char = text[offset]
        if quoted:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                quoted = False
        elif char == '"':
            quoted = True
        elif char == left:
            depth += 1
        elif char == right:
            depth -= 1
            if depth == 0:
                return offset + 1
    raise ValueError("Unbalanced Terraform delimiters; refusing policy rewrite")


def ordered_ids(body):
    """Validate the existing ordered policy list without changing its semantics."""
    matches = list(ENTRY.finditer(body))
    if not matches or ENTRY.sub("", body).strip(" \t\r\n,"):
        raise ValueError("Unsupported Access policy list structure")
    priorities = [int(match.group(2)) for match in matches]
    if priorities != list(range(1, len(matches) + 1)):
        raise ValueError("Access policy precedence must be consecutive from 1")
    result = [match.group(1) for match in matches]
    if len(set(result)) != len(result):
        raise ValueError("Duplicate IDs in existing Access policy list")
    return result


def sync_access_policies(text, desired):  # pylint: disable=too-many-locals
    """Return updated HCL, changed hosts, and matched hosts.

    Fail closed on ambiguous resources or unfamiliar policy shapes.
    """
    replacements = []
    changed = []
    found = set()
    for resource in RESOURCE.finditer(text):
        start = resource.start()
        end = balanced_end(text, resource.end() - 1, "{", "}")
        block = text[start:end]
        domains = DOMAIN.findall(block)
        candidates = [domain for domain in domains if domain in desired]
        if not candidates:
            continue
        if len(domains) != 1 or len(candidates) != 1:
            raise ValueError("Ambiguous Access application domain")
        hostname = candidates[0]
        if hostname in found:
            raise ValueError(f"Duplicate Access application: {hostname}")
        found.add(hostname)
        types = TYPE.findall(block)
        if types != ["self_hosted"]:
            raise ValueError(f"Not a self-hosted Access application: {hostname}")
        assignments = list(POLICIES.finditer(block))
        if len(assignments) != 1:
            raise ValueError(f"Missing or ambiguous policies in {hostname}")
        policies = assignments[0]
        opening = start + policies.end() - 1
        closing = balanced_end(text, opening, "[", "]")
        current = ordered_ids(text[opening + 1 : closing - 1])
        wanted = desired[hostname]
        if current == wanted:
            continue
        # Only replace the list brackets and their contents, never the resource
        # identifier, application options, or any adjacent Terraform attributes.
        indent = re.match(r"[ \t]*", policies.group()).group()
        lines = [
            f'{{ id = "{identifier}", precedence = {index} }}'
            for index, identifier in enumerate(wanted, start=1)
        ]
        new_list = (
            "[\n"
            + "\n".join(
                f"{indent}  {line}{',' if index < len(lines) - 1 else ''}"
                for index, line in enumerate(lines)
            )
            + f"\n{indent}]"
        )
        replacements.append((opening, closing, new_list))
        changed.append(hostname)
    for opening, closing, replacement in reversed(replacements):
        text = text[:opening] + replacement + text[closing:]
    return text, changed, found


def plan_access_policy_updates(merged, desired):
    """Plan policy updates using only the read-only merged Terraform checkout."""
    writes = {}
    changed = []
    found = set()
    for path in sorted(merged.glob("access-*.tf")):
        # Reusable policy resources live in the private repository, not here.
        if path.name == "access-policies.tf":
            continue
        before = path.read_text()
        after, modified, matched = sync_access_policies(before, desired)
        if found.intersection(matched):
            raise ValueError("Duplicate Access hostname across Terraform files")
        found.update(matched)
        if before != after:
            writes[path] = (before, after)
            changed.extend(modified)
    return writes, changed
