#!/usr/bin/env python3
"""Журнал інцидентів + офлайн-аналіз патернів."""
import json, os, time, hashlib
from pathlib import Path
from collections import Counter

H = Path.home() / "CYBRA"
J = H / "modules/module_120_ai_guardian/journal.jsonl"
KB = H / "modules/module_120_ai_guardian/knowledge.json"

def record(entry: dict):
    entry["ts"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    with open(J, "a") as f:
        f.write(json.dumps(entry) + "\n")
    # ротація
    try:
        if J.stat().st_size > 3_000_000:
            lines = J.read_text().splitlines()
            J.write_text("\n".join(lines[-2000:]) + "\n")
    except Exception: pass

def load_knowledge():
    if KB.exists():
        try: return json.loads(KB.read_text())
        except Exception: return {}
    return {}

def save_knowledge(k):
    KB.write_text(json.dumps(k, indent=2))

def learn(check_id, action_id, success: bool):
    """Запам'ятовує що спрацювало/не спрацювало для даного чеку."""
    k = load_knowledge()
    k.setdefault(check_id, {}).setdefault(action_id, {"ok":0, "fail":0, "last":0})
    k[check_id][action_id]["ok" if success else "fail"] += 1
    k[check_id][action_id]["last"] = time.time()
    save_knowledge(k)

def best_action(check_id):
    """Повертає найуспішнішу дію для даного чеку."""
    k = load_knowledge()
    acts = k.get(check_id, {})
    if not acts: return None
    best, ratio = None, -1
    for a, s in acts.items():
        tot = s["ok"] + s["fail"]
        if tot == 0: continue
        r = s["ok"] / tot
        # пріоритет свіжим
        if r > ratio or (r == ratio and s["last"] > (acts.get(best,{}).get("last",0))):
            best, ratio = a, r
    return (best, ratio) if best else None

def pattern_summary(n_last=200):
    """Аналіз останніх записів — топ проблем і ефективність фіксів."""
    if not J.exists(): return {}
    lines = J.read_text().splitlines()[-n_last:]
    fails, fixed, unfixed, acts = Counter(), Counter(), Counter(), Counter()
    for line in lines:
        try: e = json.loads(line)
        except Exception: continue
        if e.get("kind") == "check_fail":
            fails[e.get("check_id","?")] += 1
        elif e.get("kind") == "heal":
            if e.get("success"): fixed[e.get("action","?")] += 1
            else: unfixed[e.get("action","?")] += 1
            acts[e.get("action","?")] += 1
    return {
        "top_fails": fails.most_common(5),
        "top_fixed": fixed.most_common(5),
        "top_unfixed": unfixed.most_common(5),
        "total_actions": sum(acts.values())
    }

def suggest(check_id, fail_detail=""):
    """Офлайн-пропозиція: спершу те, що раніше спрацювало."""
    b = best_action(check_id)
    if b and b[1] >= 0.5:
        return {"action": b[0], "confidence": round(b[1], 2),
                "source": "learned"}
    # базові правила
    rules = {
        "env.cloudflared":     ("install_pkg", "cloudflared"),
        "env.git":             ("install_pkg", "git"),
        "env.qrencode":        ("install_pkg", "qrencode"),
        "env.termux-notification": ("install_pkg", "termux-api"),
        "py.qrcode":           ("pip_install", "qrcode pillow"),
        "py.nacl":             ("pip_install", "pynacl"),
        "py.eth_account":      ("pip_install", "eth-account"),
        "autonode.running":    ("restart_autonode", ""),
        "autonode.networks":   ("restart_autonode", ""),
    }
    for k, (act, tgt) in rules.items():
        if check_id.startswith(k):
            return {"action": act, "target": tgt, "confidence": 0.7, "source": "rule"}
    if check_id.startswith("key."):
        return {"action": "chmod_key_600", "target": fail_detail, "confidence": 0.95, "source": "rule"}
    if "disk.logs" in check_id or "disk.backups" in check_id:
        return {"action": "cleanup_logs", "target": "", "confidence": 0.9, "source": "rule"}
    return None

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "summary":
        print(json.dumps(pattern_summary(), indent=2, ensure_ascii=False))
