#!/usr/bin/env python3
"""Пріоритезація: якщо auto-фіксів багато — створює одну пропозицію
'що виконувати в якому порядку' і виконує за голосуванням."""
import sys, os, json
from pathlib import Path

D = Path(__file__).resolve().parent
sys.path.insert(0, str(D))
import todo, actions, parliament as P

def top_issues(n=10):
    items = todo.plan()
    # групуємо по рівню
    groups = {"critical":[], "fail":[], "warn":[]}
    for i in items:
        if i["status"] in groups:
            groups[i["status"]].append(i)
    return items, groups

def build_agenda():
    items, groups = top_issues()
    agenda = []
    for sev in ["critical","fail","warn"]:
        for i in groups[sev]:
            agenda.append({
                "priority": {"critical":1,"fail":2,"warn":3}[sev],
                "check_id": i["check_id"], "name": i["name"],
                "action": i["action"], "level": i["level"],
            })
    return agenda

def print_agenda():
    a = build_agenda()
    G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[36m'; DIM='\033[2m'; N='\033[0m'
    if not a:
        print(f"  {G}✅ нічого критичного{N}"); return
    print(f"\n  {B}═══ AGENDA ({len(a)}) ═══{N}\n")
    for i, x in enumerate(a, 1):
        c = {1:R, 2:Y, 3:G}[x["priority"]]
        print(f"  {i:2d}. {c}P{x['priority']}{N}  {x['name'][:40]:42s} {DIM}[{x['level']}]{N}")
    return

def create_priority_proposal(author=None):
    """Створює пропозицію з agenda (для голосування)."""
    agenda = build_agenda()
    if not agenda: return None, "немає що пріоритезувати"
    if not author:
        for m in P.members()["members"]:
            if m.get("active") and m["role"] == "founder":
                author = m["addr"]; break
    if not author: return None, "немає автора"
    ok, why, pid = P.create_proposal(
        "custom", "Пріоритезація фіксів",
        {"agenda": agenda}, author)
    return (pid if ok else None), why

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "show"
    if cmd == "show": print_agenda()
    elif cmd == "json": print(json.dumps(build_agenda(), indent=2, ensure_ascii=False))
    elif cmd == "propose":
        pid, why = create_priority_proposal()
        print(f"  {'✓ '+pid if pid else '✗ '+why}")
