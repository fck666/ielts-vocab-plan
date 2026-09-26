#!/usr/bin/env python3
"""Start or stop the local static site without opening a Terminal window."""

from __future__ import annotations

import hashlib
import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path
from urllib.request import urlopen


APP_NAME = "IELTS Vocabulary Lab"
PROJECT_ROOT = Path(__file__).resolve().parent
RUNTIME_DIR = Path.home() / "Library" / "Application Support" / APP_NAME
PROJECT_KEY = hashlib.sha256(str(PROJECT_ROOT).encode()).hexdigest()[:16]
RUNTIME_FILE = RUNTIME_DIR / f"{PROJECT_KEY}.json"
LEGACY_RUNTIME_FILE = RUNTIME_DIR / "runtime.json"
LOG_FILE = Path.home() / "Library" / "Logs" / APP_NAME / "server.log"


def read_runtime(path: Path) -> dict | None:
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError, TypeError):
        return None


def process_command(pid: int) -> str:
    try:
        return subprocess.check_output(["ps", "-p", str(pid), "-o", "command="], text=True).strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


def is_our_process(runtime: dict) -> bool:
    try:
        pid = int(runtime["pid"])
        root = str(Path(runtime["root"]).resolve())
    except (KeyError, TypeError, ValueError):
        return False
    serve_path = str((PROJECT_ROOT / "serve.py").resolve())
    return root == str(PROJECT_ROOT) and serve_path in process_command(pid)


def site_is_ready(url: str) -> bool:
    try:
        with urlopen(url, timeout=0.6) as response:
            return response.status == 200
    except Exception:
        return False


def remove_runtime(path: Path) -> None:
    try:
        path.unlink()
    except FileNotFoundError:
        pass


def owned_runtime() -> tuple[dict | None, Path | None]:
    for path in (RUNTIME_FILE, LEGACY_RUNTIME_FILE):
        runtime = read_runtime(path)
        if not runtime:
            continue
        try:
            root = str(Path(runtime.get("root", "")).resolve())
        except (OSError, TypeError, ValueError):
            continue
        if root == str(PROJECT_ROOT):
            return runtime, path
    return None, None


def start() -> None:
    runtime, runtime_path = owned_runtime()
    if runtime and is_our_process(runtime) and site_is_ready(runtime.get("url", "")):
        if runtime_path != RUNTIME_FILE:
            RUNTIME_FILE.write_text(json.dumps(runtime))
            remove_runtime(runtime_path)
        subprocess.Popen(["open", runtime["url"]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return
    if runtime_path:
        remove_runtime(runtime_path)

    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    log_handle = LOG_FILE.open("ab")
    process = subprocess.Popen(
        [sys.executable, str(PROJECT_ROOT / "serve.py"), "--runtime-file", str(RUNTIME_FILE), "--no-browser"],
        cwd=PROJECT_ROOT,
        stdin=subprocess.DEVNULL,
        stdout=log_handle,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    log_handle.close()

    deadline = time.monotonic() + 5
    url = None
    while time.monotonic() < deadline:
        runtime = read_runtime(RUNTIME_FILE)
        if runtime and int(runtime.get("pid", -1)) == process.pid:
            url = runtime.get("url")
            if url and site_is_ready(url):
                break
        time.sleep(0.08)
    if not url or not site_is_ready(url):
        try:
            process.terminate()
        except OSError:
            pass
        remove_runtime(RUNTIME_FILE)
        raise RuntimeError(f"The local server did not start. See {LOG_FILE}")
    subprocess.Popen(["open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def stop() -> None:
    for path in (RUNTIME_FILE, LEGACY_RUNTIME_FILE):
        runtime = read_runtime(path)
        if not runtime:
            continue
        try:
            root = str(Path(runtime.get("root", "")).resolve())
        except (OSError, TypeError, ValueError):
            continue
        if root != str(PROJECT_ROOT):
            continue
        if is_our_process(runtime):
            pid = int(runtime["pid"])
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        remove_runtime(path)


def main() -> None:
    if len(sys.argv) != 2 or sys.argv[1] not in {"start", "stop"}:
        raise SystemExit("Usage: launcher.py start|stop")
    (start if sys.argv[1] == "start" else stop)()


if __name__ == "__main__":
    main()
