#!/usr/bin/env python3
"""Еволюційний цикл парламенту з детекцією 3% відхилення.
Кожен цикл:
  1. Метрики → зберігає
  2. Baseline (rolling avg за N циклів)
  3. Порівнює: |dev| > threshold → авто-дія
  4. Оновлює baseline якщо стабільно
"""
import json, os, sys, time, subprocess, shutil
from pathlib import Path

D = Path(__file__).resolve().parent
H = Path.home() / "CYBRA"
M = H / "modules"
sys.path.insert(0, str(D))

BASE = D / "data" / "evolve" / "baseline.json"
LOG  = D / "data" / "evolve" / "log.jsonl"
CFG  = H / "config" / "evolve.json"

DEFAULT_CFG = {
    "threshold_pct": 3.0,       # базовий поріг
    "critical_pct": 15.0,       # критичний поріг
    "baseline_window": 10,      # N останніх циклів для baseline
    "auto_act": True,           # чи виконувати дії без запиту
    "cooldown_sec": 300,        # мінімум між однаковими діями
    "metrics": {
        # метрика: напрям ("up_good" / "down_good" / "stable")
        "tests_success_rate": {"dir":"up_good",   "weight":1.0},
        "stream_error_rate":  {"dir":"down_good", "weight":1.0},
        "actions_fail_rate":  {"dir":"down_good", "weight":0.8},
        "rpc_latency_avg_ms": {"dir":"down_good", "weight":0.6},
        "disk_free_mb":       {"dir":"up_good",   "weight":0.5},
        "modules_count":      {"dir":"stable",    "weight":0.0},  # informational
        "chain_broken":       {"dir":"down_good", "weight":2.0},  # максимальна вага
        "signatures_invalid": {"dir":"down_good", "weight":2.0},
        "executions_corrupted":{"dir":"down_good","weight":2.0},
        "deployed_contracts":  {"dir":"up_good",   "weight":0.4},
        "deployed_on_mainnet":{"dir":"up_good",   "weight":0.2},
    }
}

def cfg():
    if not CFG.exists():
        CFG.parent.mkdir(parents=True, exist_ok=True)
        CFG.write_text(json.dumps(DEFAULT_CFG, indent=2))
        return DEFAULT_CFG
    try:
        c = json.loads(CFG.read_text())
        base = dict(DEFAULT_CFG); base.update(c)
        if "metrics" not in c: base["metrics"] = DEFAULT_CFG["metrics"]
        else:
            mm = dict(DEFAULT_CFG["metrics"]); mm.update(c["metrics"])
            base["metrics"] = mm
        return base
    except Exception:
        return DEFAULT_CFG

def load_baseline():
    if not BASE.exists(): return {"metrics": {}, "count": 0}
    try: return json.loads(BASE.read_text())
    except Exception: return {"metrics": {}, "count": 0}

def save_baseline(b):
    BASE.parent.mkdir(parents=True, exist_ok=True)
    tmp = str(BASE)+".tmp"
    Path(tmp).write_text(json.dumps(b, indent=2))
    os.replace(tmp, BASE)

