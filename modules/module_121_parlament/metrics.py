#!/usr/bin/env python3
"""Збір метрик CYBRA. Все що вимірюється — тут."""
import json, os, sys, time, subprocess
from pathlib import Path
from collections import Counter

D = Path(__file__).resolve().parent
H = Path.home() / "CYBRA"
M = H / "modules"
METRICS_LOG = D / "data" / "metrics.jsonl"

def _run(cmd, timeout=30):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout + r.stderr
    except Exception:
        return 1, ""

def _read_jsonl(p, tail=500):
    if not Path(p).exists(): return []
    lines = Path(p).read_text().splitlines()[-tail:]
    out = []
    for line in lines:
        try: out.append(json.loads(line))
        except Exception: pass
    return out

def collect():
    """Знімок метрик зараз."""
    m = {"ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
         "ts_unix": int(time.time())}

    # 1. Модулі
    m["modules_count"] = len(list(M.glob("module_*")))

    # 2. Тести (з останнього test suite)
    rc, out = _run("bash " + str(M/"module_130_test_suite/run_tests.sh"), timeout=180)
    import re
    mt = re.search(r'PASS:\s*(\d+)\s*FAIL:\s*(\d+)\s*SKIP:\s*(\d+)', out)
    if mt:
        p, f, s = int(mt.group(1)), int(mt.group(2)), int(mt.group(3))
        m["tests_pass"] = p
        m["tests_fail"] = f
        m["tests_skip"] = s
        m["tests_success_rate"] = round(p / max(1, p+f) * 100, 2)
    else:
        m["tests_success_rate"] = None

    # 3. Stream — error rate за останні 24 год
    stream_events = _read_jsonl(D.parent / "module_121_parlament/logs/stream.jsonl", 1000) \
        if (D.parent / "module_121_parlament/logs/stream.jsonl").exists() \
        else _read_jsonl(H / "logs" / "stream.jsonl", 1000)
    cutoff = time.time() - 86400
    recent = [e for e in stream_events if e.get("ts_unix", 0) > cutoff]
    errs = [e for e in recent if e.get("level") in ("warn","error","critical")]
    m["stream_events_24h"] = len(recent)
    m["stream_errors_24h"] = len(errs)
    m["stream_error_rate"] = round(len(errs) / max(1, len(recent)) * 100, 2)

    # 4. Exec log — failed actions
    exec_log = _read_jsonl(D / "data" / "exec_log.jsonl", 200)
    recent_exec = [e for e in exec_log if e.get("ts_unix", 0) > cutoff] if exec_log else []
    if not recent_exec:
        # fallback — по timestamp
        recent_exec = [e for e in exec_log
                       if e.get("ts","")[:10] == time.strftime("%Y-%m-%d", time.gmtime())]
    fails = [e for e in recent_exec if not e.get("ok")]
    m["actions_total"] = len(recent_exec)
    m["actions_failed"] = len(fails)
    m["actions_fail_rate"] = round(len(fails) / max(1, len(recent_exec)) * 100, 2)

    # 5. Hash-chain
    try:
        import parliament as P
        rep = P.verify_chain()
        m["chain_broken"] = sum(r["broken"] for r in rep.values())
        m["chain_total"] = sum(r["entries"] for r in rep.values())
    except Exception:
        m["chain_broken"] = -1

    # 6. RPC latency (з AutoNode)
    an = H / "run" / "autonode.json"
    if an.exists():
        try:
            d = json.loads(an.read_text())
            nets = d.get("networks", {})
            lats = [v.get("latency_ms") for v in nets.values() if v.get("latency_ms")]
            m["rpc_latency_avg_ms"] = round(sum(lats)/len(lats), 1) if lats else None
            m["rpc_online_count"] = sum(1 for v in nets.values() if v.get("state") == "ok")
            m["rpc_total_count"] = len(nets)
        except Exception: pass

    # 7. Диск
    import shutil
    try:
        total, used, free = shutil.disk_usage(str(H))
        m["disk_free_mb"] = free // (1024*1024)
    except Exception:
        m["disk_free_mb"] = None

    # 8. Крипто-цілісність
    try:
        import verify_7
        ex = D / "data" / "executions"
        if ex.exists():
            corrupted = 0; total_exec = 0
            for f in ex.glob("C-*.json"):
                total_exec += 1
                try: json.loads(f.read_text())
                except Exception: corrupted += 1
            m["executions_corrupted"] = corrupted
            m["executions_total"] = total_exec
    except Exception: pass

    # 9. Підписи
    ev = M / "module_19_contract_tui_menu/evidence"
    if ev.exists():
        sigs = list(ev.glob("*.sig"))
        m["signatures_total"] = len(sigs)
        # верифікація останніх 5
        try:
            from eth_account import Account
            from eth_account.messages import encode_defunct
            bad = 0
            for s in sorted(sigs, key=lambda p: p.stat().st_mtime, reverse=True)[:5]:
                try:
                    d = json.loads(s.read_text())
                    rec = Account.recover_message(
                        encode_defunct(text=d["message"]), signature=d["signature"])
                    if rec.lower() != d["address"].lower(): bad += 1
                except Exception: bad += 1
            m["signatures_invalid"] = bad
        except ImportError: pass

    # 9b. Deployed контракти
    try:
        dep = H / "config" / "deployed.json"
        if dep.exists():
            d = json.loads(dep.read_text())
            m["deployed_contracts"] = len(d)
            m["deployed_on_testnet"] = sum(1 for x in d.values()
                                          if "testnet" in (x.get("network") or ""))
            m["deployed_on_mainnet"] = sum(1 for x in d.values()
                                          if "testnet" not in (x.get("network") or ""))
    except Exception: pass

    # 10. Процеси
    for proc, key in [("autonode/daemon.py","autonode_running"),
                      ("parlament/watchdog","watchdog_running"),
                      ("orchestrator.py daemon","orch_running")]:
        rc, _ = _run(f"pgrep -f {proc}")
        m[key] = (rc == 0)

    return m

def save(m):
    METRICS_LOG.parent.mkdir(exist_ok=True)
    with open(METRICS_LOG, "a") as f:
        f.write(json.dumps(m, ensure_ascii=False) + "\n")
    # ротація
    try:
        if METRICS_LOG.stat().st_size > 2_000_000:
            lines = METRICS_LOG.read_text().splitlines()
            METRICS_LOG.write_text("\n".join(lines[-2000:]) + "\n")
    except Exception: pass

def history(n=50):
    return _read_jsonl(METRICS_LOG, n)

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "collect"
    if cmd == "collect":
        m = collect(); save(m)
        print(json.dumps(m, indent=2, ensure_ascii=False))
    elif cmd == "show":
        h = history(10)
        if not h: print("  (порожньо)"); sys.exit(0)
        B='\033[36m'; D_='\033[2m'; N='\033[0m'
        print(f"\n  {B}Останні {len(h)} метрик{N}\n")
        for m in h[-5:]:
            print(f"  {m['ts']}")
            for k in ["tests_success_rate","stream_error_rate","actions_fail_rate",
                     "rpc_latency_avg_ms","disk_free_mb","modules_count"]:
                if k in m: print(f"    {k:24s} {m[k]}")
            print()
