#!/usr/bin/env python3
"""CYBRA NEURO: staged AI code writer with Parliament approval and guarded apply."""
from __future__ import annotations
import argparse, hashlib, json, os, re, subprocess, sys, tarfile, time, urllib.error, urllib.request, uuid
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[2]
MODULES = ROOT / "modules"
NEURO = ROOT / "neuro"
STAGING = NEURO / "staging"
DUMPS = NEURO / "golden_dumps"
PARLIAMENT_DIR = MODULES / "module_121_parlament"
MAX_FILES, MAX_FILE_BYTES, MAX_RESPONSE_BYTES = 8, 300_000, 2_000_000
MODEL_DEFAULT = "gpt-4.1-mini"

class NeuroError(RuntimeError): pass

def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def safe_source_path(raw: str) -> Path:
    p = PurePosixPath(raw.replace("\\", "/"))
    if p.is_absolute() or not p.parts or any(x in ("", ".", "..") for x in p.parts):
        raise NeuroError("небезпечний шлях")
    if len(p.parts) < 3 or p.parts[0] != "modules" or not re.fullmatch(r"module_[A-Za-z0-9_-]+", p.parts[1]):
        raise NeuroError("дозволені лише наявні файли modules/module_*/...")
    target = ROOT.joinpath(*p.parts)
    if target.is_symlink() or not target.is_file():
        raise NeuroError(f"файл відсутній або symlink: {raw}")
    if not target.resolve().is_relative_to(MODULES.resolve()):
        raise NeuroError("шлях виходить за межі modules")
    if target.stat().st_size > MAX_FILE_BYTES:
        raise NeuroError(f"файл завеликий: {raw}")
    return target

def _api_generate(task: str, sources: dict[str, str]) -> dict:
    key = os.environ.get("OPENAI_API_KEY", "").strip()
    if not key: raise NeuroError("OPENAI_API_KEY не задано в середовищі Termux")
    model = os.environ.get("CYBRA_NEURO_MODEL", MODEL_DEFAULT).strip()
    system = (
        "You are CYBRA NEURO, a cautious software maintenance agent. "
        "Return ONLY valid JSON: {summary:string, files:[{path:string, content:string}]}. "
        "Modify only exact supplied paths. Preserve interfaces. Do not add secrets, exfiltration, "
        "wallet signing, blockchain transactions, credential access, destructive cleanup, PM2 changes, "
        "or unrelated edits. Do not claim tests were run. Return complete replacement file contents."
    )
    user = {"task": task, "constraints": [
        "Only modify supplied existing files.", "Keep changes minimal and backward compatible.",
        "Do not change baselines, approvals, secrets, user data, PM2 state, or wallet files.",
        "Use deterministic code and explicit error handling."
    ], "source_files": sources}
    payload = json.dumps({"model": model, "temperature": 0,
        "response_format": {"type": "json_object"},
        "messages": [{"role": "system", "content": system},
                     {"role": "user", "content": json.dumps(user, ensure_ascii=False)}]
    }).encode()
    req = urllib.request.Request("https://api.openai.com/v1/chat/completions", data=payload,
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=120) as response: raw = response.read(MAX_RESPONSE_BYTES + 1)
    except urllib.error.HTTPError as exc:
        raise NeuroError(f"OpenAI API HTTP {exc.code}: {exc.read(2000).decode('utf-8','replace')}") from exc
    except Exception as exc: raise NeuroError(f"OpenAI API недоступний: {exc}") from exc
    if len(raw) > MAX_RESPONSE_BYTES: raise NeuroError("відповідь моделі перевищила ліміт")
    try:
        result = json.loads(json.loads(raw)["choices"][0]["message"]["content"])
    except Exception as exc: raise NeuroError(f"модель повернула некоректний JSON: {exc}") from exc
    if not isinstance(result, dict) or not isinstance(result.get("files"), list):
        raise NeuroError("у відповіді немає масиву files")
    return result

def _diff(old: str, new: str, path: str) -> str:
    import difflib
    return "".join(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
                                        fromfile=f"a/{path}", tofile=f"b/{path}"))

