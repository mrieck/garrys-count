#!/usr/bin/env python3
"""Garry's Count Viewer — minimal HTTP server for today's edited files."""

import json
import os
import sys
import http.server
import socketserver
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path

GARRYS_DIR = Path.home() / ".claude" / "garryscount"
SCRIPT_DIR = Path(__file__).parent
DEFAULT_PORT = 7777

# Sensitive directories to block from /api/content
BLOCKED_PATTERNS = [
    "/.ssh/", "/.aws/", "/.gnupg/", "/.config/", "/.kube/",
    "/.azure/", "/.gcloud/", "/Library/Keychains/",
]


def load_config():
    config_file = GARRYS_DIR / "config.json"
    try:
        return json.loads(config_file.read_text())
    except Exception:
        return {}


def get_effective_date(reset_hour):
    now = datetime.now()
    if now.hour < reset_hour:
        from datetime import timedelta
        yesterday = now - timedelta(days=1)
        return yesterday.strftime("%Y-%m-%d")
    return now.strftime("%Y-%m-%d")


def get_tally():
    config = load_config()
    reset_hour = config.get("reset_hour", 5)
    date_str = get_effective_date(reset_hour)
    tally_file = GARRYS_DIR / f"{date_str}.json"
    try:
        return json.loads(tally_file.read_text())
    except Exception:
        return {}


def is_safe_path(path_str):
    """Validate that a path is safe to serve."""
    if not path_str:
        return False
    try:
        p = Path(path_str).resolve()
        home = Path.home().resolve()
        # Must be under home directory
        p.relative_to(home)
        # Must not be in a sensitive directory
        path_normalized = str(p)
        for blocked in BLOCKED_PATTERNS:
            if blocked in path_normalized:
                return False
        # Must be a regular file
        return p.is_file()
    except (ValueError, OSError):
        return False


def read_file_content(path_str):
    if not is_safe_path(path_str):
        return {"content": None, "error": "Path not accessible"}
    try:
        content = Path(path_str).read_text(errors="replace")
        return {"content": content, "error": None}
    except Exception as e:
        return {"content": None, "error": str(e)}


def get_html():
    # Try to find index.html relative to viewer.py's installed location
    candidates = [
        GARRYS_DIR / "index.html",
        SCRIPT_DIR.parent / "viewer" / "index.html",
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate.read_text()
    return "<h1>Garry's Count Viewer</h1><p>index.html not found. Re-run install.sh.</p>"


class ViewerHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # silence request logs

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)

        if parsed.path == "/api/files":
            tally = get_tally()
            files = tally.get("files_edited", [])
            self._send_json(files)

        elif parsed.path == "/api/tally":
            tally = get_tally()
            # Return summary without file contents
            summary = {k: v for k, v in tally.items() if k != "files_edited"}
            self._send_json(summary)

        elif parsed.path == "/api/content":
            params = urllib.parse.parse_qs(parsed.query)
            path = params.get("path", [None])[0]
            self._send_json(read_file_content(path))

        elif parsed.path in ("/", "/index.html"):
            html = get_html()
            body = html.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        else:
            self.send_error(404)

    def _send_json(self, data):
        body = json.dumps(data).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main():
    config = load_config()
    port = config.get("viewer_port", DEFAULT_PORT)

    # Allow port override from command line
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            pass

    server_address = ("127.0.0.1", port)
    try:
        with socketserver.TCPServer(server_address, ViewerHandler) as httpd:
            httpd.allow_reuse_address = True
            print(f"Garry's Count Viewer running at http://localhost:{port}", flush=True)
            httpd.serve_forever()
    except OSError as e:
        print(f"Error: could not bind to port {port}: {e}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
