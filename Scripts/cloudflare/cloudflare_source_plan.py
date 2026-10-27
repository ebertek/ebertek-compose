"""Create source-repository update plans from the merged, read-only checkout.

A plan is input for a separate GitHub writer. This module never edits the
GitOps checkout, source repositories, Terraform state, or Cloudflare resources.
"""

import hashlib
import json
import os
import tempfile

PUBLIC_REPO = "ebertek/ebertek-compose"
PRIVATE_REPO = "ebertek/ebertek-compose-secrets"
PRIVATE_FILES = {"access-policies.tf", "dns-ygg.tf", "tunnel-config.tf"}


def source_repo(filename):
    """Map known Terraform source files to their owning repository."""
    if filename in PRIVATE_FILES:
        return PRIVATE_REPO
    if filename.startswith(("access-", "dns-")) and filename.endswith(".tf"):
        return PUBLIC_REPO
    raise ValueError(f"Terraform file has no approved source owner: {filename}")


def make_change(filename, before, after):
    """Describe a source change with a hash for optimistic concurrency."""
    if before == after:
        raise ValueError(f"Refusing empty change for {filename}")
    return {
        "repository": source_repo(filename),
        "path": f"terraform/cloudflare/{filename}",
        "before_sha256": (
            hashlib.sha256(before.encode("utf-8")).hexdigest()
            if before is not None
            else None
        ),
        "content": after,
    }


def output_plan(path, merged_root, files):
    """Write the change plan outside the merged Git checkout with mode 0600."""
    path = path.expanduser().resolve()
    merged_root = merged_root.expanduser().resolve()
    if path.is_relative_to(merged_root):
        raise ValueError("Plan output cannot be inside the merged Git checkout")
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(
        prefix=".cloudflare-plan-", suffix=".tmp", dir=path.parent
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump({"version": 1, "files": files}, stream, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    return path