def generate(task: str, paths: list[str]) -> str:
    if not task.strip(): raise NeuroError("потрібно описати завдання")
    if not paths or len(paths) > MAX_FILES or len(set(paths)) != len(paths):
        raise NeuroError(f"вкажи 1–{MAX_FILES} унікальних файлів")
    originals = {}
    for raw in paths:
        p = safe_source_path(raw)
        try: originals[raw] = p.read_text(encoding="utf-8")
        except Exception as exc: raise NeuroError(f"не вдалося прочитати {raw}: {exc}") from exc
    result = _api_generate(task, originals)
    returned = {}
    for item in result["files"]:
        if not isinstance(item, dict) or not isinstance(item.get("path"), str) or not isinstance(item.get("content"), str):
            raise NeuroError("неправильний елемент files")
        path, content = item["path"], item["content"]
        if path not in originals or path in returned: raise NeuroError(f"неузгоджений/повторний шлях: {path}")
        if len(content.encode()) > MAX_FILE_BYTES: raise NeuroError(f"файл завеликий: {path}")
        returned[path] = content
    if set(returned) != set(originals): raise NeuroError("модель має повернути повний вміст кожного запитаного файла")
    patch_id = time.strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:8]
    folder = STAGING / patch_id
    (folder / "files").mkdir(parents=True, exist_ok=False)
    manifest = {"id": patch_id, "created": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "summary": str(result.get("summary", ""))[:2000], "status": "staged", "files": {}}
    diffs = []
    for path, content in returned.items():
        dest = folder / "files" / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(content, encoding="utf-8")
        manifest["files"][path] = {
            "before_sha256": sha256_bytes(originals[path].encode()),
            "after_sha256": sha256_bytes(content.encode())}
        diffs.append(_diff(originals[path], content, path))
    (folder / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    (folder / "proposal.diff").write_text("".join(diffs), encoding="utf-8")
    print(f"STAGED={patch_id}\nSUMMARY={manifest['summary']}\nFILES={len(returned)}\nDIFF={folder/'proposal.diff'}")
    return patch_id

def _parliament():
    sys.path.insert(0, str(PARLIAMENT_DIR))
    try:
        import parliament
        return parliament
    except Exception as exc: raise NeuroError(f"не вдалося завантажити Parliament: {exc}") from exc

def propose(patch_id: str) -> str:
    folder = STAGING / patch_id
    mf = folder / "manifest.json"
    if not mf.is_file(): raise NeuroError("patch не знайдений")
    manifest = json.loads(mf.read_text())
    if manifest.get("status") != "staged": raise NeuroError("patch вже переданий або має інший статус")
    author = os.environ.get("CYBRA_NEURO_PARLIAMENT_AUTHOR", "").strip()
    if not author: raise NeuroError("задай CYBRA_NEURO_PARLIAMENT_AUTHOR — адресу активного члена Parliament")
    payload = {"neuro_patch_id": patch_id, "files": manifest["files"], "summary": manifest["summary"],
               "diff_sha256": sha256_bytes((folder / "proposal.diff").read_bytes())}
    ok, msg, pid = _parliament().create_proposal("upgrade", f"NEURO code patch {patch_id}", payload, author)
    if not ok: raise NeuroError(f"Parliament відхилив пропозицію: {msg}")
    manifest.update({"parliament_pid": pid, "status": "submitted"})
    mf.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(f"PARLIAMENT_PID={pid}\nSTATUS=submitted; apply дозволений лише після status=approved")
    return pid

def _run(argv: list[str], timeout: int = 300):
    return subprocess.run(argv, cwd=ROOT, capture_output=True, text=True, timeout=timeout)

def _test_changed_files(paths: list[str]) -> None:
    for raw in paths:
        p = safe_source_path(raw)
        if p.suffix == ".py":
            try: compile(p.read_text(encoding="utf-8"), str(p), "exec")
            except Exception as exc: raise NeuroError(f"Python syntax FAIL {raw}: {exc}") from exc
        elif p.suffix == ".sh":
            r = _run(["bash", "-n", str(p)], 30)
            if r.returncode: raise NeuroError(f"Bash syntax FAIL {raw}: {(r.stderr or r.stdout)[:1000]}")

def _full_tests() -> None:
    runner = MODULES / "module_130_test_suite" / "run_tests.sh"
    if not runner.is_file(): raise NeuroError("відсутній повний Test Suite")
    r = _run(["bash", str(runner)], 600)
    if r.returncode: raise NeuroError("повний Test Suite FAIL:\n" + (r.stdout + r.stderr)[-5000:])

def _metrics_gate() -> None:
    sys.path.insert(0, str(PARLIAMENT_DIR))
    try:
        import evolve, metrics
        baseline = evolve.load_baseline()
        if not baseline.get("metrics"): raise NeuroError("EVOLUTION baseline відсутній — 3% gate не може підтвердити зміни")
        deviations = evolve.detect(metrics.collect(), baseline)
        if deviations:
            details = "; ".join(f"{d['metric']} {d['deviation_pct']}%" for d in deviations[:12])
            raise NeuroError("3% GATE BLOCKED: " + details)
    except NeuroError: raise
    except Exception as exc: raise NeuroError(f"помилка EVOLUTION metrics: {exc}") from exc

def _make_dump(patch_id: str, paths: list[str]):
    DUMPS.mkdir(parents=True, exist_ok=True)
    dump = DUMPS / f"golden_{patch_id}.tar.gz"
    files = {}
    with tarfile.open(dump, "w:gz") as tar:
        for raw in paths:
            p = safe_source_path(raw)
            files[raw] = sha256_bytes(p.read_bytes())
            tar.add(p, arcname=raw, recursive=False)
    meta = {"dump": dump.name, "sha256": sha256_bytes(dump.read_bytes()), "patch_id": patch_id,
            "created": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "files": files}
    dump.with_suffix(".json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n")
    return dump, meta

def _restore_dump(dump: Path, expected: dict) -> None:
    if sha256_bytes(dump.read_bytes()) != expected["sha256"]: raise NeuroError("Golden Dump SHA256 mismatch")
    with tarfile.open(dump, "r:gz") as tar:
        for member in tar.getmembers():
            raw = member.name
            if raw not in expected["files"] or not member.isfile(): raise NeuroError(f"неочікуваний файл у dump: {raw}")
            target = safe_source_path(raw)
            stream = tar.extractfile(member)
            if stream is None: raise NeuroError(f"не вдалося прочитати dump: {raw}")
            data = stream.read(MAX_FILE_BYTES + 1)
            if len(data) > MAX_FILE_BYTES or sha256_bytes(data) != expected["files"][raw]:
                raise NeuroError(f"SHA256 preimage mismatch: {raw}")
            tmp = target.with_name(target.name + ".neuro-restore.tmp")
            tmp.write_bytes(data)
            os.replace(tmp, target)

def _restart(target: str) -> None:
    cfg = ROOT / "config" / "pm_processes.json"
    if not cfg.is_file(): raise NeuroError("немає config/pm_processes.json; перезапуск заборонено")
    try: proc = json.loads(cfg.read_text()).get("processes", {}).get(target)
    except Exception as exc: raise NeuroError(f"помилка PM config: {exc}") from exc
    if not proc or target == "supervisor" or not proc.get("enabled", True) or proc.get("_phone_disabled", False):
        raise NeuroError(f"процес не дозволений для перезапуску: {target}")
    r = _run(["cybra-pm", "restart", target], 90)
    if r.returncode: raise NeuroError(f"cybra-pm restart FAIL: {(r.stderr or r.stdout)[:1500]}")
    sys.path.insert(0, str(ROOT / "modules" / "module_300_pm"))
    try:
        import supervisor
        running, info = supervisor.is_running(proc)
        if not running: raise NeuroError(f"процес {target} не піднявся: {info}")
    except NeuroError: raise
    except Exception as exc: raise NeuroError(f"не вдалося підтвердити процес: {exc}") from exc

def apply(patch_id: str, restart_target: str) -> None:
    folder = STAGING / patch_id
    mf = folder / "manifest.json"
    if not mf.is_file(): raise NeuroError("patch не знайдений")
    manifest = json.loads(mf.read_text())
    if manifest.get("status") != "submitted" or not manifest.get("parliament_pid"):
        raise NeuroError("спочатку виконай propose")
    P = _parliament()
    proposal = P.get_proposal(manifest["parliament_pid"])
    if not proposal or proposal.get("status") != "approved": raise NeuroError("Parliament ще не схвалив пропозицію")
    payload = proposal.get("payload", {})
    if payload.get("neuro_patch_id") != patch_id or payload.get("files") != manifest["files"]:
        raise NeuroError("Parliament payload не збігається зі staged patch")
    paths, staged = list(manifest["files"]), {}
    for raw in paths:
        target = safe_source_path(raw)
        if sha256_bytes(target.read_bytes()) != manifest["files"][raw]["before_sha256"]:
            raise NeuroError(f"файл змінився після генерації: {raw}")
        data = (folder / "files" / raw).read_bytes()
        if sha256_bytes(data) != manifest["files"][raw]["after_sha256"]: raise NeuroError(f"staged SHA mismatch: {raw}")
        staged[raw] = data
    dump, dump_meta = _make_dump(patch_id, paths)
    print(f"GOLDEN_DUMP={dump}\nGOLDEN_DUMP_SHA256={dump_meta['sha256']}")
    try:
        for raw, data in staged.items():
            target = safe_source_path(raw)
            tmp = target.with_name(target.name + ".neuro.tmp")
            tmp.write_bytes(data)
            os.replace(tmp, target)
        _test_changed_files(paths)
        _full_tests()
        _metrics_gate()
        _restart(restart_target)
        _full_tests()
        _metrics_gate()
    except Exception as exc:
        print(f"APPLY_FAILED={exc}", file=sys.stderr)
        _restore_dump(dump, dump_meta)
        try:
            _test_changed_files(paths)
            _restart(restart_target)
        except Exception as restore_exc:
            raise NeuroError(f"код відновлено з dump, але перевірка/перезапуск відкату потребує уваги: {restore_exc}") from exc
        manifest.update({"status": "rolled_back", "failure": str(exc)[:2000], "golden_dump": dump.name})
        mf.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
        raise NeuroError("PATCH ВІДКОЧЕНО до Golden Dump") from exc
    manifest.update({"status": "applied", "golden_dump": dump.name,
                     "applied": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())})
    mf.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(f"NEURO_APPLY=SUCCESS\nRESTARTED={restart_target}\n3%_GATE=PASS\nTEST_SUITE=PASS")

def status() -> None:
    for mf in sorted(STAGING.glob("*/manifest.json")):
        try:
            m = json.loads(mf.read_text())
            print(f"{m.get('id')} | {m.get('status')} | parliament={m.get('parliament_pid','-')} | files={len(m.get('files',{}))}")
        except Exception: print(f"INVALID MANIFEST: {mf}")

def main() -> int:
    ap = argparse.ArgumentParser(description="CYBRA NEURO — staged code writer")
    sub = ap.add_subparsers(dest="cmd", required=True)
    g = sub.add_parser("generate"); g.add_argument("--task", required=True); g.add_argument("files", nargs="+")
    p = sub.add_parser("propose"); p.add_argument("patch_id")
    a = sub.add_parser("apply"); a.add_argument("patch_id"); a.add_argument("--restart", required=True)
    sub.add_parser("status")
    args = ap.parse_args()
    try:
        if args.cmd == "generate": generate(args.task, args.files)
        elif args.cmd == "propose": propose(args.patch_id)
        elif args.cmd == "apply": apply(args.patch_id, args.restart)
        else: status()
        return 0
    except Exception as exc:
        print(f"NEURO_ERROR: {exc}", file=sys.stderr)
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
