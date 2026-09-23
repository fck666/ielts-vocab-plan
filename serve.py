#!/usr/bin/env python3
"""Start the static vocabulary site on the first available local port."""

from __future__ import annotations

import http.server
import threading
import webbrowser
from pathlib import Path


ROOT = Path(__file__).resolve().parent
HOST = "127.0.0.1"
PORTS = (8765, *range(8766, 8800))


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)


def create_server() -> http.server.ThreadingHTTPServer:
    for port in PORTS:
        try:
            return http.server.ThreadingHTTPServer((HOST, port), QuietHandler)
        except OSError:
            continue
    raise RuntimeError("No available port found between 8765 and 8799.")


def main() -> None:
    server = create_server()
    url = f"http://{HOST}:{server.server_address[1]}/"
    threading.Timer(0.5, lambda: webbrowser.open(url)).start()
    print(f"IELTS Vocabulary Lab is running at {url}")
    print("Keep this window open. Press Ctrl+C to stop the local server.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping local server...")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
