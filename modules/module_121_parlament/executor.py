#!/usr/bin/env python3
"""Виконавець плану парламенту."""
import sys, os, json, time
from pathlib import Path

D = Path(__file__).resolve().parent
sys.path.insert(0, str(D))
import actions, todo, parliament as P

G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[36m'; DIM='\033[2m'; N='\033[0m'

def is_solo():
    """Чи парламент з одного члена (founder)?"""
    return len([m for m in P.members()["members"] if m.get("active", True)]) <= 1

def founder_addr():
    for m in P.members()["members"]:
        if m.get("active", True) and m["role"] == "founder":
            return m["addr"]
    m = P.members()["members"]
    return m[0]["addr"] if m else None

def auto_execute(items, verbose=True):
    """Виконує всі auto-дії."""
    done, failed = [], []
    for it in items:
        if it["level"] != "auto": continue
        if verbose: print(f"  {G}→{N} {it['action_name']}")
        ok, msg = actions.execute(it["action"], it["target"], source="auto")
        mark = f"{G}✓{N}" if ok else f"{R}✗{N}"
        if verbose: print(f"    {mark} {msg}")
        (done if ok else failed).append(it)
    return done, failed

def propose_actions(items, author=None):
    """Створює пропозиції для vote/veto дій. Якщо solo — підписує одразу."""
    author = author or founder_addr()
    if not author: return []
    solo = is_solo()
    created = []
    for it in items:
        if it["level"] not in ("vote", "veto"): continue
        payload = {"action": it["action"], "target": it["target"],
                   "check_id": it["check_id"], "detail": it["detail"]}
        ok, why, pid = P.create_proposal(
            "upgrade",
            f"{it['action_name']} · {it['name']}",
            payload, author
        )
        if not ok:
            print(f"  {R}✗{N} {it['action_name']}: {why}")
            continue
        # Solo mode — голосуємо автоматично
        if solo:
            msg = P.sign_message(pid, author, "yes")
            P.cast_vote(pid, author, "yes", signature="solo:auto", message=msg)
            ok2, why2 = P.close_proposal(pid)
            if ok2:
                # виконуємо
                ok3, msg3 = actions.execute(it["action"], it["target"], source="solo-vote")
                mark = f"{G}✓{N}" if ok3 else f"{R}✗{N}"
                print(f"  {mark} solo-approve → {msg3}")
                # позначаємо як виконану
                P.audit("action_executed", {"pid": pid, "action": it["action"],
                                            "ok": ok3, "msg": msg3})
            else:
                print(f"  {Y}!{N} {pid} створено, але close: {why2}")
        else:
            print(f"  {Y}→{N} {it['action_name']}  →  пропозиція {pid}")
        created.append({"pid": pid, "action": it["action"], "name": it["action_name"]})
    return created

def apply_approved(verbose=True):
    """Виконує дії з схвалених пропозицій, які ще не виконувались."""
    done = []
    for p in P.proposals(status="approved"):
        if p.get("executed"): continue
        payload = p.get("payload") or {}
        aid = payload.get("action")
        if not aid or aid not in actions.ACTIONS: continue
        if verbose:
            print(f"  {G}→{N} виконую {aid} (з {p['pid']})")
        ok, msg = actions.execute(aid, payload.get("target",""), source="vote")
        mark = f"{G}✓{N}" if ok else f"{R}✗{N}"
        if verbose: print(f"    {mark} {msg}")
        # позначаємо виконаною
        upd = dict(p); upd["executed"] = True
        upd["exec_ok"] = ok; upd["exec_msg"] = msg
        upd["exec_ts"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        # append через parliament
        with open(P.PROPOSALS, "a") as f:
            import json as _j
            upd["_prev"] = P._last_hash(P.PROPOSALS)
            upd["_hash"] = P._hash_obj(upd)
            f.write(_j.dumps(upd, ensure_ascii=False, sort_keys=True) + "\n")
        P.audit("action_executed_from_vote", {"pid": p["pid"], "action": aid, "ok": ok})
        if ok: done.append(p["pid"])
    return done

def full_cycle(verbose=True):
    """Повний цикл: аналіз → auto → пропозиції → виконання схвалених."""
    if verbose:
        print(f"\n{B}═══ Парламент · повний цикл ═══{N}\n")

    # 1. Аналіз
    items = todo.plan()
    if verbose:
        todo.print_plan(items)

    if not items:
        return {"auto_done":0, "proposals":0, "executed":0}

    # 2. Auto-дії
    if verbose: print(f"\n{B}── AUTO ──{N}")
    auto_done, auto_fail = auto_execute(items, verbose)

    # 3. Пропозиції для vote/veto
    if verbose: print(f"\n{B}── ПРОПОЗИЦІЇ ──{N}")
    proposals = propose_actions(items)

    # 4. Виконати вже схвалені
    if verbose: print(f"\n{B}── ВИКОНАННЯ СХВАЛЕНИХ ──{N}")
    executed = apply_approved(verbose)

    return {
        "auto_done": len(auto_done),
        "auto_fail": len(auto_fail),
        "proposals": len(proposals),
        "executed": len(executed),
    }

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "run"
    if cmd == "run":
        r = full_cycle()
        print(f"\n  {G}auto:{r['auto_done']}{N}  proposals:{r['proposals']}  executed:{r['executed']}")
    elif cmd == "auto":
        items = todo.plan()
        done, failed = auto_execute(items)
        print(f"\n  {G}✓ {len(done)}{N}  {R}✗ {len(failed)}{N}")
    elif cmd == "apply":
        done = apply_approved()
        print(f"\n  {G}✓ виконано {len(done)}{N}")
