#!/usr/bin/env python3
"""Візуалізація multi-sig сесій з 123."""
import sys, os, json, time
from pathlib import Path
H = Path.home() / "CYBRA"
sys.path.insert(0, str(H/"modules/module_123_multisig"))

def render(sid=None):
    try: import multisig as MS
    except Exception as e: print(f"  err: {e}"); return
    if sid:
        s = MS.get_session(sid)
        if not s: print(f"  сесія {sid} не знайдена"); return
        _draw_one(s)
    else:
        sessions = MS.sessions()
        if not sessions: print("  (немає сесій)"); return
        _draw_list(sessions)

def _draw_one(s):
    G='\033[32m'; Y='\033[33m'; B='\033[36m'; R='\033[31m'; D='\033[2m'; N='\033[0m'
    print(f"\n{B}═══ Multi-Sig Session ═══{N}")
    print(f"  SID:     {s['sid']}")
    print(f"  CID:     {s['cid']}")
    print(f"  Схема:   {s['scheme']} ({s['threshold']} з N)")
    print(f"  Статус:  {G if s['status']=='complete' else Y}{s['status']}{N}")

    got = len(s["signatures"]); total = s["threshold"]
    pct = min(100, int(got/total*100))
    bar_w = 40; fill = int(bar_w * pct / 100)
    bar = "█"*fill + "░"*(bar_w-fill)
    print(f"\n  {G}{bar}{N}  {got}/{total}")

    print(f"\n  {B}Підписи:{N}")
    if s["signatures"]:
        for i, sig in enumerate(s["signatures"], 1):
            print(f"    {G}✓{N} {i}. {sig['signer'][:16]}…  {D}{sig['at']}{N}")
    else:
        print(f"    {D}немає{N}")
    need = total - got
    if need > 0:
        print(f"\n  {Y}Потрібно ще: {need}{N}")
    print()

def _draw_list(sessions):
    G='\033[32m'; Y='\033[33m'; B='\033[36m'; D='\033[2m'; N='\033[0m'
    print(f"\n{B}Усі сесії ({len(sessions)}){N}\n")
    for s in sessions[:20]:
        got = len(s["signatures"]); tot = s["threshold"]
        col = G if s["status"]=="complete" else Y
        print(f"  {col}●{N} {s['sid']}  {s['cid'][:22]:24s}  {got}/{tot}  [{s['status']}]")
    print()

if __name__ == "__main__":
    sid = sys.argv[1] if len(sys.argv) > 1 else None
    render(sid)
