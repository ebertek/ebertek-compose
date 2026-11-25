"""Tests for Frigate recording freshness policy and timestamps."""

import unittest

from exporter import metrics


class MetricsTest(unittest.TestCase):
    """Check which cameras are queried and the resulting timestamps."""

    def test_continuous_camera_policy(self):
        """Emit timestamps only for enabled continuous recordings."""

        def camera(days, enabled=True, recording=True):
            return {
                "enabled": enabled,
                "record": {"enabled": recording, "continuous": {"days": days}},
            }

        responses = {
            "config": {
                "cameras": {
                    "continuous": camera(1),
                    "missing": camera(1),
                    "event": camera(0),
                    "disabled": camera(1, enabled=False),
                    "no-record": camera(1, recording=False),
                },
            },
            "continuous/recordings?after=100&before=1000": [
                {"end_time": 995},
                {"end_time": 980},
            ],
            "missing/recordings?after=100&before=1000": [],
        }
        output = metrics(responses.__getitem__, 1000).decode()
        self.assertIn('{camera="continuous"} 995.0', output)
        self.assertIn('{camera="missing"} 0', output)
        self.assertEqual(output.count("{camera="), 2)

    def test_upstream_failure_is_not_a_missing_segment(self):
        """Propagate API failures to the scrape handler."""
        with self.assertRaises(OSError):
            metrics(lambda _: self.fail_request(), 1000)

    @staticmethod
    def fail_request():
        """Simulate a failed upstream API request."""
        raise OSError("unreachable")


if __name__ == "__main__":
    unittest.main()
