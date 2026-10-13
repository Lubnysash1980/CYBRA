#!/usr/bin/env python3
"""Аналітика: тренди по підписах, парламенту, виконанню."""
import json, os, sys, time
from pathlib import Path
from collections import Counter, defaultdict
H = Path.home() / "CYBRA"

def _load_jsonl(p):
    if not Path(p).exists(): return []
    out = []
    for line in Path(p).read_text().splitlines():
        try: out.append(json.loads(line))
        except Exception: pass
    return out

def signatures_trend(days=30):
    """Скільки підписів за день."""
    ev = H / "modules/module_19_contract_tui_menu/evidence"
    if not ev.exists(): return {}
    by_day = Counter()
    cutoff = time.time() - days*86400
    for f in ev.glob("*.sig"):
        if f.stat().st_mtime < cutoff: continue
        day = time.strftime("%Y-%m-%d", time.localtime(f.stat().st_mtime))
        by_day[day] += 1
    return dict(sorted(by_day.items()))

def parliament_stats():
    try:
        sys.path.insert(0, str(H/"modules/module_121_parlament"))
        import parliament as P
        props = P.proposals()
        by_status = Counter(p.get("status") for p in props)
        # активність по членах
        activity = Counter()
        for v in _load_jsonl(H/"modules/module_121_parlament/data/votes.jsonl"):
            activity[v["voter"][:10]] += 1
        return {"total": len(props), "by_status": dict(by_status),
                "top_voters": activity.most_common(5)}
    except Exception as e:
        return {"error": str(e)}

def execution_stats():
    ex = H / "modules/module_121_parlament/data/executions"
    if not ex.exists(): return {}
    from collections import Counter
    progress_bins = Counter()
    total = 0
    for f in ex.glob("C-*.json"):
        try:
            d = json.loads(f.read_text())
            lvl_done = sum(1 for v in d.get("levels", {}).values() if v.get("ok"))
            progress_bins[lvl_done] += 1
            total += 1
        except Exception: pass
    return {"total_contracts": total, "by_level_done": dict(progress_bins)}

def actions_stats():
    log = H / "modules/module_121_parlament/data/exec_log.jsonl"
    entries = _load_jsonl(log)
    if not entries: return {}
    c = Counter(e.get("action") for e in entries)
    ok = sum(1 for e in entries if e.get("ok"))
    return {"total": len(entries), "ok": ok, "fail": len(entries)-ok,
            "top": c.most_common(10)}

def overview():
    return {
        "signatures": signatures_trend(),
        "parliament": parliament_stats(),
        "executions": execution_stats(),
        "actions": actions_stats(),
    }

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "overview"
    if cmd == "overview":
        print(json.dumps(overview(), indent=2, ensure_ascii=False))
    elif cmd == "text":
        G='\033[32m'; Y='\033[33m'; B='\033[36m'; D='\033[2m'; N='\033[0m'
        o = overview()
        print(f"\n{B}═══ CYBRA Analytics ═══{N}")

        sigs = o["signatures"]
        print(f"\n{B}▸ Підписи ({sum(sigs.values())} за 30 днів){N}")
        maxv = max(sigs.values()) if sigs else 1
        for day, n in list(sigs.items())[-14:]:
            bar = "█" * max(1, int(n/maxv*30))
            print(f"  {day}  {G}{bar}{N}  {n}")

        p = o["parliament"]
        print(f"\n{B}▸ Парламент{N}")
        if "total" in p:
            print(f"  Всього: {p['total']}")
            for st, n in (p.get("by_status") or {}).items():
                print(f"    {st:12s} {n}")
            if p.get("top_voters"):
                print(f"  Топ-голосувачі:")
                for addr, n in p["top_voters"]:
                    print(f"    {addr}… {n}")

        e = o["executions"]
        print(f"\n{B}▸ Виконання{N}")
        print(f"  Контрактів: {e.get('total_contracts',0)}")
        for lvl, n in sorted(e.get("by_level_done", {}).items()):
            print(f"    L{lvl}: {n}")

        a = o["actions"]
        if a:
            print(f"\n{B}▸ Дії парламенту{N}")
            print(f"  Всього: {a['total']}  {G}ok: {a['ok']}{N}  {Y}fail: {a['fail']}{N}")
