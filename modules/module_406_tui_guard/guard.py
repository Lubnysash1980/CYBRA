#!/usr/bin/env python3
"""TUI Integrity Guard — тримає TUI синхронізованим з реальністю.

Перевіряє:
  1. Кожен case NNN) має main.sh або визначену action_* функцію
  2. Кожен пункт у MENU має відповідний case
  3. Кожен case має пункт у MENU
  4. Кожен action_* викликаний — визначений
  5. Немає подвійних case (bash бере останній)

Знаходить розходження → fix.
"""
import hashlib, json, os, re, subprocess, sys, time
from pathlib import Path

H = Path.home() / "CYBRA"
M = H / "modules"
TUI = M / "module_19_contract_tui_menu/bin/cybra_menu.sh"
PUB = H / "public/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
D = Path(__file__).resolve().parent
LOG = D / "data" / "guard.log"
STATS = D / "data" / "stats.json"

def _now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
def _log(msg, level="info"):
    line = f"[{_now()}] [{level}] {msg}"
    print(line, flush=True)
    try:
        with open(LOG, "a") as f: f.write(line + "\n")
    except Exception: pass

def _tui_hash():
    if not TUI.exists(): return None
    return hashlib.sha256(TUI.read_bytes()).hexdigest()[:16]

# ═══════════════════════════════════════════════════════════════
# PARSE
# ═══════════════════════════════════════════════════════════════
def parse_all():
    if not TUI.exists(): return None
    s = TUI.read_text()
    out = {}
    # Case handlers: NNN) ...
    out["case"] = {}
    for m in re.finditer(r'^[ \t]+(\d+)\)\s*([^;]*?)\s*;;[ \t]*$', s, re.M):
        mid = m.group(1)
        if mid not in out["case"]:
            out["case"][mid] = m.group(2).strip()
        else:
            # дублікат
            out["case"][mid] = "DUP"
    # MENU: [NNN]
    out["menu"] = set(re.findall(r'\[(\d+)\]', s))
    # Дії: action_*
    out["action_def"] = set(re.findall(r'^action_[a-z_0-9]+\(\)', s, re.M))
    out["action_use"] = set(re.findall(r'\b(action_[a-z_0-9]+)\b', s))
    return out

# ═══════════════════════════════════════════════════════════════
# CHECK
# ═══════════════════════════════════════════════════════════════
def check():
    data = parse_all()
    if not data:
        return {"ok": False, "reason": "TUI не читається"}

    issues = []

    # 1. Case → що він робить?
    for mid, action in data["case"].items():
        if action == "DUP":
            issues.append({"type":"dup_case","id":mid,"detail":f"case {mid} зустрічається двічі"})
            continue
        # Якщо action_* — має бути визначена
        m = re.match(r'(action_[a-z_0-9]+)', action)
        if m:
            fname = m.group(1)
            if f"{fname}()" not in data["action_def"]:
                issues.append({"type":"missing_action","id":mid,"detail":f"{fname} не визначена"})
            continue
        # Якщо bash "$HOME/CYBRA/..." — файл має існувати
        m = re.search(r'(?:bash|sh)\s+"?([^\s"]+)"?', action)
        if m:
            f = m.group(1).replace("$HOME/", str(H)+"/").replace("$H/", str(H)+"/")
            # якщо подвійний $H/CYBRA/CYBRA
            if "CYBRA/CYBRA/" in f:
                issues.append({"type":"double_cybra","id":mid,"detail":f"подвійний CYBRA: {f[:60]}"})
                continue
            if not Path(f).exists():
                issues.append({"type":"missing_file","id":mid,"detail":f"немає {Path(f).name}"})
                continue

    # 2. Case без пункту MENU (крім 0,402)
    for mid in data["case"]:
        if mid in ("0",): continue
        if mid not in data["menu"]:
            issues.append({"type":"case_no_menu","id":mid,"detail":f"case {mid} без пункту меню"})

    # 3. MENU без case
    for mid in data["menu"]:
        if mid in ("0",): continue
        if mid not in data["case"]:
            issues.append({"type":"menu_no_case","id":mid,"detail":f"пункт [{mid}] без case"})

    # 4. action_* викликані але не визначені
    missing_actions = data["action_use"] - {a[:-2] for a in data["action_def"]}
    for a in sorted(missing_actions)[:20]:
        if a in ("action_",): continue
        issues.append({"type":"missing_action_call","id":"?","detail":f"{a} викликана але не визначена"})

    result = {
        "ok": len(issues) == 0,
        "at": _now(),
        "tui_hash": _tui_hash(),
        "case_count": len(data["case"]),
        "menu_count": len(data["menu"]),
        "action_def": len(data["action_def"]),
        "issues_count": len(issues),
        "issues": issues,
    }

    # зберегти stats
    STATS.write_text(json.dumps(result, indent=2, ensure_ascii=False))
    return result

