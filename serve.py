#!/usr/bin/env python3
"""Start the static vocabulary site on the first available local port."""

from __future__ import annotations

import http.server
import argparse
import json
import os
import threading
import webbrowser
import socket
import uuid
from urllib.parse import urlsplit
from pathlib import Path


ROOT = Path(__file__).resolve().parent
HOST = "127.0.0.1"
PORTS = (8765, *range(8766, 8800))
SPEECH_SOCKET = Path.home() / "Library" / "Application Support" / "IELTS Vocabulary Lab" / "speech.sock"


def native_speech(request: dict) -> dict:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        connection.settimeout(6)
        connection.connect(str(SPEECH_SOCKET))
        connection.sendall(json.dumps(request).encode("utf-8") + b"\n")
        response = bytearray()
        while len(response) < 8192:
            chunk = connection.recv(1024)
            if not chunk:
                break
            response.extend(chunk)
            if b"\n" in response:
                return json.loads(response.split(b"\n", 1)[0])
    raise OSError("Native speech did not respond")


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def speech_request_allowed(self) -> bool:
        # Reject cross-origin browser requests and unexpected Host headers (including DNS rebinding).
        host = self.headers.get("Host", "")
        allowed_hosts = {f"127.0.0.1:{self.server.server_port}", f"localhost:{self.server.server_port}"}
        origin = self.headers.get("Origin")
        return (host in allowed_hosts
                and self.headers.get("Sec-Fetch-Site") != "cross-site"
                and (not origin or origin == f"http://{host}"))

    def send_json(self, status: int, value: dict) -> None:
        body = json.dumps(value).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def do_GET(self):
        if urlsplit(self.path).path != "/api/speech":
            return super().do_GET()
        if not self.speech_request_allowed():
            return self.send_json(403, {"available": False, "error": "Same-origin access required"})
        try:
            result = native_speech({"action": "status"})
        except (OSError, ValueError):
            result = {"available": False, "backend": "browser"}
        self.send_json(200, result)

    def do_POST(self):
        if urlsplit(self.path).path != "/api/speech":
            return self.send_json(404, {"ok": False, "error": "Unknown endpoint"})
        if (not self.speech_request_allowed()
                or self.headers.get("Content-Type", "").split(";", 1)[0].strip() != "application/json"):
            return self.send_json(403, {"ok": False, "error": "Same-origin JSON request required"})
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if not 0 < length <= 4096:
                raise ValueError("Invalid request size")
            payload = json.loads(self.rfile.read(length))
            if not isinstance(payload, dict):
                raise ValueError("Invalid request")
            action = payload.get("action", "speak")
            if action == "speak":
                text, accent = payload.get("text"), payload.get("accent", "uk")
                if not isinstance(text, str) or not text.strip() or len(text) > 300 or accent not in ("uk", "us"):
                    raise ValueError("Invalid word or accent")
                request = {"action": action, "text": text, "accent": accent,
                           "requestID": str(payload.get("requestID") or uuid.uuid4())[:80]}
            elif action == "stop":
                request = {"action": action}
            else:
                raise ValueError("Unknown action")
        except (ValueError, TypeError):
            return self.send_json(400, {"ok": False, "error": "Invalid speech request"})
        try:
            result = native_speech(request)
        except (OSError, ValueError):
            return self.send_json(503, {"ok": False, "error": "Native speech unavailable"})
        self.send_json(200 if result.get("ok") else 409, result)

    def end_headers(self):
        if self.path.split("?", 1)[0].endswith((".html", "/")):
            self.send_header("Cache-Control", "no-cache, must-revalidate")
        super().end_headers()

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
