"""Build an isolated browser QA game; never edits or exports the production project."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess


ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / ".work" / "webqa"
OUTPUT = ROOT / "evidence" / "webqa"

HTML_QA = r'''<style>
html,body{background:#111a20!important;color:#d5e6ed;margin:0;overflow:auto!important}
#canvas{width:1280px!important;height:720px!important;max-width:none!important;max-height:none!important}
#qa-status{position:fixed;top:8px;right:8px;z-index:999;font:13px system-ui;background:#13252fe8;padding:8px 12px;border:1px solid #537b88;border-radius:8px;max-width:500px;pointer-events:none}
#qa-results{position:absolute;top:730px;left:12px;right:12px;white-space:pre-wrap;overflow-wrap:anywhere;display:none;background:#172b35;padding:18px;font:13px monospace}
</style><div id="qa-status">Loading actual Godot game. Click Start QA inside the game; keep this tab visible.</div><pre id="qa-results"></pre>
<script>
window.__fStudentQAErrors=[];
window.__fStudentQAErrorTotal=0;
function recordQAError(message){
 window.__fStudentQAErrorTotal++;
 if(window.__fStudentQAErrors.length<100)window.__fStudentQAErrors.push(message);
}
const originalQAError=console.error.bind(console);
console.error=function(...args){recordQAError(args.map(String).join(' '));originalQAError(...args);};
window.addEventListener('error',e=>recordQAError(String(e.message)));
window.fStudentQAStatus=function(text){document.getElementById('qa-status').textContent=text;};
window.finishFStudentQA=function(result){
 result.browser_console_errors=window.__fStudentQAErrors.slice();
 result.browser_console_error_total=window.__fStudentQAErrorTotal;
 window.FSTUDENT_QA_RESULT=result;
 const pre=document.getElementById('qa-results'); pre.textContent=JSON.stringify(result,null,2);pre.style.display='block';
 window.fStudentQAStatus((result.traversal.complete?'Traversal complete':'Traversal FAILED')+' | Results shown below canvas; saving locally...');
 console.log('FSTUDENT_WEB_QA_RESULT',JSON.stringify(result));
 fetch('/qa-result',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(result)})
 .then(r=>{if(!r.ok)throw Error('HTTP '+r.status);return r.json();})
 .then(saved=>{window.fStudentQAStatus('QA finished | '+saved.saved);pre.dataset.saved=saved.saved;})
 .catch(e=>window.fStudentQAStatus('QA finished | Local save failed: '+e.message+' | JSON remains below canvas'));
};
</script>'''


def run_engine(engine: Path, args: list[str], log_name: str) -> None:
    completed = subprocess.run([str(engine), "--headless", "--path", str(PROJECT), *args],
                               cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    log = completed.stdout + completed.stderr
    (OUTPUT / log_name).write_text(log, encoding="utf-8")
    if completed.returncode or "SCRIPT ERROR" in log or "Parse Error" in log:
        raise RuntimeError(f"Godot QA build failed: {log_name}\n{log[-6000:]}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine", type=Path, default=ROOT / ".work/engine/Godot_v4.7.2-stable_win64_console.exe")
    args = parser.parse_args()
    PROJECT.mkdir(parents=True, exist_ok=True)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    # Explicit directories avoid recursively copying .work, exports, or prior QA builds.
    for directory in ("Assets", "Scripts", "Scenes", "Web"):
        shutil.copytree(ROOT / directory, PROJECT / directory, dirs_exist_ok=True)
    shutil.copy2(ROOT / "icon.svg", PROJECT / "icon.svg")
    shutil.copy2(ROOT / "tools/web_qa_runner.gd", PROJECT / "web_qa_runner.gd")
    settings = (ROOT / "project.godot").read_text(encoding="utf-8-sig")
    settings = settings.replace('run/main_scene="res://Scenes/main.tscn"', 'run/main_scene="res://web_qa_main.tscn"')
    settings = settings.replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="FStudentRevengeWebQA"')
    (PROJECT / "project.godot").write_text(settings, encoding="utf-8")
    (PROJECT / "web_qa_main.tscn").write_text('[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://web_qa_runner.gd" id="1"]\n\n[node name="IsolatedWebQA" type="Node"]\nprocess_mode = 3\nscript = ExtResource("1")\n', encoding="utf-8")
    preset = (ROOT / "export_presets.cfg").read_text(encoding="utf-8-sig")
    preset = preset.replace('export_path="docs/index.html"', f'export_path="{(OUTPUT / "index.html").as_posix()}"')
    preset = preset.replace('html/canvas_resize_policy=2', 'html/canvas_resize_policy=0')
    (PROJECT / "export_presets.cfg").write_text(preset, encoding="utf-8")
    run_engine(args.engine.resolve(), ["--editor", "--import", "--quit"], "qa_import.log")
    imports = []
    for model in sorted((PROJECT / "Assets/Models").glob("*.glb")):
        digest = hashlib.md5(model.read_bytes()).hexdigest()
        cached = []
        for entry in (PROJECT / ".godot/imported").glob(model.name + "-*.md5"):
            match = re.search(r'source_md5="([a-f0-9]+)"', entry.read_text())
            if match:
                cached.append(match.group(1))
        imports.append({"model": model.name, "current_md5": digest, "cache_source_md5": cached,
                        "cache_matches_current_source": digest in cached})
    (OUTPUT / "import_source_integrity.json").write_text(json.dumps(imports, indent=2), encoding="utf-8")
    if not all(row["cache_matches_current_source"] for row in imports):
        raise RuntimeError("QA model import cache does not match copied source; export was not started")
    run_engine(args.engine.resolve(), ["--export-release", "Web", str(OUTPUT / "index.html")], "qa_export.log")
    page = OUTPUT / "index.html"
    html = page.read_text(encoding="utf-8")
    html = html.replace('<body>', '<body>\n' + HTML_QA, 1)
    html = html.replace('<canvas id="canvas">', '<canvas id="canvas" width="1280" height="720">', 1)
    page.write_text(html, encoding="utf-8")
    sources = [PROJECT / "project.godot", PROJECT / "export_presets.cfg", PROJECT / "web_qa_runner.gd",
               PROJECT / "web_qa_main.tscn", *sorted((PROJECT / "Scripts").glob("*.gd")),
               *sorted((PROJECT / "Scenes").glob("*.tscn"))]
    resources = sorted(p for p in (PROJECT / "Assets").rglob("*") if p.is_file())
    record = {"scope": "Isolated local browser QA, not production export", "project": str(PROJECT),
              "output": str(OUTPUT), "engine": str(args.engine.resolve()), "viewport": [1280, 720],
              "sources": {str(p.relative_to(PROJECT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},
              "resources": {str(p.relative_to(PROJECT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in resources},
              "exports": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in OUTPUT.iterdir() if p.suffix in {".html", ".js", ".wasm", ".pck"}}}
    (OUTPUT / "build_manifest.json").write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"built": True, "url": "http://127.0.0.1:8769/index.html", "output": str(OUTPUT)}))


if __name__ == "__main__":
    main()
