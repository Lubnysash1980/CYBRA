#!/usr/bin/env python3
"""Повний self-audit цикл: stream → deep audit → gap → roadmap → stream.
Викликається з watchdog або cron."""
import sys, os, time, json, subprocess
from pathlib import Path

D = Path(__file__).resolve().parent
sys.path.insert(0, str(D))
import stream, deep_audit, gap, roadmap

def full_cycle(verbose=False):
    t0 = time.time()
    stream.system("audit_cycle_start")

    # 1. Deep audit
    issues = deep_audit.run()
    crit = [i for i in issues if i["level"]=="critical"]
    warn = [i for i in issues if i["level"]=="warn"]
    for i in issues:
        stream.audit("deep_audit", {"kind": i["kind"], "detail": i["detail"],
                                    "level": i["level"]})

    # 2. Gap аналіз
    try:
        a = gap.analyze()
        stream.audit("gap_analysis", {
            "gaps": len(a["gaps"]),
            "ready": a["ready_count"],
            "existing_modules": a["existing_modules"],
        })
    except Exception as e:
        a = None
        stream.system("gap_fail", {"err": str(e)}, level="warn")

    # 3. Roadmap
    try:
        cfg = roadmap.refresh()
        stream.audit("roadmap_refresh", {"items": len(cfg["items"])})
    except Exception as e:
        stream.system("roadmap_fail", {"err": str(e)}, level="warn")

    dur = int((time.time()-t0)*1000)
    stream.system("audit_cycle_end", {"dur_ms": dur,
                                      "crit": len(crit), "warn": len(warn)})

    if verbose:
        G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[36m'; N='\033[0m'
        print(f"\n  {B}═══ Self-Audit Cycle ({dur}ms) ═══{N}")
        print(f"  🚨 {len(crit)}  🟡 {len(warn)}  (spec gaps)")
        if a:
            print(f"  Roadmap: {len(a['gaps'])} прогалин, "
                  f"{a['ready_count']} {G}готові{N}")
            print(f"  Далі → config/roadmap.json + docs/ROADMAP.md")

    return {"crit": len(crit), "warn": len(warn),
            "gaps": len(a["gaps"]) if a else 0,
            "ready": a["ready_count"] if a else 0,
            "dur_ms": dur}

if __name__ == "__main__":
    v = "-v" in sys.argv or "--verbose" in sys.argv
    r = full_cycle(verbose=v)
    if not v:
        print(json.dumps(r, ensure_ascii=False))
