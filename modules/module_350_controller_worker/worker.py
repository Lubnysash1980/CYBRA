#!/usr/bin/env python3
"""Controller Worker v2 — 3% deviation + heal до 100% + signatures.

Цикл:
  1. Snapshot метрик → порівняти з baseline → 3% deviation
  2. Якщо devs > 0 → heal loop до 100%
  3. Контролери (8) → heal до 100%
  4. Signatures обох сторін
  5. Health → heal до 100%
  6. Completion → до 100%
  7. Процеси → start-all

Працює поки all_ok=True. Max спроб heal=5.
"""
import json, os, subprocess, sys, time, signal
from pathlib import Path

H = Path.home() / "CYBRA"
M = H / "modules"
D = Path(__file__).resolve().parent
LOG = D / "data" / "worker.log"
STATE = D / "data" / "worker_state.json"
BASELINE = D / "data" / "worker_baseline.json"

RUN = True
def stop(*a):
    global RUN; RUN = False
    _log("stop signal")
signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)

def _now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def _log(msg, level="info"):
    line = f"[{_now()}] [{level}] {msg}"
    print(line, flush=True)
    try:
        with open(LOG, "a") as f: f.write(line + "\n")
        if LOG.stat().st_size > 500_000:
            lines = LOG.read_text().splitlines()
            LOG.write_text("\n".join(lines[-500:]) + "\n")
    except Exception: pass

def _run(cmd, timeout=90):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout + r.stderr).strip()
    except Exception as e:
        return 1, str(e)[:200]

# ═══ SNAPSHOT метрик для 3% ═══
def gate_status():
    """Отримує 100% gate стан."""
    try:
        sys.path.insert(0, str(M/"module_399_gate"))
        import gate
        ok, s = gate.is_100()
        return ok, s
    except Exception: return False, {}

def sic_snapshot():
    """Отримує SIC snapshot."""
    try:
        sys.path.insert(0, str(M/"module_380_sic"))
        import sic
        return sic.snapshot()
    except Exception: return {}

def load_mapping():
    """Завантажує mapping для пріоритезації."""
    try:
        sys.path.insert(0, str(M/"module_360_mapping"))
        import mapping
        return mapping.load()
    except Exception: return {"items": {}}

def snapshot():
    """Збирає метрики."""
    m = {"ts": _now(), "ts_unix": int(time.time())}
    # controllers
    try:
        sys.path.insert(0, str(M/"module_320_controllers"))
        import controllers
        ctrls = controllers.check_all()
        m["controllers_ok"] = sum(1 for c in ctrls if c["ok"])
        m["controllers_total"] = len(ctrls)
    except Exception: pass
    # health
    try:
        sys.path.insert(0, str(M/"module_121_parlament"))
        import health
        h = health.health_all()
        m["health"] = h.get("overall", 0)
    except Exception: pass
    # completion
    try:
        import completion
        m["completion"] = completion.completion_score().get("overall", 0)
    except Exception: pass
    # signatures
    try:
        import controllers
        sig_ok = next((c["ok"] for c in ctrls if c["id"]=="signatures"), None)
        m["signatures_ok"] = sig_ok
    except Exception: pass
    # processes
    rc, out = _run("cybra-pm list", timeout=15)
    m["processes_offline"] = out.count("○ offline")
    # disk
    import shutil
    try:
        _, _, free = shutil.disk_usage(str(H))
        m["disk_free_mb"] = free // (1024*1024)
    except Exception: pass
    return m

def load_baseline():
    if not BASELINE.exists(): return None
    try: return json.loads(BASELINE.read_text())
    except Exception: return None

def save_baseline(m):
    BASELINE.write_text(json.dumps({"metrics": m, "at": _now()}, indent=2))

