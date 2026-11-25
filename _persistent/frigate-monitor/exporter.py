"""Expose Frigate's indexed recording freshness for continuously retained cameras."""

import json
import logging
import math
import os
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import quote, urlencode
from urllib.request import urlopen


def metrics(get, now):
    """Read a bounded recording window and emit one timestamp per eligible camera."""
    config = get("config")
    window = urlencode({"after": now - 900, "before": now})
    lines = [
        "# HELP frigate_latest_recording_end_timestamp_seconds Latest indexed recording end.",
        "# TYPE frigate_latest_recording_end_timestamp_seconds gauge",
    ]
    for camera, settings in config["cameras"].items():
        recording = settings["record"]
        if not (
            settings["enabled"]
            and recording["enabled"]
            and recording["continuous"]["days"] > 0
        ):
            continue
        segments = get(f"{quote(camera, safe='')}/recordings?{window}")
        if not isinstance(segments, list):
            raise ValueError("Invalid Frigate recording response")
        end = max((float(segment["end_time"]) for segment in segments), default=0)
        if not math.isfinite(end):
            raise ValueError("Invalid Frigate recording timestamp")
        label = json.dumps(camera, ensure_ascii=False)
        lines.append(
            f"frigate_latest_recording_end_timestamp_seconds{{camera={label}}} {end}"
        )
    return ("\n".join(lines) + "\n").encode()


def get_json(path):
    """Read JSON from the existing local Frigate API."""
    base = os.environ["FRIGATE_API_URL"].rstrip("/")
    with urlopen(f"{base}/{path}", timeout=2) as response:
        return json.load(response)


class MetricsHandler(BaseHTTPRequestHandler):
    """Serve metrics without returning upstream response bodies or errors."""

    def do_GET(self):  # pylint: disable=invalid-name
        """Serve the Prometheus scrape endpoint."""
        if self.path != "/metrics":
            self.send_error(404)
            return
        try:
            payload = metrics(get_json, time.time())
        except (OSError, ValueError, KeyError, TypeError) as error:
            logging.warning("Frigate scrape failed (%s)", type(error).__name__)
            self.send_error(502)
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; version=0.0.4")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, format, *args):  # pylint: disable=redefined-builtin
        """Suppress routine HTTP access logs."""


if __name__ == "__main__":
    with HTTPServer(("0.0.0.0", 9108), MetricsHandler) as server:
        server.serve_forever()
