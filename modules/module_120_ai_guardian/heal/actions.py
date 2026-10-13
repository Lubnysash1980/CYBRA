"""
Кожна дія: {id, name, level, can_auto, fn}
level: safe (можна auto) | warn (запит) | danger (тільки --force)
"""
import subprocess, os, shutil, stat, time
from pathlib import Path

H = Path.home() / "CYBRA"

def _run(cmd, timeout=60):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout, r.stderr
    except subprocess.TimeoutExpired:
        return 124, "", "timeout"

# ── safe ────────────────────────────────────────────────────
def fix_chmod_key(target):
    f = Path(target)
    if not f.exists(): return False, "не існує"
    os.chmod(f, 0o600)
    return True, f"chmod 600 {f}"

def fix_chmod_exec(target):
    f = Path(target)
    if not f.exists(): return False, "не існує"
    m = stat.S_IMODE(f.stat().st_mode) | 0o755
    os.chmod(f, m)
    return True, f"chmod +x {f}"

def fix_remove_dead_pid(pid_file):
    p = Path(pid_file)
    if p.exists():
        p.unlink()
        return True, f"rm {p}"
    return False, "не існує"

def fix_clear_nonce_dryrun(path):
    # НЕ чіпаємо справжні nonce — тільки репорт
    return False, "потребує підтвердження"

# ── warn ────────────────────────────────────────────────────
def fix_install_pkg(pkg):
    rc, out, err = _run(f"pkg install -y {pkg}", timeout=180)
    return rc == 0, f"pkg install {pkg}: rc={rc}"

def fix_pip_install(mod):
    rc, out, err = _run(f"pip install --quiet {mod}", timeout=180)
    return rc == 0, f"pip install {mod}: rc={rc}"

def fix_restart_autonode():
    main = H / "modules/module_114_autonode/main.sh"
    if not main.exists(): return False, "модуль 114 не встановлено"
    _run(f"bash {main} stop", timeout=20)
    rc, _, _ = _run(f"bash {main} start", timeout=20)
    return rc == 0, f"autonode restart: rc={rc}"

def fix_cleanup_logs():
    """Ротація: залишає останні 7 днів."""
    cutoff = time.time() - 7*86400
    removed = 0
    for d in [H/"logs", H/"run"]:
        if not d.exists(): continue
        for f in d.glob("*"):
            if f.is_file() and f.stat().st_mtime < cutoff:
                try: f.unlink(); removed += 1
                except Exception: pass
    return True, f"видалено {removed} старих файлів"

def fix_git_commit(msg=None):
    """Автокоміт — тільки якщо є .git."""
    repo = H if (H/".git").exists() else None
    if not repo: return False, "немає git-репо"
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    m = msg or f"guardian: auto-snapshot {ts}"
    _run(f'git -C {repo} add -A', timeout=30)
    rc, _, _ = _run(f'git -C {repo} commit -m "{m}" --allow-empty', timeout=30)
    return rc == 0, f"git commit: rc={rc}"

# ── danger ──────────────────────────────────────────────────
def fix_reinstall_tui_from_backup():
    """Відкотити TUI з останнього .bak."""
    bin_dir = H / "modules/module_19_contract_tui_menu/bin"
    baks = sorted(bin_dir.glob("cybra_menu.sh.bak.*"),
                  key=lambda p: p.stat().st_mtime, reverse=True)
    if not baks: return False, "немає бекапів"
    src = baks[0]
    dst = bin_dir / "cybra_menu.sh"
    # перевірка що бекап живий
    rc, _, _ = _run(f"bash -n {src}", timeout=10)
    if rc != 0: return False, f"бекап {src.name} зламаний"
    shutil.copy2(dst, f"{dst}.before_restore.{int(time.time())}")
    shutil.copy2(src, dst)
    return True, f"відкочено з {src.name}"

# ─── таблиця ────────────────────────────────────────────────
ACTIONS = {
    # safe — auto
    "chmod_key_600":     {"level":"safe","auto":True, "fn": lambda t: fix_chmod_key(t)},
    "chmod_exec":        {"level":"safe","auto":True, "fn": lambda t: fix_chmod_exec(t)},
    "remove_dead_pid":   {"level":"safe","auto":True, "fn": lambda t: fix_remove_dead_pid(t)},
    # warn — за підтвердженням
    "install_pkg":       {"level":"warn","auto":False,"fn": lambda t: fix_install_pkg(t)},
    "pip_install":       {"level":"warn","auto":False,"fn": lambda t: fix_pip_install(t)},
    "restart_autonode":  {"level":"warn","auto":False,"fn": lambda t: fix_restart_autonode()},
    "cleanup_logs":      {"level":"warn","auto":False,"fn": lambda t: fix_cleanup_logs()},
    "git_commit":        {"level":"warn","auto":False,"fn": lambda t: fix_git_commit(t)},
    # danger — тільки з --force
    "restore_tui":       {"level":"danger","auto":False,"fn": lambda t: fix_reinstall_tui_from_backup()},
}
