#!/usr/bin/env python3
"""Mirror — парламент як джерело істини для інших пристроїв.
Пристрій-клон: клонує репо, отримує весь стан і код.
Пристрій-джерело: пушить зміни, інші пристрої стягують.
  · cybra mirror init <remote>    — налаштувати первинне джерело
  · cybra mirror clone <remote>   — під'єднати пристрій до джерела
  · cybra mirror status           — стан реплікації
  · cybra mirror resync           — повна синхронізація
"""
import json, os, sys, subprocess, time
from pathlib import Path

H = Path.home() / "CYBRA"
D = Path(__file__).resolve().parent
MIRROR_CFG = H / "config" / "mirror.json"

C_G='\033[32m'; C_R='\033[31m'; C_Y='\033[33m'; C_B='\033[36m'; C_N='\033[0m'

def _run(cmd, cwd=None, timeout=300):
    try:
        r = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True,
                           text=True, timeout=timeout)
        return r.returncode, (r.stdout + r.stderr).strip()
    except Exception as e: return 1, str(e)

def _load():
    if not MIRROR_CFG.exists(): return {"mode": "standalone"}
    try: return json.loads(MIRROR_CFG.read_text())
    except Exception: return {"mode": "standalone"}

def _save(d): MIRROR_CFG.write_text(json.dumps(d, indent=2))

def set_source(remote, branch="sync"):
    """Цей пристрій = джерело істини."""
    d = {"mode": "source", "remote": remote, "branch": branch,
         "since": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
    _save(d)
    # активувати sync
    sys.path.insert(0, str(D))
    import sync
    ok, m = sync.setup(remote, branch)
    return ok, f"source mode: {m}" if ok else m

def set_mirror(remote, branch="sync"):
    """Цей пристрій = дзеркало. Стягує з джерела."""
    d = {"mode": "mirror", "remote": remote, "branch": branch,
         "since": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
    _save(d)
    sys.path.insert(0, str(D))
    import sync
    # ініціалізація + pull
    ok, m = sync._ensure_repo()
    if not ok: return False, m
    _run("git remote remove origin 2>/dev/null", cwd=H)
    rc, _ = _run(f"git remote add origin {remote}", cwd=H)
    if rc != 0: return False, "remote add failed"
    _run(f"git checkout -q -B {branch}", cwd=H)
    rc, out = _run(f"git fetch origin {branch}", cwd=H, timeout=180)
    if rc != 0: return False, f"fetch: {out[:200]}"
    rc, out = _run(f"git reset --hard origin/{branch}", cwd=H, timeout=60)
    if rc != 0: return False, f"reset: {out[:200]}"
    # оновити sync config
    c = sync.cfg()
    c["enabled"] = True; c["remote"] = remote; c["branch"] = branch
    sync._save_cfg(c)
    return True, f"mirror mode під'єднано до {remote}"

def resync():
    """Повна синхронізація у режимі mirror."""
    d = _load()
    if d.get("mode") != "mirror":
        return False, "не в режимі mirror"
    sys.path.insert(0, str(D))
    import sync
    # зберегти локальні дані (щоб не втратити)
    _run("git stash -u 2>/dev/null", cwd=H)
    rc, out = _run(f"git fetch origin {d['branch']}", cwd=H, timeout=180)
    if rc != 0: return False, f"fetch: {out[:200]}"
    rc, out = _run(f"git reset --hard origin/{d['branch']}", cwd=H, timeout=60)
    if rc != 0: return False, out[:200]
    # перезапустити сервіси
    _run("bash " + str(D.parent/"module_114_autonode/main.sh") + " restart", timeout=30)
    _run("bash " + str(D.parent/"module_121_parlament/watchdog.sh") + " stop", timeout=20)
    _run("bash " + str(D.parent/"module_121_parlament/watchdog.sh") + " start", timeout=20)
    return True, "resynced + services restarted"

def status():
    d = _load()
    out = {"mode": d.get("mode", "standalone"), "config": d}
    if (H/".git").exists():
        rc, br = _run("git rev-parse --abbrev-ref HEAD", cwd=H)
        rc2, ahead = _run(f"git rev-list --count @{{u}}..HEAD 2>/dev/null", cwd=H)
        rc3, behind = _run(f"git rev-list --count HEAD..@{{u}} 2>/dev/null", cwd=H)
        out["branch"] = br.strip()
        out["ahead"] = int((ahead.strip() or "0").split("\n")[-1] or "0")
        out["behind"] = int((behind.strip() or "0").split("\n")[-1] or "0")
    return out

def print_status():
    s = status()
    mode = s["mode"]
    col = {"source": C_G, "mirror": C_Y, "standalone": C_N}.get(mode, C_N)
    print(f"\n{C_B}═══ CYBRA Mirror ═══{C_N}\n")
    print(f"  Режим:   {col}{mode}{C_N}")
    if "config" in s and s["config"].get("remote"):
        print(f"  Remote:  {s['config']['remote']}")
        print(f"  Branch:  {s['config'].get('branch','sync')}")
    if "ahead" in s:
        print(f"  AHEAD:   {s['ahead']}")
        print(f"  BEHIND:  {s['behind']}")
    print()

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "init":
        if len(sys.argv) < 3: print("usage: mirror.py init <remote>"); sys.exit(1)
        ok, m = set_source(sys.argv[2], sys.argv[3] if len(sys.argv)>3 else "sync")
        print(("✓ " if ok else "✗ ")+m)
    elif cmd == "clone":
        if len(sys.argv) < 3: print("usage: mirror.py clone <remote>"); sys.exit(1)
        ok, m = set_mirror(sys.argv[2], sys.argv[3] if len(sys.argv)>3 else "sync")
        print(("✓ " if ok else "✗ ")+m)
    elif cmd == "status": print_status()
    elif cmd == "resync":
        ok, m = resync(); print(("✓ " if ok else "✗ ")+m)
    elif cmd == "json": print(json.dumps(status(), indent=2))
