#!/usr/bin/env python3
"""Menu Tester — тест КОЖНОГО пункту меню.
Класифікація:
  ✓ OK      — працює
  ⚠ STUB    — заглушка (not implemented)
  ✗ FAIL    — зламано (немає файлу/функції)
  ⚙ INTER   — інтерактивний (потребує вводу, не тестується)
  🚫 MISS   — файл відсутній
"""
import hashlib, json, os, re, subprocess, sys, time
from pathlib import Path

H = Path.home() / "CYBRA"
M = H / "modules"
TUI = M / "module_19_contract_tui_menu/bin/cybra_menu.sh"
D = Path(__file__).resolve().parent
REPORT = D / "data" / "report.json"

def _run(cmd, timeout=10):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout + r.stderr)[:200]
    except Exception as e:
        return 1, str(e)[:100]

def parse_cases():
    """Парсить усі case."""
    if not TUI.exists(): return {}
    s = TUI.read_text()
    cases = {}
    for m in re.finditer(r'^[ \t]+(\d+)\)\s*([^;]*?)\s*;;[ \t]*$', s, re.M):
        mid = m.group(1)
        action = m.group(2).strip()
        if mid not in cases:
            cases[mid] = action
        else:
            cases[mid] = "DUP:" + action[:30]
    return cases

def get_fn_body(fname):
    if not TUI.exists(): return None
    s = TUI.read_text()
    pat = re.compile(rf'^{re.escape(fname)}\(\)\s*\{{', re.M)
    m = pat.search(s)
    if not m: return None
    start = m.end(); depth = 1; i = start
    while i < len(s) and depth > 0:
        if s[i] == '{': depth += 1
        elif s[i] == '}': depth -= 1
        i += 1
    return s[start:i-1]

def classify(mid, action):
    """Повертає (status, detail)."""
    if action.startswith("DUP:"):
        return "FAIL", "дублікат case"

    # action_*
    m = re.match(r'^(action_[a-z_0-9]+)', action)
    if m:
        fname = m.group(1)
        body = get_fn_body(fname)
        if body is None:
            return "FAIL", f"{fname} не визначена"
        if "not implemented" in body or "не реалізовано" in body or "TODO" in body:
            return "STUB", f"{fname}: заглушка"
        if len(body.strip()) < 30:
            return "STUB", f"{fname}: закоротка ({len(body.strip())} B)"
        return "OK", f"{fname}"

    # bash "$HOME/..." or "$H/..."
    m = re.search(r'(?:bash|sh)\s+"?([^\s"]+)"?', action)
    if m:
        f = m.group(1)
        f = f.replace("$HOME/", str(Path.home())+"/").replace("$H/", str(H)+"/")
        f = f.replace("${HOME}/", str(Path.home())+"/")
        p = Path(f)
        if not p.exists():
            return "MISS", f"немає: {p.name}"
        if not os.access(p, os.X_OK):
            return "FAIL", f"не executable: {p.name}"
        rc, out = _run(f"bash -n {p}")
        if rc != 0:
            return "FAIL", f"syntax: {out[:40]}"
        return "OK", p.name

    # cybra-pm / bin / etc
    m = re.search(r'cybra-pm\s+\S+', action)
    if m: return "OK", m.group(0)

    # read -r — інтерактив
    if "read" in action: return "INTER", "interactive"

    # Порожня
    if not action.strip(): return "FAIL", "порожня дія"

    return "WARN", action[:40]

def test_all():
    cases = parse_cases()
    results = {}
    counts = {"OK":0,"STUB":0,"FAIL":0,"MISS":0,"INTER":0,"WARN":0}
    for mid, action in sorted(cases.items(), key=lambda x: int(x[0])):
        if mid == "0": continue
        st, detail = classify(mid, action)
        results[mid] = {"status": st, "detail": detail, "action": action[:60]}
        counts[st] = counts.get(st, 0) + 1
    report = {
        "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "total": len(results), "counts": counts, "items": results,
    }
    REPORT.write_text(json.dumps(report, indent=2, ensure_ascii=False))
    return report

