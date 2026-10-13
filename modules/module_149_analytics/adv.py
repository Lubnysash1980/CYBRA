#!/usr/bin/env python3
"""Розширена аналітика: sparkline, порівняння, експорт."""
import json, os, sys, time, csv
from pathlib import Path
from collections import Counter, defaultdict

H = Path.home() / "CYBRA"
D = Path(__file__).resolve().parent

SPARK = "▁▂▃▄▅▆▇█"

def sparkline(values, width=50):
    if not values: return ""
    mn, mx = min(values), max(values)
    rng = mx - mn if mx > mn else 1
    out = []
    for v in values[-width:]:
        idx = int((v - mn) / rng * (len(SPARK) - 1))
        out.append(SPARK[idx])
    return "".join(out)

def load_metrics(days=30):
    sys.path.insert(0, str(H/"modules/module_121_parlament"))
    try:
        import metrics
        return metrics.history(500)
    except Exception: return []

def contracts_per_day(days=30):
    ev = H/"modules/module_19_contract_tui_menu/evidence"
    if not ev.exists(): return {}
    cutoff = time.time() - days*86400
    by_day = Counter()
    for f in ev.glob("*.sig"):
        if f.stat().st_mtime < cutoff: continue
        day = time.strftime("%Y-%m-%d", time.localtime(f.stat().st_mtime))
        by_day[day] += 1
    return dict(sorted(by_day.items()))

def parliament_activity(days=30):
    try:
        sys.path.insert(0, str(H/"modules/module_121_parlament"))
        import parliament as P
        props = P.proposals()
    except Exception: return {}
    cutoff = time.time() - days*86400
    by_day = Counter()
    for p in props:
        try:
            t = time.mktime(time.strptime(p.get("created",""), "%Y-%m-%dT%H:%M:%SZ"))
            if t < cutoff: continue
            day = time.strftime("%Y-%m-%d", time.localtime(t))
            by_day[day] += 1
        except Exception: pass
    return dict(sorted(by_day.items()))

def export_csv(out_path):
    """Експорт усіх метрик у CSV."""
    m = load_metrics()
    if not m: return False, "немає даних"
    keys = set()
    for x in m: keys.update(x.keys())
    keys.discard("_dossier_hash")
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(sorted(keys))
        for x in m:
            w.writerow([x.get(k, "") for k in sorted(keys)])
    return True, out_path

def print_dashboard():
    G='\033[32m'; Y='\033[33m'; B='\033[36m'; D_='\033[2m'; N='\033[0m'

    print(f"\n{B}═══════════════════════════════════════════════════════{N}")
    print(f"{B}  ADVANCED ANALYTICS{N}")
    print(f"{B}═══════════════════════════════════════════════════════{N}")

    # 1. Contracts per day
    print(f"\n  {B}▸ Контракти (30 днів){N}")
    cpd = contracts_per_day()
    if cpd:
        vals = list(cpd.values())
        print(f"    {G}{sparkline(vals)}{N}  total={sum(vals)}")
        for day, n in list(cpd.items())[-7:]:
            print(f"    {day}  {G}{'█'*n}{N} {n}")
    else:
        print(f"    {D_}немає даних{N}")

    # 2. Parliament activity
    print(f"\n  {B}▸ Парламент (30 днів){N}")
    pa = parliament_activity()
    if pa:
        vals = list(pa.values())
        print(f"    {G}{sparkline(vals)}{N}  total={sum(vals)}")
    else:
        print(f"    {D_}немає{N}")

    # 3. Metrics trend
    m = load_metrics()
    if m:
        print(f"\n  {B}▸ Ключові метрики{N}")
        for key in ["tests_success_rate", "stream_error_rate", "actions_fail_rate",
                    "rpc_latency_avg_ms", "disk_free_mb", "modules_count",
                    "deployed_contracts"]:
            vals = [x.get(key) for x in m if x.get(key) is not None]
            if not vals: continue
            nums = [float(v) for v in vals if isinstance(v, (int,float))]
            if not nums: continue
            spark = sparkline(nums)
            print(f"    {key:24s} {G}{spark}{N}  now={nums[-1]:.1f}")
    print()

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "show"
    if cmd == "show": print_dashboard()
    elif cmd == "export":
        p = sys.argv[2] if len(sys.argv) > 2 else str(D/"data" / f"metrics_{int(time.time())}.csv")
        ok, m = export_csv(p); print(("✓ " if ok else "✗ ") + str(m))
