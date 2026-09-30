"""Verify the deployed Pages files against the exact local production export."""
from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
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
        committed = subprocess.check_output(["git", "show", f"{revision}:docs/{name}"], cwd=ROOT)
        local_matches = local == committed or (
            Path(name).suffix in {".html", ".js"} and local.replace(b"\r\n", b"\n") == committed
        )
        request = Request(URL + name + "?verify=" + revision, headers={"Cache-Control": "no-cache"})
        with urlopen(request, timeout=90) as response:
            remote = response.read()
            status = response.status
        expected = hashlib.sha256(committed).hexdigest()
        received = hashlib.sha256(remote).hexdigest()
        results.append({"file": name, "http_status": status, "bytes": len(remote),
                        "committed_sha256": expected, "public_sha256": received,
                        "working_tree_sha256": hashlib.sha256(local).hexdigest(),
                        "working_tree_matches_commit_allowing_text_crlf": local_matches,
                        "match": status == 200 and expected == received and local_matches})
    # Verify the exact cache-key URL used by the shipping shell as well.
    shell = (ROOT / "docs/index.html").read_text(encoding="utf-8")
    cache_key = re.search(r"const packUrl = packPath \+ '([^']+)';", shell)
    if cache_key is None:
        raise SystemExit("Missing versioned pack URL in the exported shell")
    pack_url = URL + "index.pck" + cache_key.group(1)
    with urlopen(Request(pack_url, headers={"Cache-Control": "no-cache"}), timeout=90) as response:
        pack_bytes = response.read()
        pack_status = response.status
    versioned_pack = {"url": pack_url, "http_status": pack_status, "bytes": len(pack_bytes),
                      "sha256": hashlib.sha256(pack_bytes).hexdigest()}
    versioned_pack["match"] = pack_status == 200 and versioned_pack["sha256"] == next(
        row["committed_sha256"] for row in results if row["file"] == "index.pck")
    record = {"version": "0.5", "checked_at_utc": datetime.now(timezone.utc).isoformat(),
              "source_commit": revision, "url": URL,
              "scope": "Public HTTP bytes against committed production export, also checked against the local export allowing Git CRLF conversion for HTML/JS only. Binary PCK/WASM bytes must match exactly. Browser behavior is separately documented in VALIDATION.md.",
              "passed": all(row["match"] for row in results) and versioned_pack["match"],
              "files": results, "versioned_pack": versioned_pack,
              "rollback_commit": "8dddb42569aaf0cedf0f11130263e6e512fdbde7",
              "rollback_branch": "codex/pre-bureaucracy-v0.4.1"}
    path = ROOT / "Verification" / "publication_v0_5.json"
    path.write_text(json.dumps(record, indent=2), encoding="utf-8")
    print(json.dumps({"passed": record["passed"], "files": len(results), "source_commit": revision}))
    if not record["passed"]:
        raise SystemExit("Publication does not match; inspect publication_v0_5.json")


if __name__ == "__main__":
    main()