# ═══ 8-STAGE FIX ═══
STAGES = [
    ("1_fix_double_cybra", "Виправлення CYBRA/CYBRA"),
    ("2_fix_dup_cases",    "Прибирання дублікатів case"),
    ("3_fix_missing_files","Додавання заглушок для MISS"),
    ("4_fix_stubs",        "Заміна STUB на інформативні"),
    ("5_fix_syntax",       "Перевірка syntax усіх .sh"),
    ("6_sync_pub",         "Синхронізація PUB"),
    ("7_snapshot",         "Створення snapshot"),
    ("8_git_commit",       "Git commit"),
]

def fix_stage_1():
    """CYBRA/CYBRA → CYBRA."""
    s = TUI.read_text()
    n = 0
    for a, b in [("CYBRA/CYBRA", "CYBRA"), ("$HOME/CYBRA/CYBRA", "$HOME/CYBRA")]:
        c = s.count(a)
        if c: s = s.replace(a, b); n += c
    if n: TUI.write_text(s)
    return n, f"замін: {n}"

def fix_stage_2():
    """Прибрати дублікати case."""
    s = TUI.read_text()
    lines = s.split("\n")
    seen = {}
    out = []
    removed = 0
    for line in lines:
        m = re.match(r'^\s+(\d+)\)', line)
        if m:
            mid = m.group(1)
            if mid in seen:
                removed += 1
                continue
            seen[mid] = True
        out.append(line)
    if removed:
        TUI.write_text("\n".join(out))
    return removed, f"видалено дублікатів: {removed}"

def fix_stage_3():
    """Додати заглушки для MISS."""
    report = json.loads(REPORT.read_text()) if REPORT.exists() else test_all()
    miss = [m for m, v in report["items"].items() if v["status"] == "MISS"]
    if not miss: return 0, "немає MISS"
    s = TUI.read_text()
    # Замінити MISS case на заглушку
    for mid in miss:
        old = re.search(rf'^(\s+){mid}\)\s*[^;]*;;', s, re.M)
        if old:
            ind = old.group(1)
            new = f'{ind}{mid}) echo "⚠ [{mid}] не реалізовано"; read -rp "Enter…" _ ;;'
            s = s[:old.start()] + new + s[old.end():]
    TUI.write_text(s)
    return len(miss), f"замінено: {len(miss)}"

def fix_stage_4():
    """Замінити STUB на інформативні."""
    report = json.loads(REPORT.read_text()) if REPORT.exists() else test_all()
    stubs = [m for m, v in report["items"].items() if v["status"] == "STUB"]
    if not stubs: return 0, "немає STUB"
    s = TUI.read_text()
    fixed = 0
    for mid in stubs:
        info = report["items"][mid]
        m = re.match(r'^(action_[a-z_0-9]+)', info["action"])
        if not m: continue
        fname = m.group(1)
        pat = re.compile(rf'^{re.escape(fname)}\(\)\s*\{{.*?^\}}', re.M | re.DOTALL)
        new_body = (
            f'{fname}() {{\n'
            f'  echo "⚠ [{mid}] не реалізовано"\n'
            f'  echo "   Причина: {info["detail"][:50]}"\n'
            f'  echo "   Стан: cybra → 399"\n'
            f'  read -rp "Enter…" _\n'
            f'}}'
        )
        s2 = pat.sub(new_body, s, count=1)
        if s2 != s: s = s2; fixed += 1
    if fixed: TUI.write_text(s)
    return fixed, f"замінено: {fixed}"

def fix_stage_5():
    """Перевірка syntax."""
    rc, out = _run(f"bash -n {TUI}")
    if rc == 0: return 0, "syntax OK"
    return 1, f"FAIL: {out[:60]}"

def fix_stage_6():
    """Sync PUB."""
    PUB = H / "public/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
    if PUB.exists():
        PUB.write_text(TUI.read_text())
        return 0, "PUB синхронізовано"
    return 0, "PUB відсутній"

def fix_stage_7():
    """Snapshot."""
    rc, out = _run(f"python3 {M}/module_390_src/src.py snapshot", timeout=60)
    return (0 if rc == 0 else 1), "snapshot створено" if rc == 0 else "snapshot failed"

