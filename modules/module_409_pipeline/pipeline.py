#!/usr/bin/env python3
"""Full Pipeline — test → fix → restart → github → test.
Один запуск робить все.
"""
import json, os, subprocess, sys, time
from pathlib import Path

H = Path.home() / "CYBRA"
M = H / "modules"
D = Path(__file__).resolve().parent
LOG = D / "data" / "pipeline.log"
STATE = D / "data" / "state.json"

def _now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
def _run(cmd, timeout=60, cwd=None):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True,
                          timeout=timeout, cwd=cwd)
        return r.returncode, (r.stdout + r.stderr).strip()
    except subprocess.TimeoutExpired:
        return 124, "timeout"
    except Exception as e:
        return 1, str(e)[:200]

def _log(msg, level="info"):
    line = f"[{_now()}] [{level}] {msg}"
    print(line, flush=True)
    try:
        with open(LOG, "a") as f: f.write(line + "\n")
        if LOG.stat().st_size > 1_000_000:
            lines = LOG.read_text().splitlines()
            LOG.write_text("\n".join(lines[-500:]) + "\n")
    except Exception: pass

def _step(n, name):
    print(f"\n{'='*60}\n  STEP {n}/8 — {name}\n{'='*60}")

# ═══════════════════════════════════════════════════════════════
# STEP 1: TEST
# ═══════════════════════════════════════════════════════════════
def step_test():
    _step(1, "TEST")
    code = 0
    try:
        sys.path.insert(0, str(M/"module_408_menu_tester"))
        import tester
        r = tester.test_all()
        c = r["counts"]
        print(f"  OK:    {c.get('OK',0)}")
        print(f"  STUB:  {c.get('STUB',0)}")
        print(f"  FAIL:  {c.get('FAIL',0)}")
        print(f"  MISS:  {c.get('MISS',0)}")
        # Зберегти fail/miss
        fails = [m for m,v in r["items"].items() if v["status"] in ("FAIL","MISS")]
        return {"ok": c.get("FAIL",0) == 0 and c.get("MISS",0) == 0,
                "counts": c, "fails": fails}
    except Exception as e:
        print(f"  ✗ {e}")
        return {"ok": False, "error": str(e)}

# ═══════════════════════════════════════════════════════════════
# STEP 2: FIX
# ═══════════════════════════════════════════════════════════════
def step_fix():
    _step(2, "AUTOFIX")
    try:
        sys.path.insert(0, str(M/"module_408_menu_tester"))
        import tester
        results = tester.run_all_stages()
        fixed = sum(1 for r in results if r["ok"])
        for r in results:
            mark = "✓" if r["ok"] else "✗"
            print(f"  {mark} {r['name']:35s}  {r['msg']}")
        return {"ok": fixed >= 6, "fixed": fixed, "total": len(results)}
    except Exception as e:
        print(f"  ✗ {e}")
        return {"ok": False, "error": str(e)}

# ═══════════════════════════════════════════════════════════════
# STEP 3: RESTART PM
# ═══════════════════════════════════════════════════════════════
def step_restart():
    _step(3, "RESTART PM")
    procs = ["tui_guard", "watchdog", "controller_worker", "selfheal",
             "autonode", "orchestrator", "dashboard"]
    ok = 0
    for p in procs:
        rc, out = _run(f"cybra-pm restart {p}", timeout=30)
        if rc == 0:
            ok += 1
            print(f"  ✓ {p}")
        else:
            print(f"  ! {p}: {out[:60]}")
        time.sleep(1)
    time.sleep(5)
    # Перевірка
    rc, out = _run("cybra-pm list", timeout=15)
    online = out.count("● online")
    print(f"\n  Online: {online}/{len(procs)}")
    return {"ok": online >= 5, "online": online, "total": len(procs)}

# ═══════════════════════════════════════════════════════════════
# STEP 4: GIT — pull/commit/push
# ═══════════════════════════════════════════════════════════════
def step_git():
    _step(4, "GITHUB")
    gm = H / "git_module"
    if not (gm / ".git").exists():
        # Спробувати CYBRA/.git
        gm = H
        if not (gm / ".git").exists():
            print("  ! немає git repo")
            return {"ok": False, "reason": "no repo"}

    # Remote?
    rc, remote = _run("git remote -v", cwd=str(gm), timeout=10)
    has_remote = "origin" in remote
    print(f"  Repo:   {gm}")
    print(f"  Remote: {'✓' if has_remote else '✗ немає'}")

    # Pull (якщо remote є)
    if has_remote:
        print(f"\n  Pull...")
        rc, out = _run("git pull --rebase origin main 2>&1 || git pull --rebase origin master 2>&1 || true",
                      cwd=str(gm), timeout=60)
        print(f"  {out[:150]}")

    # Add + commit
    _run("git add -A", cwd=str(gm), timeout=15)
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    rc, out = _run(f'git commit -m "pipeline: auto-fix {ts}" --allow-empty',
                  cwd=str(gm), timeout=30)
    print(f"\n  Commit: {'✓' if rc == 0 else 'skip'}")

    # Push (якщо remote є)
    if has_remote:
        rc, out = _run("git push origin HEAD 2>&1", cwd=str(gm), timeout=90)
        print(f"  Push: {'✓' if rc == 0 else '✗ ' + out[:100]}")

    return {"ok": True, "has_remote": has_remote, "repo": str(gm)}

