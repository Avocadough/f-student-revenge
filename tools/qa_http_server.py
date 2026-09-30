"""Serve only the isolated local QA export and receive its JSON on localhost."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import uuid

ROOT = Path(__file__).resolve().parents[1]
WEB_ROOT = ROOT / "evidence/webqa"
RESULTS = ROOT / "evidence/webqa_results"


class QAHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB_ROOT), **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_POST(self):
        if self.path != "/qa-result":
            self.send_error(404)
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0 or length > 512_000:
                raise ValueError("Invalid result size")
            data = json.loads(self.rfile.read(length))
            if not isinstance(data, dict) or "traversal" not in data or "performance" not in data:
                raise ValueError("Missing QA result fields")
            RESULTS.mkdir(parents=True, exist_ok=True)
            stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
            name = f"webqa_{stamp}_{uuid.uuid4().hex[:8]}.json"
            (RESULTS / name).write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
            response = json.dumps({"saved": name}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(response)))
            self.end_headers()
            self.wfile.write(response)
            print(f"QA_RESULT_SAVED {name}", flush=True)
        except (ValueError, OSError) as exc:
            self.send_error(400, str(exc))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8769)
    args = parser.parse_args()
    if not (WEB_ROOT / "index.html").exists():
        raise SystemExit("Build the isolated Web QA export before starting this server.")
    print(f"Local isolated QA: http://127.0.0.1:{args.port}/index.html", flush=True)
    ThreadingHTTPServer(("127.0.0.1", args.port), QAHandler).serve_forever()


if __name__ == "__main__":
    main()
