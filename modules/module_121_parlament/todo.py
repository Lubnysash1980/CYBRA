#!/usr/bin/env python3
"""Генерує список TODO для парламенту на основі стану системи."""
import sys, os, json, importlib.util
from pathlib import Path

D = Path(__file__).resolve().parent
H = Path.home() / "CYBRA"
sys.path.insert(0, str(D))
import actions

# Завантажуємо чекери з 120 (Guardian)
def load_checkers():
    g_dir = H / "modules/module_120_ai_guardian/checks"
    if not g_dir.exists(): return []
    out = []
    for py in sorted(g_dir.glob("check_*.py")):
        try:
            spec = importlib.util.spec_from_file_location(py.stem, py)
            m = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(m)
            out.append((py.stem, m))
        except Exception: pass
    return out

def run_all_checks():
    issues = []
    for name, m in load_checkers():
        try:
            for r in m.run():
                if r["status"] in ("warn","fail","critical"):
                    issues.append(r)
        except Exception as e:
            issues.append({"id": f"checker.{name}",
                           "name": f"Чекер {name}",
                           "status": "warn", "detail": str(e)[:60],
                           "fix_hint": ""})
    return issues

def suggest_action(issue):
    """Визначає дію для проблеми."""
    cid = issue["id"]; det = issue.get("detail","")
    rules = [
        ("key.",              "chmod_key_600",  lambda d: next((t for t in d.split() if t.startswith("/") and "keys" in t), "")),
        ("disk.logs",         "cleanup_logs",   lambda d: ""),
        ("disk.backups",      "cleanup_logs",   lambda d: ""),
        ("autonode.running",  "rm_dead_pid",    lambda d: str(H/"run/autonode.pid")),
        ("autonode.networks", "restart_autonode", lambda d: ""),
        ("env.cloudflared",   "install_pkg",    lambda d: "cloudflared"),
        ("env.git",           "install_pkg",    lambda d: "git"),
        ("env.qrencode",      "install_pkg",    lambda d: "qrencode"),
        ("env.termux-notification", "install_pkg", lambda d: "termux-api"),
        ("py.qrcode",         "pip_install",    lambda d: "qrcode pillow"),
        ("py.nacl",           "pip_install",    lambda d: "pynacl"),
        ("py.eth_account",    "pip_install",    lambda d: "eth-account"),
        ("tui.handlers",      "create_tui_backup", lambda d: ""),
        ("tui.syntax",        "restore_tui",    lambda d: ""),
    ]
    for prefix, act, tgt_fn in rules:
        if cid.startswith(prefix):
            return act, tgt_fn(det)
    # за правилом у action.check
    for aid, a in actions.ACTIONS.items():
        chk = a.get("check")
        if chk and chk(cid):
            return aid, ""
    return None, ""

def plan():
    """Повертає структурований план."""
    issues = run_all_checks()
    items = []
    for iss in issues:
        act, target = suggest_action(iss)
        lvl = actions.ACTIONS.get(act, {}).get("level", "manual") if act else "manual"
        items.append({
            "check_id": iss["id"], "name": iss["name"],
            "status": iss["status"], "detail": iss["detail"],
            "action": act, "action_name": actions.ACTIONS.get(act,{}).get("name","—") if act else "—",
            "level": lvl, "target": target,
        })
    # пріоритет: critical > fail > warn; auto > vote > veto > manual
    lvl_w = {"auto":0, "vote":1, "veto":2, "manual":3}
    st_w  = {"critical":0, "fail":1, "warn":2}
    items.sort(key=lambda x: (st_w.get(x["status"],9), lvl_w.get(x["level"],9)))
    return items

def print_plan(items):
    G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[36m'; D='\033[2m'; N='\033[0m'
    if not items:
        print(f"\n  {G}✅ Все гаразд — жодних дій не потрібно{N}\n")
        return
    auto  = [i for i in items if i["level"]=="auto"]
    vote  = [i for i in items if i["level"]=="vote"]
    veto  = [i for i in items if i["level"]=="veto"]
    man   = [i for i in items if i["level"]=="manual"]

    print(f"\n  {B}═══ ЩО РОБИТИ ({len(items)} пунктів) ═══{N}")
    print(f"  {G}auto={len(auto)}{N}  {Y}vote={len(vote)}{N}  {R}veto={len(veto)}{N}  manual={len(man)}\n")

    def _print(lst, title, color):
        if not lst: return
        print(f"  {color}▸ {title}{N}")
        for i in lst:
            st = {"critical":"🚨","fail":"🔴","warn":"🟡"}.get(i["status"],"•")
            print(f"    {st} {i['name']:38s}  {D}{i['action_name']}{N}")
            if i["target"]:
                print(f"       {D}target: {i['target']}{N}")
        print()

    _print(auto, "АВТО (парламент виконає сам)", G)
    _print(vote, "ГОЛОСУВАННЯ (потрібен кворум)", Y)
    _print(veto, "VETO (founder + кворум)", R)
    _print(man,  "ВРУЧНУ", D)

if __name__ == "__main__":
    items = plan()
    if len(sys.argv) > 1 and sys.argv[1] == "json":
        print(json.dumps(items, indent=2, ensure_ascii=False))
    else:
        print_plan(items)
