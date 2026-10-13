#!/usr/bin/env python3
"""Menu Doctor v2 — правильний парсер + реальні заглушки."""
import json, os, re, subprocess, sys, time
from pathlib import Path

H = Path.home() / "CYBRA"
M = H / "modules"
TUI = M / "module_19_contract_tui_menu/bin/cybra_menu.sh"
D = Path(__file__).resolve().parent
CACHE = D / "data" / "menu_state.json"

def _run(cmd, timeout=10):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout + r.stderr)[:200]
    except Exception as e:
        return 1, str(e)[:100]

def parse_tui():
    """Парсить TUI правильно."""
    if not TUI.exists(): return {}
    s = TUI.read_text()
    items = {}
    # Match: `NNN)` на початку рядка, потім все до `;;`
    for m in re.finditer(r'^[ \t]+(\d+)\)\s*(.*?)\s*;;[ \t]*$', s, re.M):
        mid = m.group(1)
        action = m.group(2).strip()
        items[mid] = action
    return items

def get_function_body(fname):
    """Витягує тіло функції action_* з TUI."""
    s = TUI.read_text()
    # Знайти початок функції
    pat = re.compile(rf'^{re.escape(fname)}\(\)\s*\{{', re.M)
    m = pat.search(s)
    if not m: return None
    # Знайти відповідну }
    start = m.end()
    depth = 1
    i = start
    while i < len(s) and depth > 0:
        if s[i] == '{': depth += 1
        elif s[i] == '}': depth -= 1
        i += 1
    return s[start:i-1]

def check_action(mid, action):
    """Перевіряє дію. Повертає (status, reason)."""
    # 1. action_*
    m = re.match(r'^(action_[a-z_0-9]+)', action)
    if m:
        fname = m.group(1)
        body = get_function_body(fname)
        if body is None:
            return "fail", f"{fname}: не визначена"
        # Заглушка?
        if "not implemented" in body or "не реалізовано" in body:
            return "stub", f"{fname}: заглушка"
        if len(body.strip()) < 30:
            return "stub", f"{fname}: закоротка ({len(body)} B)"
        if "TODO" in body:
            return "stub", f"{fname}: TODO"
        return "ok", f"{fname} ✓"

    # 2. bash/sh "$H/..." або "$HOME/..."
    m = re.search(r'(?:bash|sh)\s+"?([^\s"]+\.sh)"?', action)
    if m:
        f = m.group(1)
        f = f.replace("$H/", str(H)+"/").replace("$HOME/", str(H)+"/")
        if f.startswith("~/'"): f = f.replace("~/", str(H)+"/")
        # розкрити змінні через bash
        rc, out = _run(f'echo "{f}"')
        if rc == 0: f = out.strip()
        p = Path(f)
        if not p.exists():
            return "fail", f"немає: {p.name}"
        if not os.access(p, os.X_OK):
            return "warn", f"не chmod+x: {p.name}"
        rc, out = _run(f"bash -n {p}")
        if rc != 0:
            return "fail", f"syntax: {out[:50]}"
        return "ok", f"{p.name} ✓"

    # 3. cybra-pm
    m = re.search(r'(cybra-pm\s+\S+)', action)
    if m:
        cmd = m.group(1).split()[0]
        rc, _ = _run(f"command -v {cmd}")
        return ("ok", cmd) if rc == 0 else ("fail", f"немає {cmd}")

    # 4. Заглушка
    if "not implemented" in action or "TODO" in action:
        return "stub", action[:40]

    # 5. Порожня
    if not action.strip():
        return "fail", "порожня дія"

    return "warn", f"невідомо: {action[:40]}"