def fix_stage_8():
    """Git commit."""
    gm = H / "git_module"
    if not gm.exists(): return 0, "немає git_module"
    rc, _ = _run(f"cd {gm} && git add -A && git commit -m 'menu tester fix {int(time.time())}' --allow-empty", timeout=30)
    return (0 if rc == 0 else 1), "commit" if rc == 0 else "commit skipped"

STAGE_FNS = {
    "1_fix_double_cybra": fix_stage_1,
    "2_fix_dup_cases": fix_stage_2,
    "3_fix_missing_files": fix_stage_3,
    "4_fix_stubs": fix_stage_4,
    "5_fix_syntax": fix_stage_5,
    "6_sync_pub": fix_stage_6,
    "7_snapshot": fix_stage_7,
    "8_git_commit": fix_stage_8,
}

def run_all_stages():
    """8-stage fix."""
    results = []
    for sid, name in STAGES:
        fn = STAGE_FNS.get(sid)
        if not fn: continue
        try:
            code, msg = fn()
            results.append({"stage": sid, "name": name, "ok": code == 0, "msg": msg})
        except Exception as e:
            results.append({"stage": sid, "name": name, "ok": False, "msg": str(e)[:80]})
    return results

if __name__ == "__main__":
    import sys
    G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[36m'; BOLD='\033[1m'; D_='\033[2m'; N='\033[0m'
    cmd = sys.argv[1] if len(sys.argv) > 1 else "test"

    if cmd == "test":
        r = test_all()
        print(f"\n  {B}{BOLD}═══ Menu Tester ═══{N}\n")
        print(f"  {B}Всього пунктів:{N} {r['total']}")
        print(f"  {G}✓ OK:{N}      {r['counts'].get('OK',0)}")
        print(f"  {Y}⚙ INTER:{N}    {r['counts'].get('INTER',0)} (потребує вводу)")
        print(f"  {Y}⚠ STUB:{N}     {r['counts'].get('STUB',0)} (заглушки)")
        print(f"  {R}✗ FAIL:{N}     {r['counts'].get('FAIL',0)}")
        print(f"  {R}🚫 MISS:{N}     {r['counts'].get('MISS',0)} (немає файлу)")
        print()
        # Показати fail та miss
        fails = [(m, v) for m, v in r["items"].items() if v["status"] in ("FAIL","MISS")]
        if fails:
            print(f"  {R}Проблеми ({len(fails)}):{N}")
            for mid, v in fails[:25]:
                mark = "✗" if v["status"] == "FAIL" else "🚫"
                print(f"    {mark} [{mid:>3}] {v['detail'][:65]}")
        stubs = [(m, v) for m, v in r["items"].items() if v["status"] == "STUB"]
        if stubs:
            print(f"\n  {Y}Заглушки ({len(stubs)}):{N}")
            for mid, v in stubs[:15]:
                print(f"    ⚠ [{mid:>3}] {v['detail'][:65]}")

    elif cmd == "8stage":
        print(f"\n  {B}{BOLD}═══ 8-Stage Autofix ═══{N}\n")
        results = run_all_stages()
        for r in results:
            mark = f"{G}✓{N}" if r["ok"] else f"{R}✗{N}"
            print(f"  {mark} {r['name']:35s}  {r['msg']}")
        # тест після
        print(f"\n  {B}Після фіксів:{N}")
        r = test_all()
        print(f"    {G}OK: {r['counts'].get('OK',0)}{N}  "
              f"{Y}STUB: {r['counts'].get('STUB',0)}{N}  "
              f"{R}FAIL: {r['counts'].get('FAIL',0)}{N}  "
              f"{R}MISS: {r['counts'].get('MISS',0)}{N}")

    elif cmd == "json":
        print(json.dumps(test_all(), indent=2, ensure_ascii=False))

    elif cmd == "list":
        r = test_all()
        for mid, v in sorted(r["items"].items(), key=lambda x: int(x[0])):
            col = {"OK":G,"STUB":Y,"FAIL":R,"MISS":R,"INTER":Y,"WARN":Y}.get(v["status"],"")
            print(f"  {col}{v['status']:5s}{N} [{mid:>3}] {v['detail'][:60]}")
