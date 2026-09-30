"""Verify the deployed Pages files against the exact local production export."""
from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
URL = "https://avocadough.github.io/f-student-revenge/"
FILES = ["index.html", "index.pck", "index.wasm", "index.js",
         "index.audio.worklet.js", "index.audio.position.worklet.js",
         "index.icon.png", "index.apple-touch-icon.png", "index.png"]


def main() -> None:
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    results = []
    for name in FILES:
        local = (ROOT / "docs" / name).read_bytes()
        request = Request(URL + name + "?verify=" + revision, headers={"Cache-Control": "no-cache"})
        with urlopen(request, timeout=90) as response:
            remote = response.read()
            status = response.status
        expected = hashlib.sha256(local).hexdigest()
        received = hashlib.sha256(remote).hexdigest()
        results.append({"file": name, "http_status": status, "bytes": len(remote),
                        "local_sha256": expected, "public_sha256": received,
                        "match": status == 200 and expected == received})
    record = {"version": "0.3", "checked_at_utc": datetime.now(timezone.utc).isoformat(),
              "source_commit": revision, "url": URL,
              "scope": "Public HTTP bytes against local production export; browser behavior is separately documented in VALIDATION.md.",
              "passed": all(row["match"] for row in results), "files": results,
              "rollback_commit": "d75d0f6283f2fd60f66cb5114a455c588f5f7219",
              "rollback_branch": "codex/pre-demon-v0.2"}
    path = ROOT / "Verification" / "publication_v0_3.json"
    path.write_text(json.dumps(record, indent=2), encoding="utf-8")
    print(json.dumps({"passed": record["passed"], "files": len(results), "source_commit": revision}))
    if not record["passed"]:
        raise SystemExit("Publication does not match; inspect publication_v0_3.json")


if __name__ == "__main__":
    main()
