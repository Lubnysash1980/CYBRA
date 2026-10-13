#!/usr/bin/env python3
"""Синхронізація парламентських даних через git (remote parliament)."""
import sys, os, subprocess, time, json
from pathlib import Path

D = Path(__file__).resolve().parent
DATA = D / "data"
CFG = D / "git_sync.json"

DEFAULT = {
    "enabled": False,
    "remote": "",           # git remote URL
    "branch": "parlament",
    "autopush": True,
    "autopull": True,
    "conflict_policy": "union",   # union | mine | theirs
}

def _cfg():
    c = dict(DEFAULT)
    if CFG.exists():
        try: c.update(json.loads(CFG.read_text()))
        except Exception: pass
    return c

def _save(c):
    CFG.write_text(json.dumps(c, indent=2))

def _run(cmd, cwd=None, timeout=60):
    try:
        r = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True,
                           text=True, timeout=timeout)
        return r.returncode, (r.stdout + r.stderr).strip()
    except Exception as e:
        return 1, str(e)

def _ensure_repo():
    if (DATA / ".git").exists(): return True, "ok"
    rc, out = _run("git init -q", cwd=DATA)
    if rc != 0: return False, out
    _run("git config user.email parliament@cybra.local", cwd=DATA)
    _run("git config user.name 'CYBRA Parliament'", cwd=DATA)
    # .gitignore — щоб не тягнути бекапи
    (DATA / ".gitignore").write_text(
        "*.tmp\n*.log\nundo/\n")
    _run("git add -A && git commit -q -m 'init: parliament data' --allow-empty",
         cwd=DATA)
    return True, "created"

def setup(remote, branch="parlament"):
    c = _cfg(); c["remote"] = remote; c["branch"] = branch; c["enabled"] = True
    _save(c)
    ok, msg = _ensure_repo()
    if not ok: return False, msg
    rc, out = _run(f"git remote remove origin 2>/dev/null; git remote add origin {remote}", cwd=DATA)
    if rc != 0: return False, out
    return True, f"remote: {remote}"

def snapshot(msg=None):
    """Комітить поточний стан парламентських даних."""
    c = _cfg()
    ok, _ = _ensure_repo()
    if not ok: return False, "repo init fail"
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    m = msg or f"parlament: snapshot {ts}"
    _run("git add -A", cwd=DATA)
    rc, out = _run(f'git commit -q -m "{m}" --allow-empty', cwd=DATA)
    return True, m

def push():
    c = _cfg()
    if not c["remote"]: return False, "remote не налаштовано"
    _run(f"git checkout -q -B {c['branch']}", cwd=DATA)
    rc, out = _run(f"git push -q origin {c['branch']}", cwd=DATA, timeout=120)
    return rc == 0, out[:200]

def pull():
    c = _cfg()
    if not c["remote"]: return False, "remote не налаштовано"
    rc, out = _run(f"git fetch -q origin {c['branch']}", cwd=DATA, timeout=120)
    if rc != 0: return False, out[:200]
    policy = c.get("conflict_policy", "union")
    if policy == "mine":
        rc, out = _run(f"git checkout -q --ours . 2>/dev/null; git merge -q origin/{c['branch']} -X ours", cwd=DATA, timeout=60)
    elif policy == "theirs":
        rc, out = _run(f"git merge -q origin/{c['branch']} -X theirs", cwd=DATA, timeout=60)
    else:
        # union — для jsonl це фактично конкатенація
        rc, out = _run(f"git merge -q origin/{c['branch']} -X ours", cwd=DATA, timeout=60)
        # для *.jsonl — вручну: конкатенація унікальних рядків
        if "*.jsonl" in out or rc != 0:
            _union_jsonl()
    return True, out[:200] or "pulled"

def _union_jsonl():
    """Зливає jsonl файли: об'єднує унікальні рядки по _hash."""
    for f in DATA.glob("*.jsonl"):
        base = f.read_text().splitlines()
        try:
            others = _run(f"git show origin/{_cfg()['branch']}:{f.name}", cwd=DATA)[1].splitlines()
        except Exception:
            continue
        seen = set(); merged = []
        for line in base + others:
            if not line.strip(): continue
            try: h = json.loads(line).get("_hash", line[:32])
            except Exception: h = line[:32]
            if h in seen: continue
            seen.add(h); merged.append(line)
        # сортуємо по ts якщо є
        def _ts(l):
            try: return json.loads(l).get("ts","")
            except Exception: return ""
        merged.sort(key=_ts)
        f.write_text("\n".join(merged) + "\n")

def sync(both=True):
    """snapshot + push + pull (обережно)."""
    c = _cfg()
    if not c["enabled"]: return {"ok": False, "reason": "не активовано"}
    out = {}
    if c.get("autopull", True):
        ok, msg = pull(); out["pull"] = msg
    ok, msg = snapshot(); out["commit"] = msg
    if both and c.get("autopush", True):
        ok, msg = push(); out["push"] = msg
    return {"ok": True, **out}

def status():
    c = _cfg()
    if not (DATA / ".git").exists():
        return {"enabled": c["enabled"], "repo": False}
    rc, log = _run("git log --oneline -5", cwd=DATA)
    rc2, remote = _run("git remote -v", cwd=DATA)
    rc3, br = _run("git rev-parse --abbrev-ref HEAD", cwd=DATA)
    return {
        "enabled": c["enabled"], "repo": True, "branch": br.strip(),
        "remote": remote.strip() or "(немає)",
        "last_commits": log.splitlines()
    }

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "setup":
        if len(sys.argv) < 3: print("usage: git_sync.py setup <remote_url> [branch]"); sys.exit(1)
        br = sys.argv[3] if len(sys.argv) > 3 else "parlament"
        ok, msg = setup(sys.argv[2], br)
        print(("✓ " if ok else "✗ ") + msg)
    elif cmd == "sync":
        print(json.dumps(sync(), indent=2, ensure_ascii=False))
    elif cmd == "status":
        print(json.dumps(status(), indent=2, ensure_ascii=False))
    elif cmd == "push":
        snapshot(); print(push())
    elif cmd == "pull":
        print(pull())
    elif cmd == "disable":
        c = _cfg(); c["enabled"] = False; _save(c); print("вимкнено")
