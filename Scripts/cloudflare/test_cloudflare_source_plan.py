"""Offline tests for source-owner routing and immutable change plans."""

import hashlib
import json
import os
import tempfile
import unittest
from pathlib import Path

from cloudflare_source_plan import make_change, output_plan, source_repo


class SourcePlanTests(unittest.TestCase):
    """Ensure planned changes cannot modify the merged checkout."""

    def test_repo_ownership(self):
        """Route tunnel and internal DNS privately, Access/DNS publicly."""
        self.assertEqual(
            source_repo("tunnel-config.tf"), "ebertek/ebertek-compose-secrets"
        )
        self.assertEqual(source_repo("dns-ygg.tf"), "ebertek/ebertek-compose-secrets")
        self.assertEqual(
            source_repo("access-policies.tf"), "ebertek/ebertek-compose-secrets"
        )
        self.assertEqual(source_repo("access-auto.tf"), "ebertek/ebertek-compose")
        with self.assertRaises(ValueError):
            source_repo("backend.tf")

    def test_manifest_has_source_precondition(self):
        """Include original-file digest so a later writer can reject drift."""
        proposed = make_change("dns-ygg.tf", "old", "new")
        self.assertEqual(
            proposed["before_sha256"],
            hashlib.sha256(b"old").hexdigest(),
        )
        self.assertEqual(proposed["content"], "new")
        self.assertIsNone(make_change("access-auto.tf", None, "new")["before_sha256"])
        with self.assertRaises(ValueError):
            make_change("dns-ygg.tf", "same", "same")

    def test_output_plan_outside_checkout(self):
        """Write a private JSON plan without modifying tracked files."""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "ygg-compose"
            root.mkdir()
            output = Path(directory) / "plans/source.json"
            files = [make_change("dns-ygg.tf", "before", "after")]
            output_plan(output, root, files)
            saved = json.loads(output.read_text())
            self.assertEqual(saved["files"], files)
            self.assertEqual(os.stat(output).st_mode & 0o777, 0o600)
            self.assertFalse(list(root.iterdir()))
            with self.assertRaises(ValueError):
                output_plan(root / "oops.json", root, files)


if __name__ == "__main__":
    unittest.main()