def detect_deviation(current, baseline):
    """3% deviation detection."""
    if not baseline or not baseline.get("metrics"): return []
    base = baseline["metrics"]
    devs = []
    # пороги
    RULES = {
        "controllers_ok": {"dir":"up_good", "min_abs": 0},   # 1 контролер = критично
        "health":         {"dir":"up_good", "min_abs": 3},   # 3% health
        "completion":     {"dir":"up_good", "min_abs": 3},
        "processes_offline": {"dir":"down_good", "min_abs": 1},
        "disk_free_mb":   {"dir":"up_good", "min_abs": 500},
    }
    for key, rule in RULES.items():
        if key not in current or key not in base: continue
        cur, base_v = current[key], base[key]
        if cur == base_v: continue
        try:
            cur_f, base_f = float(cur), float(base_v)
        except Exception: continue
        # min_abs
        if abs(cur_f - base_f) < rule["min_abs"]: continue
        # для up_good: якщо впало
        if rule["dir"] == "up_good" and cur_f < base_f:
            dev = (base_f - cur_f) / max(abs(base_f), 1) * 100
            devs.append({"metric": key, "cur": cur, "base": base_v,
                        "dev_pct": round(dev, 2), "dir": "drop"})
        # для down_good: якщо виросло
        elif rule["dir"] == "down_good" and cur_f > base_f:
            dev = (cur_f - base_f) / max(abs(base_f), 1) * 100
            devs.append({"metric": key, "cur": cur, "base": base_v,
                        "dev_pct": round(dev, 2), "dir": "rise"})
    return devs

# ═══ CHECKS ═══
def check_controllers():
    try:
        sys.path.insert(0, str(M/"module_320_controllers"))
        import controllers
        results = controllers.check_all()
        return all(c["ok"] for c in results), results
    except Exception as e:
        return False, [{"ok": False, "name":"loader", "msg": str(e)[:100]}]

def check_health():
    try:
        sys.path.insert(0, str(M/"module_121_parlament"))
        import health
        return health.health_all()
    except Exception as e:
        return {"overall": 0, "error": str(e)[:100]}

def check_completion():
    try:
        sys.path.insert(0, str(M/"module_121_parlament"))
        import completion
        return completion.completion_score().get("overall", 0)
    except Exception: return 0

def check_processes():
    rc, out = _run("cybra-pm list", timeout=15)
    return out.count("○ offline") + out.count("offline")

# ═══ HEAL ═══
def heal_controllers():
    return _run(f"python3 {M}/module_330_selfheal/engine.py cycle", timeout=120)

def heal_health():
    return _run(f"python3 {M}/module_121_parlament/health.py heal", timeout=90)

def heal_completion():
    return _run(f"python3 {M}/module_121_parlament/completion.py run", timeout=120)

def heal_processes():
    return _run("cybra-pm start-all", timeout=60)

def heal_signatures():
    """Для непідписаних — не автоматично, тільки лог."""
    return (True, "signature heal: manual (підпис у MetaMask)")

