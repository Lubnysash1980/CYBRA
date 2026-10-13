#!/usr/bin/env python3
"""AI Guardian — єдина система перевірки та автолікування CYBRA."""
import sys, json, os, subprocess, time, argparse, importlib.util
from pathlib import Path

D = Path(__file__).resolve().parent
sys.path.insert(0, str(D))
import journal

# кольори
G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[36m'; DIM='\033[2m'; N='\033[0m'
ICON = {"ok":"🟢","warn":"🟡","fail":"🔴","critical":"🚨"}

def load_module(path):
    spec = importlib.util.spec_from_file_location(path.stem, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m

def run_checks():
    results = []
    check_dir = D / "checks"
    for py in sorted(check_dir.glob("check_*.py")):
        try:
            mod = load_module(py)
            r = mod.run()
            results.extend(r)
        except Exception as e:
            results.append({
                "id": f"check.{py.stem}", "name": py.stem,
                "status": "warn", "detail": f"помилка чекера: {e}",
                "fix_hint": ""
            })
    return results

def summarize(results):
    counts = {"ok":0,"warn":0,"fail":0,"critical":0}
    for r in results:
        counts[r["status"]] = counts.get(r["status"], 0) + 1
    return counts

def print_results(results, verbose=False):
    counts = summarize(results)
    print(f"\n  {B}═══ Результат ═══{N}")
    print(f"  🟢 {counts['ok']}  🟡 {counts['warn']}  🔴 {counts['fail']}  🚨 {counts['critical']}\n")

    for r in results:
        if r["status"] == "ok" and not verbose: continue
        ic = ICON.get(r["status"], "?")
        print(f"  {ic} {r['name']:34s} {DIM}{r['detail']}{N}")
        if verbose and r.get("fix_hint"):
            print(f"     {DIM}→ {r['fix_hint']}{N}")
    return counts

def save_report(results, counts, mode):
    ts = time.strftime("%Y%m%d_%H%M%S")
    p = D / "backups" / f"report_{ts}.json"
    p.write_text(json.dumps({
        "ts": ts, "mode": mode, "counts": counts, "results": results
    }, indent=2, ensure_ascii=False))
    # ротація — 30 звітів
    reps = sorted((D/"backups").glob("report_*.json"),
                  key=lambda x: x.stat().st_mtime, reverse=True)
    for old in reps[30:]:
        old.unlink()
    return p

def execute_action(action_id, target, force=False, auto=False):
    spec = importlib.util.spec_from_file_location("actions", D/"heal/actions.py")
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    a = m.ACTIONS.get(action_id)
    if not a:
        return False, f"невідома дія: {action_id}"
    level = a["level"]
    if level == "danger" and not force:
        return False, f"{action_id}: потрібен --force (рівень danger)"
    if level == "warn" and auto and not force:
        return False, f"{action_id}: warn не запускається в auto-режимі без --force"
    try:
        return a["fn"](target)
    except Exception as e:
        return False, f"exception: {e}"

def heal_loop(results, force=False, auto=False, learn=True):
    """Проходить по fail/warn, шукає відповідну дію і виконує."""
    fixed, unfixed = [], []
    for r in results:
        if r["status"] in ("ok",): continue
        s = journal.suggest(r["id"], r.get("detail",""))
        if not s: continue

        act = s["action"]
        tgt = s.get("target") or r.get("fix_hint","")
        # спец-випадок: chmod ключів — витягуємо шлях з detail
        if act == "chmod_key_600":
            for tok in r.get("detail","").split():
                if tok.startswith("/") and "keys" in tok:
                    tgt = tok
        print(f"\n  {Y}→{N} {r['name']} — {act} (conf {s.get('confidence','?')})")
        if tgt: print(f"    {DIM}target: {tgt}{N}")

        ok, msg = execute_action(act, tgt, force=force, auto=auto)
        journal.record({
            "kind":"heal", "check_id":r["id"], "action":act,
            "target":tgt, "success":ok, "msg":msg
        })
        if learn:
            journal.learn(r["id"], act, ok)
        if ok:
            print(f"    {G}✓{N} {msg}")
            fixed.append({"check":r["id"], "action":act, "msg":msg})
        else:
            print(f"    {R}✗{N} {msg}")
            unfixed.append({"check":r["id"], "action":act, "msg":msg})
    return fixed, unfixed

# ─── CLI ────────────────────────────────────────────────────
def cmd_run(a):
    print(f"\n{B}══════════════════════════════════════════════════════════{N}")
    print(f"{B}  AI Guardian · перевірка CYBRA{N}")
    print(f"{B}══════════════════════════════════════════════════════════{N}")

    results = run_checks()
    counts = summarize(results)
    print_results(results, verbose=a.verbose)
    save_report(results, counts, "check")

    # запис у журнал
    for r in results:
        if r["status"] in ("fail","critical"):
            journal.record({"kind":"check_fail","check_id":r["id"],
                            "status":r["status"],"detail":r["detail"]})

    if a.auto:
        print(f"\n{B}═══ AutoHeal ═══{N}")
        fixed, unfixed = heal_loop(results, force=a.force, auto=True)
        print(f"\n  {G}Виправлено: {len(fixed)}{N}  {R}Не вдалось: {len(unfixed)}{N}")
        # повторна перевірка після лікування
        if fixed:
            print(f"\n{B}═══ Повторна перевірка ═══{N}")
            r2 = run_checks()
            c2 = summarize(r2)
            print_results(r2)
            save_report(r2, c2, "recheck")
    elif a.heal:
        print(f"\n{B}═══ Heal (за підтвердженням) ═══{N}")
        fixed, unfixed = heal_loop(results, force=False, auto=False)
        print(f"\n  {G}Виправлено: {len(fixed)}{N}  {R}Не вдалось: {len(unfixed)}{N}")

    print()
    return 0 if counts["fail"] + counts["critical"] == 0 else 2

def cmd_history(a):
    if not journal.J.exists():
        print("  (журнал порожній)"); return
    lines = journal.J.read_text().splitlines()
    for line in lines[-a.n:]:
        try: e = json.loads(line)
        except Exception: continue
        t = e.get("ts","?"); k = e.get("kind","?")
        if k == "check_fail":
            print(f"  {t}  FAIL  {e.get('check_id')}  {e.get('detail','')[:50]}")
        elif k == "heal":
            mark = "✓" if e.get("success") else "✗"
            print(f"  {t}  {mark} HEAL  {e.get('action')}  {e.get('msg','')[:50]}")

def cmd_summary(a):
    s = journal.pattern_summary()
    print(json.dumps(s, indent=2, ensure_ascii=False))

def cmd_suggest(a):
    s = journal.suggest(a.check_id, a.detail or "")
    print(json.dumps(s or {"info":"нема пропозиції"}, indent=2, ensure_ascii=False))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", nargs="?", default="run",
                    choices=["run","history","summary","suggest"])
    ap.add_argument("--auto", action="store_true", help="автоматично виправляти safe-проблеми")
    ap.add_argument("--heal", action="store_true", help="показати пропозиції та запитати")
    ap.add_argument("--force", action="store_true", help="дозволити warn/danger")
    ap.add_argument("--verbose", "-v", action="store_true")
    ap.add_argument("-n", type=int, default=20)
    ap.add_argument("--check-id", default="")
    ap.add_argument("--detail", default="")
    a = ap.parse_args()

    if a.cmd == "run":      sys.exit(cmd_run(a))
    if a.cmd == "history":  cmd_history(a); return
    if a.cmd == "summary":  cmd_summary(a); return
    if a.cmd == "suggest":  cmd_suggest(a); return

if __name__ == "__main__":
    main()