# ═══════════════════════════════════════════════════════════════
# FIX
# ═══════════════════════════════════════════════════════════════
def fix_double_cybra():
    """Виправляє подвійний CYBRA у будь-якому вигляді."""
    if not TUI.exists(): return 0
    s = TUI.read_text()
    total = 0
    # Всі варіанти
    for a, b in [
        ("$HOME/CYBRA/CYBRA/", "$HOME/CYBRA/"),
        ("$H/CYBRA/CYBRA/", "$H/CYBRA/"),
        ("/${HOME}/CYBRA/CYBRA/", "/${HOME}/CYBRA/"),
        ("/home/CYBRA/CYBRA/", "/home/CYBRA/"),
        (str(H) + "/CYBRA/", str(H) + "/"),
    ]:
        n = s.count(a)
        if n:
            s = s.replace(a, b)
            total += n
    if total:
        TUI.write_text(s)
        if PUB.exists(): PUB.write_text(s)
        _log(f"fix_double_cybra: {total} замін", "warn")
    return total

def fix_add_stub_cases():
    """Додає case для пунктів меню без case."""
    data = parse_all()
    if not data: return 0
    missing = []
    for mid in data["menu"]:
        if mid in ("0",): continue
        if mid not in data["case"]:
            missing.append(mid)
    if not missing: return 0
    s = TUI.read_text()
    # вставити перед останнім *)
    insert = "\n".join([
        f'        {mid}) echo "⚠ [{mid}] не має case"; echo "   Виправ: cybra → 406 → fix"; read -rp "Enter…" _ ;;'
        for mid in sorted(missing, key=int)
    ])
    m = re.search(r'^(\s*)\*\)', s, re.M)
    if not m:
        return 0
    ind = m.group(1)
    s = s[:m.start()] + insert + "\n" + s[m.start():]
    TUI.write_text(s)
    if PUB.exists(): PUB.write_text(s)
    _log(f"fix_add_stub_cases: {len(missing)} case", "warn")
    return len(missing)

def fix():
    """Загальний фікс."""
    total = 0
    total += fix_double_cybra()
    total += fix_add_stub_cases()
    return total

# ═══════════════════════════════════════════════════════════════
# CLI
# ═══════════════════════════════════════════════════════════════
if __name__ == "__main__":
    import sys
    G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[36m'; BOLD='\033[1m'; D_='\033[2m'; N='\033[0m'
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"

    if cmd == "check":
        r = check()
        col = G if r["ok"] else R
        print(f"\n  {B}{BOLD}═══ TUI Integrity Guard ═══{N}\n")
        print(f"  TUI hash:     {r.get('tui_hash')}")
        print(f"  Cases:        {r.get('case_count')}")
        print(f"  Menu items:   {r.get('menu_count')}")
        print(f"  Action defs:  {r.get('action_def')}")
        print(f"\n  {col}{'✓ OK' if r['ok'] else '✗ '+str(r['issues_count'])+' проблем'}{N}")
        if r["issues"]:
            # групуємо по типу
            by_type = {}
            for i in r["issues"]:
                by_type.setdefault(i["type"], []).append(i)
            for t, items in by_type.items():
                print(f"\n  {Y}{t}{N} ({len(items)}):")
                for i in items[:8]:
                    print(f"    ✗ [{i['id']:>3}] {i['detail'][:70]}")

    elif cmd == "fix":
        n = fix()
        print(f"  {G}✓{N} виправлено: {n}")
        check()

    elif cmd == "json":
        print(json.dumps(check(), indent=2, ensure_ascii=False))

    elif cmd == "monitor":
        """Постійний моніторинг — для daemon."""
        prev_hash = None
        while True:
            r = check()
            h = r.get("tui_hash")
            if prev_hash and h != prev_hash:
                _log(f"TUI changed: {prev_hash} → {h}", "warn")
                if not r["ok"]:
                    _log(f"TUI broken ({r['issues_count']} issues) → FIX", "warn")
                    fix()
                    r = check()
            prev_hash = h
            time.sleep(60)

    elif cmd == "daemon":
        _log("TUI Guard daemon START")
        prev_hash = None
        while True:
            try:
                r = check()
                h = r.get("tui_hash")
                if prev_hash and h != prev_hash:
                    _log(f"TUI changed: {prev_hash} → {h}", "warn")
                    if not r["ok"]:
                        _log(f"broken ({r['issues_count']}) → FIX", "warn")
                        fix()
                prev_hash = h
            except Exception as e:
                _log(f"error: {e}", "error")
            time.sleep(60)