def check_all():
    items = parse_tui()
    results = {}
    counts = {"ok": 0, "warn": 0, "stub": 0, "fail": 0}
    for mid, action in sorted(items.items(), key=lambda x: int(x[0])):
        status, reason = check_action(mid, action)
        results[mid] = {"status": status, "reason": reason, "action": action[:80]}
        counts[status] = counts.get(status, 0) + 1

    out = {
        "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "total": len(results), "counts": counts, "items": results,
    }
    CACHE.write_text(json.dumps(out, indent=2, ensure_ascii=False))
    return out

def fix_stubs():
    """Замінює заглушки на корисні повідомлення з посиланням на модуль."""
    s = TUI.read_text()
    data = json.loads(CACHE.read_text()) if CACHE.exists() else check_all()
    stubs = [m for m, v in data["items"].items() if v["status"] in ("stub","fail")]
    if not stubs: return 0, []
    fixed = []
    for mid in stubs:
        info = data["items"][mid]
        action = info["action"]
        # витягнути ім'я функції
        m = re.match(r'^(action_[a-z_0-9]+)', action)
        if m:
            fname = m.group(1)
            # замінити тіло функції
            pat = re.compile(rf'^{re.escape(fname)}\(\)\s*\{{.*?^\}}', re.M | re.DOTALL)
            new_body = (
                f'{fname}() {{\n'
                f'  echo "⚠ Пункт [{mid}] ще не реалізовано"\n'
                f'  echo "   Причина: {info["reason"][:50]}"\n'
                f'  echo "   Модуль: module_{mid}_* (перевір чи встановлено)"\n'
                f'  echo "   Стан:  python3 ~/CYBRA/modules/module_399_gate/gate.py status"\n'
                f'  read -rp "Enter…" _\n'
                f'}}'
            )
            s2 = pat.sub(new_body, s, count=1)
            if s2 != s:
                s = s2
                fixed.append(mid)
    if fixed:
        TUI.write_text(s)
    return len(fixed), fixed

if __name__ == "__main__":
    import sys
    G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[36m'; BOLD='\033[1m'; D_='\033[2m'; N='\033[0m'
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"

    if cmd == "check":
        data = check_all()
        print(f"\n  {B}{BOLD}═══ Menu Doctor v2 ═══{N}\n")
        print(f"  {B}Всього пунктів:{N}  {data['total']}")
        print(f"  {G}✓ OK:{N}     {data['counts'].get('ok', 0)}")
        print(f"  {Y}! Warn:{N}   {data['counts'].get('warn', 0)}")
        print(f"  {Y}● Stub:{N}   {data['counts'].get('stub', 0)}  ← заглушки")
        print(f"  {R}✗ Fail:{N}   {data['counts'].get('fail', 0)}")

        stubs = [(m, v) for m, v in data["items"].items() if v["status"] == "stub"]
        if stubs:
            print(f"\n  {Y}Заглушки ({len(stubs)}):{N}")
            for mid, v in stubs[:25]:
                print(f"    ● [{mid:>3}] {v['reason'][:60]}")

        fails = [(m, v) for m, v in data["items"].items() if v["status"] == "fail"]
        if fails:
            print(f"\n  {R}Зламані ({len(fails)}):{N}")
            for mid, v in fails[:20]:
                print(f"    ✗ [{mid:>3}] {v['reason'][:60]}")

    elif cmd == "fix":
        n, fixed = fix_stubs()
        print(f"  {G}✓{N} виправлено заглушок: {n}")
        if fixed:
            print(f"  IDs: {' '.join(fixed[:20])}")
        check_all()

    elif cmd == "stubs":
        data = json.loads(CACHE.read_text()) if CACHE.exists() else check_all()
        stubs = sorted([m for m, v in data["items"].items() if v["status"] == "stub"], key=int)
        print(" ".join(stubs))

    elif cmd == "broken":
        data = json.loads(CACHE.read_text()) if CACHE.exists() else check_all()
        fails = sorted([m for m, v in data["items"].items() if v["status"] == "fail"], key=int)
        print(" ".join(fails))

    elif cmd == "json":
        print(json.dumps(check_all(), indent=2, ensure_ascii=False))