# ═══════════════════════════════════════════════════════════════
# STEP 5: HEALTH + GATE
# ═══════════════════════════════════════════════════════════════
def step_health(max_retries=3, wait=10):
    _step(5, "HEALTH + GATE")
    h = {"overall": 0}
    ok = False
    for attempt in range(1, max_retries + 1):
        try:
            sys.path.insert(0, str(M/"module_121_parlament"))
            import health
            if "health" in sys.modules:
                import importlib
                importlib.reload(health)
            h = health.health_all()
            print(f"  Attempt {attempt}: {h['overall']}%")
            if attempt == 1:
                print(f"    Parliament:  {h['parliament']['score']}%")
                print(f"    System:      {h['system']['score']}%")
                for i in h.get("parliament", {}).get("issues", []):
                    print(f"      ! {i}")
                for i in h.get("system", {}).get("issues", []):
                    print(f"      ! {i}")
            if h.get("overall", 0) >= 100:
                break
        except Exception as e:
            print(f"  ✗ health attempt {attempt}: {e}")
        if attempt < max_retries:
            print(f"    чекаю {wait}s...")
            time.sleep(wait)

    try:
        sys.path.insert(0, str(M/"module_399_gate"))
        import gate
        if "gate" in sys.modules:
            import importlib
            importlib.reload(gate)
        ok, s = gate.is_100()
        print(f"\n  Gate: {'✓ ВІДКРИТО' if ok else '🚫 ЗАБЛОКОВАНО'}")
        print(f"  Controllers: {s.get('controllers_ok',0)}/{s.get('controllers_total',0)}")
        print(f"  NodeState:   {s.get('node_state', '?')}")
    except Exception as e:
        print(f"  ✗ gate: {e}")
        ok = False

    return {"ok": h.get("overall",0) >= 100, "health": h.get("overall",0), "gate": ok}

# ═══════════════════════════════════════════════════════════════
# STEP 6: WAIT
# ═══════════════════════════════════════════════════════════════
def step_wait(seconds=30):
    _step(6, f"WAIT {seconds}s")
    for i in range(seconds, 0, -5):
        print(f"  {i}s...")
        time.sleep(5)
    return {"ok": True}

# ═══════════════════════════════════════════════════════════════
# STEP 7: RETEST
# ═══════════════════════════════════════════════════════════════
def step_retest():
    _step(7, "RETEST")
    return step_test()

# ═══════════════════════════════════════════════════════════════
# STEP 8: REPORT
# ═══════════════════════════════════════════════════════════════
def step_report(results):
    _step(8, "REPORT")
    state = {
        "at": _now(),
        "results": results,
        "all_ok": all(r.get("ok", False) for r in results.values()),
    }
    STATE.write_text(json.dumps(state, indent=2, ensure_ascii=False))
    print()
    for k, v in results.items():
        mark = "✓" if v.get("ok") else "✗"
        print(f"  {mark} {k}")
    print(f"\n  {'✅ ALL OK' if state['all_ok'] else '⚠ Ще є проблеми'}")
    return state

# ═══════════════════════════════════════════════════════════════
# RUN
# ═══════════════════════════════════════════════════════════════
def run(wait_sec=30):
    _log("═══ PIPELINE START ═══")
    results = {}
    results["test_1"]   = step_test()
    results["fix"]      = step_fix()
    results["restart"]  = step_restart()
    results["wait"]     = step_wait(wait_sec)   # WAIT до health
    results["health"]   = step_health()          # retry внутри
    results["git"]      = step_git()
    results["test_2"]   = step_retest()
    state = step_report(results)
    _log(f"PIPELINE END: all_ok={state['all_ok']}")
    return state

if __name__ == "__main__":
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "run"
    if cmd == "run":
        wait = int(sys.argv[2]) if len(sys.argv) > 2 else 30
        run(wait_sec=wait)
    elif cmd == "state":
        if STATE.exists(): print(STATE.read_text())
    elif cmd == "log":
        n = int(sys.argv[2]) if len(sys.argv) > 2 else 50
        if LOG.exists(): print("\n".join(LOG.read_text().splitlines()[-n:]))