def save_log(entry):
    LOG.parent.mkdir(parents=True, exist_ok=True)
    entry["ts"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    entry["ts_unix"] = int(time.time())
    with open(LOG, "a") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    try:
        if LOG.stat().st_size > 1_000_000:
            lines = LOG.read_text().splitlines()
            LOG.write_text("\n".join(lines[-1000:]) + "\n")
    except Exception: pass

def update_baseline(current, history):
    """Rolling average за останні N циклів."""
    c = cfg(); win = c["baseline_window"]
    b = load_baseline()
    metrics_cfg = c["metrics"]
    samples = history[-win:] + [current]

    out = {}
    for key, mc in metrics_cfg.items():
        vals = [s.get(key) for s in samples if s.get(key) is not None]
        if not vals: continue
        if isinstance(vals[0], bool):
            out[key] = sum(1 for v in vals if v) / len(vals) >= 0.5
        else:
            out[key] = round(sum(vals) / len(vals), 3)
    b["metrics"] = out
    b["count"] = b.get("count", 0) + 1
    b["updated"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    save_baseline(b)
    return b

def _dev_pct(current, base):
    """Відхилення у відсотках. Обробка edge cases."""
    if base == 0:
        return 0 if current == 0 else 100
    return (current - base) / abs(base) * 100

def detect(current, baseline):
    """Повертає список відхилень."""
    c = cfg()
    metrics_cfg = c["metrics"]
    base_m = baseline.get("metrics", {})
    out = []
    for key, mc in metrics_cfg.items():
        if key not in current or current[key] is None: continue
        if key not in base_m or base_m[key] is None: continue
        cur = current[key]; b = base_m[key]
        # для bool — просто порівнюємо
        if isinstance(cur, bool) or isinstance(b, bool):
            if cur != b:
                out.append({"metric": key, "current": cur, "baseline": b,
                            "deviation_pct": 100.0, "dir": mc["dir"],
                            "severity": "warn", "weight": mc["weight"]})
            continue
        try:
            cur_f = float(cur); b_f = float(b)
        except Exception: continue
        # Ігноруємо дрібні абсолютні зміни (< min_delta) — це шум
        min_delta = c.get("min_abs_delta", {}).get(key, 0)
        if min_delta and abs(cur_f - b_f) < min_delta:
            continue
        dev = _dev_pct(cur_f, b_f)
        # визначаємо чи це погане відхилення
        is_bad = (
            (mc["dir"] == "up_good" and dev < -c["threshold_pct"]) or
            (mc["dir"] == "down_good" and dev > c["threshold_pct"])
        )
        if is_bad:
            sev = "critical" if abs(dev) > c["critical_pct"] else "warn"
            out.append({
                "metric": key, "current": cur, "baseline": b,
                "deviation_pct": round(dev, 2), "dir": mc["dir"],
                "severity": sev, "weight": mc["weight"]
            })
    return out

# ═══════════════════════════════════════════════════════════════
# ACTIONS при відхиленні
# ═══════════════════════════════════════════════════════════════
_last_action_at = {}

def _cooldown_ok(action_id):
    c = cfg()
    cd = c.get("cooldown_sec", 300)
    now = time.time()
    if now - _last_action_at.get(action_id, 0) < cd:
        return False
    return True

def _mark_action(action_id):
    _last_action_at[action_id] = time.time()
    # зберігаємо між запусками
    p = D / "data" / "evolve" / "action_time.json"
    try:
        d = json.loads(p.read_text()) if p.exists() else {}
    except Exception: d = {}
    d[action_id] = int(time.time())
    p.write_text(json.dumps(d))

def _load_action_times():
    p = D / "data" / "evolve" / "action_time.json"
    if not p.exists(): return
    try:
        for k, v in json.loads(p.read_text()).items():
            _last_action_at[k] = v
    except Exception: pass

def act(deviation):
    """Виконує дію за відхиленням. Повертає (action_id, ok, msg)."""
    _load_action_times()
    metric = deviation["metric"]
    sev = deviation["severity"]
    dev = deviation["deviation_pct"]

    # мапа: metric → [дії за пріоритетом]
    ACTIONS = {
        "tests_success_rate": [
            ("rerun_tests",      "перезапустити тести"),
            ("auto_fix_safe",    "авто-фікс safe-проблем через 121"),
            ("restore_tui",      "відкотити TUI з бекапу"),
        ],
        "stream_error_rate": [
            ("analyze_stream",   "аналіз останніх помилок у stream"),
            ("restart_watchdog", "перезапуск watchdog"),
            ("restart_orch",     "перезапуск orchestrator"),
        ],
        "actions_fail_rate": [
            ("retry_failed",     "повторний виклик failed actions"),
            ("auto_fix_safe",    "авто-фікс safe-проблем"),
        ],
        "rpc_latency_avg_ms": [
            ("bench_rpc",        "бенчмарк RPC endpoints"),
            ("switch_rpc",       "переключити на швидший endpoint"),
        ],
        "disk_free_mb": [
            ("cleanup_old",      "очищення старих логів/бекапів"),
            ("cleanup_backups",  "видалити бекапи > 20"),
        ],
        "modules_count": [
            ("install_missing",  "авто-інсталяція модулів з каталогу"),
        ],
        "chain_broken": [
            ("verify_chain",     "перевірити hash-chain"),
            ("alert_critical",   "критичний алерт"),
        ],
        "signatures_invalid": [
            ("quarantine_sigs",  "ізолювати невалідні підписи"),
            ("alert_critical",   "критичний алерт"),
        ],
        "executions_corrupted": [
            ("restore_exec",     "відновити з бекапу"),
            ("alert_critical",   "критичний алерт"),
        ],
    }

    actions = ACTIONS.get(metric, [])
    if not actions:
        return ("none", False, f"немає дій для {metric}")

    # для critical — беремо найсильнішу дію (останню)
    # для warn — першу
    choice = actions[-1] if sev == "critical" else actions[0]
    action_id, desc = choice

    # cooldown
    if not _cooldown_ok(action_id):
        return (action_id, False, f"cooldown {action_id}")

    # виконуємо
    fn = ACTIONS_FN.get(action_id)
    if not fn:
        return (action_id, False, f"немає реалізації {action_id}")
    try:
        ok, msg = fn(deviation)
        _mark_action(action_id)
        return (action_id, ok, msg)
    except Exception as e:
        return (action_id, False, f"exception: {e}")

# ─── реалізації дій ──────────────────────────────────────────
def _rerun_tests(d):
    rc = subprocess.run(["bash", str(M/"module_130_test_suite/run_tests.sh")],
                        capture_output=True, timeout=300)
    return rc.returncode == 0, f"exit={rc.returncode}"

def _auto_fix_safe(d):
    try:
        import executor
        items = __import__("todo").plan()
        done, failed = executor.auto_execute(items, verbose=False)
        return True, f"fixed={len(done)} fail={len(failed)}"
    except Exception as e:
        return False, str(e)[:100]

def _restore_tui(d):
    try:
        import actions
        ok, msg = actions.execute("restore_tui", "", source="evolve")
        return ok, msg
    except Exception as e:
        return False, str(e)[:100]

def _analyze_stream(d):
    try:
        sys.path.insert(0, str(D))
        import stream
        evs = stream.read(200, level="error") + stream.read(200, level="critical")
        if not evs:
            evs = stream.read(100, level="warn")
        # топ-3 категорії
        from collections import Counter
        c = Counter(e["cat"] for e in evs)
        top = c.most_common(3)
        return True, f"top errors: {top}"
    except Exception as e:
        return False, str(e)[:100]

def _restart_watchdog(d):
    try:
        subprocess.run(["bash", str(D/"watchdog.sh"), "stop"], timeout=10)
        subprocess.run(["bash", str(D/"watchdog.sh"), "start"], timeout=10)
        return True, "restarted"
    except Exception as e:
        return False, str(e)[:100]

def _restart_orch(d):
    try:
        subprocess.run(["bash", str(D/"orch.sh"), "stop"], timeout=10)
        subprocess.run(["bash", str(D/"orch.sh"), "start"], timeout=10)
        return True, "restarted"
    except Exception as e:
        return False, str(e)[:100]

def _retry_failed(d):
    try:
        sys.path.insert(0, str(D))
        import actions
        entries = actions.recent(100)
        failed = [e for e in entries if not e.get("ok")]
        retried = 0
        for e in failed[-3:]:
            aid = e.get("action"); tgt = e.get("target","")
            if not aid: continue
            ok, _ = actions.execute(aid, tgt, source="evolve-retry")
            if ok: retried += 1
        return True, f"retried={retried}/{len(failed[-3:])}"
    except Exception as e:
        return False, str(e)[:100]

def _bench_rpc(d):
    try:
        rc = subprocess.run(["python3", str(M/"module_115_rpc_bench/main.sh")],
                            capture_output=True, timeout=120, shell=False)
        return rc.returncode == 0, "bench done"
    except Exception as e:
        return False, str(e)[:100]

def _switch_rpc(d):
    """Переключає на перший альтернативний endpoint."""
    try:
        cfg_n = H / "config" / "networks.json"
        d_net = json.loads(cfg_n.read_text())
        cur = d_net["current"]
        rpcs = d_net["networks"][cur]["rpc_http"]
        if len(rpcs) < 2: return True, "немає альтернатив"
        # ротуємо
        d_net["networks"][cur]["rpc_http"] = rpcs[1:] + [rpcs[0]]
        cfg_n.write_text(json.dumps(d_net, indent=2, ensure_ascii=False))
        return True, f"switch → {d_net['networks'][cur]['rpc_http'][0]}"
    except Exception as e:
        return False, str(e)[:100]

def _cleanup_old(d):
    try:
        import actions
        ok, msg = actions.execute("cleanup_logs", "", source="evolve")
        return ok, msg
    except Exception as e:
        return False, str(e)[:100]

def _cleanup_backups(d):
    try:
        bdir = H / "backups"
        if not bdir.exists(): return True, "no backups"
        runs = sorted(bdir.glob("run_*"), key=lambda p: p.stat().st_mtime, reverse=True)
        removed = 0
        for old in runs[20:]:
            shutil.rmtree(old, ignore_errors=True); removed += 1
        return True, f"removed={removed}"
    except Exception as e:
        return False, str(e)[:100]

def _install_missing(d):
    try:
        sys.path.insert(0, str(D))
        import orchestrator
        o = orchestrator.Orchestrator(verbose=False)
        r = o.install_missing()
        return True, f"installed={r.get('installed',0)}"
    except Exception as e:
        return False, str(e)[:100]

def _verify_chain(d):
    try:
        import parliament as P
        rep = P.verify_chain()
        broken = sum(r["broken"] for r in rep.values())
        return broken == 0, f"broken={broken}"
    except Exception as e:
        return False, str(e)[:100]

def _alert_critical(d):
    try:
        import alerts
        alerts.send("chain_broken", f"EVOLVE CRITICAL: {d['metric']}",
                    f"current={d['current']} baseline={d['baseline']} dev={d['deviation_pct']}%")
        return True, "alerted"
    except Exception as e:
        return False, str(e)[:100]

def _quarantine_sigs(d):
    """Переміщує невалідні .sig у quarantine."""
    try:
        from eth_account import Account
        from eth_account.messages import encode_defunct
        ev = M / "module_19_contract_tui_menu/evidence"
        quar = ev / "_quarantine"
        quar.mkdir(exist_ok=True)
        moved = 0
        for s in sorted(ev.glob("*.sig"), key=lambda p: p.stat().st_mtime, reverse=True)[:10]:
            try:
                d_ = json.loads(s.read_text())
                rec = Account.recover_message(
                    encode_defunct(text=d_["message"]), signature=d_["signature"])
                if rec.lower() != d_["address"].lower():
                    s.rename(quar / s.name); moved += 1
            except Exception:
                s.rename(quar / s.name); moved += 1
        return True, f"quarantined={moved}"
    except Exception as e:
        return False, str(e)[:100]

def _restore_exec(d):
    try:
        # бекап executions з останнього backups/run_*
        bdir = H / "backups"
        runs = sorted(bdir.glob("run_*"), key=lambda p: p.stat().st_mtime, reverse=True)
        if not runs: return False, "немає бекапів"
        exec_dir = D / "data" / "executions"
        restored = 0
        for f in runs[0].glob("*_dossier.json"):
            try:
                json.loads(f.read_text())
            except Exception:
                shutil.copy2(f, exec_dir / f.name); restored += 1
        return True, f"restored={restored}"
    except Exception as e:
        return False, str(e)[:100]

ACTIONS_FN = {
    "rerun_tests": _rerun_tests, "auto_fix_safe": _auto_fix_safe,
    "restore_tui": _restore_tui, "analyze_stream": _analyze_stream,
    "restart_watchdog": _restart_watchdog, "restart_orch": _restart_orch,
    "retry_failed": _retry_failed, "bench_rpc": _bench_rpc, "switch_rpc": _switch_rpc,
    "cleanup_old": _cleanup_old, "cleanup_backups": _cleanup_backups,
    "install_missing": _install_missing, "verify_chain": _verify_chain,
    "alert_critical": _alert_critical, "quarantine_sigs": _quarantine_sigs,
    "restore_exec": _restore_exec,
}

# ═══════════════════════════════════════════════════════════════
# ГОЛОВНИЙ ЦИКЛ
# ═══════════════════════════════════════════════════════════════
def cycle(dry_run=False, verbose=True):
    G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[36m'; DIM='\033[2m'; N='\033[0m'
    if verbose:
        print(f"\n{B}═══ EVOLVE CYCLE ═══{N}")

    # 1. метрики
    import metrics
    m = metrics.collect()
    metrics.save(m)
    if verbose:
        print(f"  {DIM}метрики зібрано{N}")

    # 2. baseline
    hist = metrics.history(50)
    baseline = load_baseline()
    if not baseline.get("metrics"):
        # перший запуск — одразу ставимо baseline
        b = update_baseline(m, hist[:-1])
        if verbose:
            print(f"  {G}baseline створено{N} (перший запуск)")
        save_log({"kind":"baseline_init", "baseline": b["metrics"]})
        return {"ok": True, "phase": "baseline_init"}

    # 3. detect
    devs = detect(m, baseline)
    if verbose:
        if devs:
            print(f"  {Y}виявлено відхилень: {len(devs)}{N}")
            for d in devs:
                col = R if d["severity"]=="critical" else Y
                arrow = "↑" if d["deviation_pct"] > 0 else "↓"
                print(f"    {col}[{d['severity']:8s}]{N} {d['metric']:24s} "
                      f"{d['baseline']} → {d['current']}  {arrow}{abs(d['deviation_pct']):.1f}%")
        else:
            print(f"  {G}відхилень немає{N}")

    # 4. дії
    actions_taken = []
    if devs and not dry_run:
        c = cfg()
        if c.get("auto_act", True):
            for d in devs:
                aid, ok, msg = act(d)
                mark = f"{G}✓{N}" if ok else f"{R}✗{N}"
                if verbose:
                    print(f"    {mark} {aid}: {msg}")
                actions_taken.append({"metric":d["metric"], "action":aid,
                                     "ok":ok, "msg":msg})
                save_log({"kind":"action", "deviation":d,
                         "action":aid, "ok":ok, "msg":msg})

    # 5. оновити baseline
    b = update_baseline(m, hist)
    if verbose:
        print(f"  {DIM}baseline оновлено (#{b['count']}){N}")

    save_log({"kind":"cycle", "metrics":m, "deviations":devs,
             "actions":actions_taken, "baseline": b["metrics"]})
    # git-tracked metrics
    try:
        import metrics_git
        dev_n = len(devs)
        tag = f"cycle: {dev_n} devs, {len(actions_taken)} actions"
        metrics_git.commit_snapshot(m, tag=tag)
    except Exception: pass

    # self-heal engine — реагує на devs
    if devs:
        try:
            import importlib.util
            spec = importlib.util.spec_from_file_location(
                "engine", str(D.parent/"module_330_selfheal/engine.py"))
            eng = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(eng)
            r = eng.cycle(verbose=False)
            if verbose and r.get("healed", 0):
                print(f"  {G}✓{N} selfheal: {r['healed']} вилікувано")
        except Exception: pass

    # completion engine — доводить все до 100%
    try:
        import completion
        c_res = completion.run(verbose=False)
        if c_res["after"] > c_res["before"]:
            # є покращення → sync commit
            try:
                import sync
                sync.commit(f"completion: {c_res['before']}% → {c_res['after']}%")
                if sync.cfg().get("auto_push"):
                    sync.push()
            except Exception: pass
    except Exception: pass

    return {"ok": True, "deviations": len(devs), "actions": len(actions_taken),
            "baseline_count": b["count"]}

def show_status():
    G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[36m'; DIM='\033[2m'; N='\033[0m'
    b = load_baseline()
    if not b.get("metrics"):
        print(f"\n  {Y}baseline ще не створено{N}\n"); return
    print(f"\n  {B}Baseline{N}  {DIM}({b['count']} циклів, {b.get('updated')}){N}\n")
    for k, v in sorted(b["metrics"].items()):
        print(f"    {k:28s} {v}")
    print()

    # тренд останніх 10
    import metrics
    h = metrics.history(10)
    if len(h) >= 2:
        print(f"  {B}Тренд{N}\n")
        cfg_m = cfg()["metrics"]
        for key in cfg_m:
            vals = [x.get(key) for x in h if x.get(key) is not None]
            if len(vals) < 2: continue
            first, last = vals[0], vals[-1]
            if isinstance(first, (int,float)) and isinstance(last, (int,float)):
                try:
                    dev = (last-first)/abs(first)*100 if first else 0
                    col = G if (
                        (cfg_m[key]["dir"]=="up_good" and dev>=0) or
                        (cfg_m[key]["dir"]=="down_good" and dev<=0)
                    ) else R
                    arrow = "↑" if dev > 0 else "↓" if dev < 0 else "→"
                    print(f"    {key:28s} {first:>10} → {last:>10}  {col}{arrow}{abs(dev):.1f}%{N}")
                except Exception: pass
    print()

def show_log(n=20):
    if not LOG.exists():
        print("  (порожньо)"); return
    B='\033[36m'; G='\033[32m'; R='\033[31m'; Y='\033[33m'; D_='\033[2m'; N='\033[0m'
    lines = LOG.read_text().splitlines()[-n:]
    print(f"\n  {B}Evolve log (останні {len(lines)}){N}\n")
    for line in lines:
        try: e = json.loads(line)
        except Exception: continue
        k = e.get("kind")
        ts = e.get("ts","?")[:19]
        if k == "cycle":
            nd = len(e.get("deviations", []))
            na = len(e.get("actions", []))
            col = R if nd else G
            print(f"  {D_}{ts}{N}  cycle: {col}{nd} devs{N}, {na} actions")
        elif k == "action":
            mark = f"{G}✓{N}" if e.get("ok") else f"{R}✗{N}"
            print(f"  {D_}{ts}{N}  {mark} {e.get('action'):20s} ← {e['deviation']['metric']}")
        elif k == "baseline_init":
            print(f"  {D_}{ts}{N}  baseline init")
    print()

# ═══════════════════════════════════════════════════════════════
# CLI
# ═══════════════════════════════════════════════════════════════
if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "run"
    if cmd == "run":
        dry = "--dry" in sys.argv
        r = cycle(dry_run=dry)
        print(f"  result: {json.dumps(r, ensure_ascii=False)}")
    elif cmd == "dry":
        cycle(dry_run=True)
    elif cmd == "status":
        show_status()
    elif cmd == "log":
        n = int(sys.argv[2]) if len(sys.argv) > 2 else 20
        show_log(n)
    elif cmd == "reset-baseline":
        if BASE.exists(): BASE.unlink()
        print("  ✓ baseline скинуто")
    elif cmd == "cfg":
        print(json.dumps(cfg(), indent=2, ensure_ascii=False))
    elif cmd == "daemon":
        interval = int(sys.argv[2]) if len(sys.argv) > 2 else 900
        print(f"  evolve daemon: interval={interval}s")
        while True:
            try: cycle(verbose=False)
            except Exception as e: print(f"  err: {e}")
            time.sleep(interval)