# ═══ CYCLE ═══
def cycle(max_heal_rounds=5, verbose=True):
    t0 = time.time()
    rounds = []
    # Cascade tests
    try:
        sys.path.insert(0, str(M/"module_401_cascade_verify"))
        import verify as CV
        ok_c, stats, issues = CV.check_cascade()
        if verbose:
            _log(f"cascade: {'✓' if ok_c else '✗'} {stats}")
    except Exception: pass

    # GATE check (пріоритет)
    g_ok, g_s = gate_status()
    if verbose:
        _log(f"gate: {'100% ✓' if g_ok else 'заблоковано'} (health={g_s.get('health',0)}% ctrl={g_s.get('controllers_ok',0)}/{g_s.get('controllers_total',0)})")

    # SIC
    s = sic_snapshot()
    if verbose and s:
        _log(f"sic: {s.get('modules_total',0)} модулів, {s.get('matrix_edges',0)} зв'язків, конфліктів: {s.get('conflicts',0)}")

    # mapping report
    m = load_mapping()
    if verbose and m.get("items"):
        _log(f"mapping: {len(m['items'])} пунктів")
        # критичні
        crit = [it for it in m["items"].values() if it["priority"] == 1]
        _log(f"  критичних (P1): {len(crit)}")

    for rnd in range(max_heal_rounds):
        ok_all = True
        actions = []

        # snapshot + 3%
        cur = snapshot()
        base = load_baseline()
        devs = detect_deviation(cur, base) if base else []

        if not base:
            save_baseline(cur)
            _log("baseline init")
            return {"round": 0, "state": "baseline_init", "metrics": cur}

        # логуємо devs
        if devs and verbose:
            _log(f"3% devs: {len(devs)}")
            for d in devs:
                _log(f"  [{d['dir']}] {d['metric']}: {d['base']} → {d['cur']}  ({d['dev_pct']:+.1f}%)")

        # 1. Контролери
        c_ok, ctrls = check_controllers()
        bad = [c for c in ctrls if not c["ok"]]
        if bad:
            ok_all = False
            _log(f"controllers: {len(bad)}/{len(ctrls)} bad")
            for c in bad:
                _log(f"  ✗ {c['name']}: {c['msg'][:60]}")
            heal_controllers()
            actions.append("heal_controllers")

        # 2. Signatures
        sig_ctrl = next((c for c in ctrls if c.get("id")=="signatures"), None)
        if sig_ctrl and not sig_ctrl["ok"]:
            _log(f"signatures: {sig_ctrl['msg']}")
            # Не лікуємо автоматично — тільки лог
            actions.append("signatures_notified")

        # 3. Health
        h = check_health()
        if h.get("overall", 0) < 100:
            ok_all = False
            _log(f"health: {h['overall']}% < 100 → heal")
            heal_health()
            actions.append("heal_health")

        # 4. Completion
        comp = check_completion()
        if comp < 100:
            ok_all = False
            _log(f"completion: {comp}% < 100 → run")
            heal_completion()
            actions.append("heal_completion")

        # 5. Процеси
        off = check_processes()
        if off > 0:
            ok_all = False
            _log(f"processes offline: {off} → start-all")
            heal_processes()
            actions.append("heal_processes")

        rounds.append({
            "round": rnd + 1,
            "ok": ok_all,
            "actions": actions,
            "devs": len(devs),
            "health": h.get("overall", 0),
            "completion": comp,
            "controllers_ok": sum(1 for c in ctrls if c["ok"]),
            "controllers_total": len(ctrls),
        })

        if ok_all:
            _log(f"✓ все 100% на раунді {rnd+1}")
            break
        else:
            _log(f"раунд {rnd+1} не 100% → повтор")
            time.sleep(3)

    # фінальний snapshot
    final = snapshot()
    save_baseline(final)  # оновлюємо baseline

    duration = int((time.time()-t0)*1000)
    state = {
        "at": _now(),
        "duration_ms": duration,
        "rounds": rounds,
        "final": final,
        "all_ok": all(r["ok"] for r in rounds) if rounds else False,
    }
    STATE.write_text(json.dumps(state, indent=2, ensure_ascii=False))
    _log(f"cycle done: {len(rounds)} раундів, {duration}ms, all_ok={state['all_ok']}")

    if verbose:
        G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[36m'; N='\033[0m'
        print(f"\n  {B}Результат:{N}")
        for r in rounds:
            col = G if r["ok"] else Y
            print(f"    {col}раунд {r['round']}{N}:  "
                  f"ctrl={r['controllers_ok']}/{r['controllers_total']} "
                  f"health={r['health']}% comp={r['completion']}% "
                  f"devs={r['devs']} actions={r['actions']}")
        print(f"  {B}Фінал:{N} all_ok={state['all_ok']} ({duration}ms)")

    return state

def daemon(interval=300):
    _log(f"═══ Controller Worker v2 START · interval={interval}s ═══")
    while RUN:
        try: cycle(verbose=False)
        except Exception as e: _log(f"error: {e}", level="error")
        for _ in range(interval):
            if not RUN: break
            time.sleep(1)
    _log("═══ STOP ═══")

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "cycle"
    if cmd == "cycle": cycle()
    elif cmd == "daemon":
        iv = int(sys.argv[2]) if len(sys.argv) > 2 else 300
        daemon(iv)
    elif cmd == "snapshot":
        print(json.dumps(snapshot(), indent=2))
    elif cmd == "status":
        if STATE.exists(): print(STATE.read_text())
        else: print("(не запускався)")
    elif cmd == "log":
        n = int(sys.argv[2]) if len(sys.argv) > 2 else 30
        if LOG.exists(): print("\n".join(LOG.read_text().splitlines()[-n:]))
        else: print("(немає логу)")
