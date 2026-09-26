#!/usr/bin/env python3
"""Start the static vocabulary site on the first available local port."""

from __future__ import annotations

import http.server
import argparse
import json
import os
import threading
import webbrowser
from pathlib import Path


ROOT = Path(__file__).resolve().parent
HOST = "127.0.0.1"
PORTS = (8765, *range(8766, 8800))


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def log_message(self, format, *args):
        pass


def create_server() -> http.server.ThreadingHTTPServer:
    for port in PORTS:
        try:
            return http.server.ThreadingHTTPServer((HOST, port), QuietHandler)
        except OSError:
            continue
    raise RuntimeError("No available port found between 8765 and 8799.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Serve the static vocabulary site.")
    parser.add_argument("--runtime-file", type=Path)
    parser.add_argument("--no-browser", action="store_true")
    args = parser.parse_args()
    server = create_server()
    url = f"http://{HOST}:{server.server_address[1]}/"
    if args.runtime_file:
        args.runtime_file.parent.mkdir(parents=True, exist_ok=True)
        args.runtime_file.write_text(json.dumps({"pid": os.getpid(), "url": url, "root": str(ROOT)}))
    if not args.no_browser:
        threading.Timer(0.5, lambda: webbrowser.open(url)).start()
    print(f"IELTS Vocabulary Lab is running at {url}", flush=True)
    print("Keep this window open. Press Ctrl+C to stop the local server.", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping local server...")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
