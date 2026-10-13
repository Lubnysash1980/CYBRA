"""Реєстр дій парламенту.
Кожна дія: id, name, level (auto|vote|veto), fn, check_ids (для яких проблем)
"""
import subprocess, os, shutil, stat, time, json
from pathlib import Path

H = Path.home() / "CYBRA"
LOG = H / "modules/module_121_parlament/data/exec_log.jsonl"

def _log(entry):
    entry["ts"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    with open(LOG, "a") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")

def _run(cmd, timeout=180):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout + r.stderr)[:400]
    except subprocess.TimeoutExpired:
        return 124, "timeout"

# ─── фікси (кожен повертає (ok, msg)) ───────────────────────
def _chmod_key(path):
    p = Path(path)
    if not p.exists(): return False, f"не існує: {path}"
    os.chmod(p, 0o600)
    return True, f"chmod 600 {path}"

def _chmod_exec(path):
    p = Path(path)
    if not p.exists(): return False, f"не існує: {path}"
    os.chmod(p, stat.S_IMODE(p.stat().st_mode) | 0o755)
    return True, f"chmod +x {path}"

def _rm_dead_pid(path):
    p = Path(path)
    if p.exists(): p.unlink(); return True, f"видалено {path}"
    return True, "не існував"

def _install_pkg(pkg):
    rc, out = _run(f"pkg install -y {pkg}", timeout=300)
    return rc == 0, f"pkg {pkg} rc={rc}"

def _pip_install(mod):
    rc, out = _run(f"pip install --quiet {mod}", timeout=300)
    return rc == 0, f"pip {mod} rc={rc}"

def _restart_autonode():
    m = H / "modules/module_114_autonode/main.sh"
    if not m.exists(): return False, "модуль 114 відсутній"
    _run(f"bash {m} stop", 20)
    rc, _ = _run(f"bash {m} start", 20)
    return rc == 0, f"autonode restart rc={rc}"

def _cleanup_logs():
    cutoff = time.time() - 7 * 86400
    removed = 0
    for d in [H/"logs", H/"run"]:
        if not d.exists(): continue
        for f in d.glob("*"):
            if f.is_file() and f.stat().st_mtime < cutoff:
                try: f.unlink(); removed += 1
                except Exception: pass
    return True, f"видалено {removed} старих"

def _git_commit(msg):
    repo = H if (H/".git").exists() else None
    if not repo: return False, "немає .git"
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    _run(f'git -C {repo} add -A', 30)
    rc, _ = _run(f'git -C {repo} commit -m "parlament: {msg or ts}" --allow-empty', 30)
    return rc == 0, f"git commit rc={rc}"

def _restore_tui():
    bin_dir = H / "modules/module_19_contract_tui_menu/bin"
    baks = sorted(bin_dir.glob("cybra_menu.sh.bak.*"),
                  key=lambda p: p.stat().st_mtime, reverse=True)
    if not baks: return False, "немає бекапів"
    src = baks[0]; dst = bin_dir / "cybra_menu.sh"
    rc, _ = _run(f"bash -n {src}", 10)
    if rc != 0: return False, f"бекап {src.name} зламаний"
    shutil.copy2(dst, f"{dst}.before_restore.{int(time.time())}")
    shutil.copy2(src, dst)
    return True, f"відкочено з {src.name}"

def _create_tui_backup():
    bin_dir = H / "modules/module_19_contract_tui_menu/bin"
    src = bin_dir / "cybra_menu.sh"
    if not src.exists(): return False, "TUI немає"
    bak = src.with_suffix(f".sh.bak.manual.{int(time.time())}")
    shutil.copy2(src, bak)
    return True, f"бекап: {bak.name}"


def _do_undo_last():
    try:
        import undo
        u, f = undo.undo_last(1)
        if u: return True, f"відкочено: {u[0]['action']}"
        return False, f"немає що відкочувати ({f})"
    except Exception as e:
        return False, f"undo: {e}"

# ─── реєстр ─────────────────────────────────────────────────
# level: auto  — парламент виконує сам (безпечно)
#        vote  — потрібне голосування (звичайне)
#        veto  — потрібен founder + кворум (небезпечно)
ACTIONS = {
    # ─── AUTO (безпечні) ───
    "chmod_key_600": {
        "name": "Виправити права ключа → 600",
        "level": "auto",
        "check": lambda cid: cid.startswith("key.") and "права" in cid,
        "fn": lambda target: _chmod_key(target),
        "detect": "check_files",
    },
    "chmod_exec": {
        "name": "Зробити файл виконуваним",
        "level": "auto",
        "check": lambda cid: cid.startswith("file.") and cid.endswith(".sh"),
        "fn": lambda target: _chmod_exec(target),
    },
    "rm_dead_pid": {
        "name": "Прибрати мертвий PID-файл",
        "level": "auto",
        "check": lambda cid: cid == "autonode.running",
        "fn": lambda target: _rm_dead_pid(target),
    },
    "create_tui_backup": {
        "name": "Створити бекап TUI перед змінами",
        "level": "auto",
        "check": lambda cid: cid.startswith("tui."),
        "fn": lambda target: _create_tui_backup(),
    },
    # ─── VOTE (потрібне голосування) ───
    "install_pkg": {
        "name": "Встановити системний пакет",
        "level": "vote",
        "fn": lambda target: _install_pkg(target),
    },
    "pip_install": {
        "name": "Встановити Python-модуль",
        "level": "vote",
        "fn": lambda target: _pip_install(target),
    },
    "restart_autonode": {
        "name": "Перезапустити AutoNode",
        "level": "vote",
        "fn": lambda target: _restart_autonode(),
    },
    "cleanup_logs": {
        "name": "Очистити старі логи (>7 днів)",
        "level": "vote",
        "fn": lambda target: _cleanup_logs(),
    },
    "git_commit": {
        "name": "Автокоміт",
        "level": "vote",
        "fn": lambda target: _git_commit(target),
    },
    "undo_last": {
        "name": "Відкотити останню дію",
        "level": "auto",
        "fn": lambda target: _do_undo_last(),
    },
    # ─── VETO (тільки founder + кворум) ───
    "restore_tui": {
        "name": "Відкотити TUI з бекапу",
        "level": "veto",
        "fn": lambda target: _restore_tui(),
    },
}

def execute(action_id, target="", source="manual"):
    a = ACTIONS.get(action_id)
    if not a: return False, f"невідома дія: {action_id}"
    # знімок перед дією
    try:
        import undo
        undo.snapshot_before(action_id, target)
    except Exception: pass
    ok, msg = a["fn"](target)
    _log({"action": action_id, "target": target,
          "level": a["level"], "source": source,
          "ok": ok, "msg": msg})
    try:
        import stream
        stream.action(action_id, ok, msg, source)
    except Exception: pass
    return ok, msg

def recent(n=20):
    if not LOG.exists(): return []
    out = []
    for line in LOG.read_text().splitlines()[-n:]:
        try: out.append(json.loads(line))
        except Exception: pass
    return out
