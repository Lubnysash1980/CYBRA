#!/usr/bin/env python3
"""CYBRA Controllers — централізована перевірка контролерів системи:
  - LevelController  (7 рівнів EVO)
  - Exoskeleton      (зовнішня оболонка)
  - BinaryMixer      (бінарне змішування)
  - NodeStateController (стан вузлів)
  - IntegrityController (цілісність)
"""
import json, os, subprocess, time, sys
from pathlib import Path

H = Path.home() / "CYBRA"
M = H / "modules"
D = Path(__file__).resolve().parent
LOG = D / "data" / "log.jsonl"

def _run(cmd, timeout=10):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout + r.stderr).strip()
    except Exception: return 1, ""

def _log(entry):
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
    except Exception: pass
    entry["ts"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    with open(LOG, "a") as f: f.write(json.dumps(entry, ensure_ascii=False) + "\n")

# ─── КОНТРОЛЕРИ ───
def c_level():
    """EVO7 — 7 рівнів."""
    p = M / "module_96_evo7/main.sh"
    if p.exists(): return True, "модуль 96 (EVO7) присутній"
    # альтернатива
    for d in M.glob("module_9[6-9]_*"):
        return True, f"модуль {d.name} присутній"
    return False, "немає модуля 96-99"

def c_exoskeleton():
    """Exoskeleton — зовнішня оболонка (LevelController тощо)."""
    for path in [M/"module_97_evo_controller", H/"lib"]:
        if path.exists():
            files = list(path.glob("**/*Exoskeleton*")) + list(path.glob("**/*exoskeleton*"))
            if files: return True, f"{len(files)} файлів у {path.name}"
    return False, "не знайдено"

def c_binary_mixer():
    """BinaryMixer — модуль 102."""
    p = M / "module_102_binmix_daemon"
    if p.exists(): return True, "модуль 102 (binmix) присутній"
    for d in M.glob("module_10[0-2]_*"):
        return True, f"модуль {d.name}"
    return False, "модуль 102 відсутній"

def c_node_state():
    """NodeState — autonode.json."""
    f = H / "run" / "autonode.json"
    if not f.exists(): return False, "autonode.json відсутній"
    try:
        d = json.loads(f.read_text())
        nets = d.get("networks", {})
        online = sum(1 for v in nets.values() if v.get("state") == "ok")
        total = len(nets)
        if online == total and total > 0:
            return True, f"{online}/{total} мереж online"
        return False, f"тільки {online}/{total} online"
    except Exception as e:
        return False, f"parse: {e}"

def c_integrity():
    """Hash-chain парламенту + metrics_git."""
    try:
        sys.path.insert(0, str(M/"module_121_parlament"))
        import parliament as P
        r = P.verify_chain()
        broken = sum(x["broken"] for x in r.values())
        if broken > 0: return False, f"{broken} порушень hash-chain"
        return True, "hash-chain цілісний"
    except Exception as e:
        return False, f"parliament: {e}"

def c_git_sync():
    """Git синхронізація."""
    gm = H / "git_module"
    if not (gm/".git").exists(): return False, "git_module відсутній"
    rc, out = _run(f"cd {gm} && git status --porcelain | wc -l")
    n = int(out.strip() or 0)
    if n > 0: return False, f"{n} незакомічено"
    return True, "git чистий"

def c_backend():
    """Backend = enabled процеси у PM online."""
    import json, subprocess
    cfg = H / "config/pm_processes.json"
    if not cfg.exists():
        return True, "немає конфігу"
    try:
        procs = json.loads(cfg.read_text()).get("processes", {})
    except Exception as e:
        return False, f"cfg read: {e}"

    # тільки enabled
    enabled = [n for n, p in procs.items() if p.get("enabled", True) and not p.get("_phone_disabled")]
    if not enabled:
        return True, "немає enabled процесів"

    # pids — читаємо через pgrep match_pattern
    online = 0
    offline = []
    for name in enabled:
        pat = procs[name].get("match_pattern") or name
        # спрощено — pgrep по pattern
        r = subprocess.run(["pgrep", "-f", pat], capture_output=True, timeout=5)
        if r.returncode == 0:
            online += 1
        else:
            offline.append(name)

    if not offline:
        return True, f"{online}/{len(enabled)} online"
    return False, f"{online}/{len(enabled)} online, offline: {','.join(offline[:3])}"

def c_signatures():
    """Перевіряє що всі АКТИВНІ контракти підписані.
    Draft/awaiting — не рахуються як порушення."""
    E = H / "modules/module_19_contract_tui_menu/evidence"
    if not E.exists(): return True, "немає evidence"
    contracts = list(E.glob("C-INV-*.json"))
    if not contracts: return True, "немає контрактів"
    # статуси, при яких підпис ОБОВ'ЯЗКОВИЙ
    SIGNED_REQUIRED = {"signed","active","funded","delivered"}
    # статуси, при яких підпис ще НЕ обов'язковий (bootstrap)
    NO_SIG_YET = {"draft","awaiting_payment","invoice_received","pending","awaiting_order_confirm"}
    unsigned_buyer = []
    unsigned_seller = []
    complete = 0
    pending = 0
    for c in contracts:
        try: d = json.loads(c.read_text())
        except Exception: continue
        cid = d.get("cid") or c.stem
        status = d.get("status", "draft")
        # якщо draft/awaiting — не рахуємо
        if status in NO_SIG_YET:
            pending += 1
            continue
        buyer_sig = E / f"{cid}_buyer.sig"
        seller_sig = E / f"{cid}_seller.sig"
        if not buyer_sig.exists():
            unsigned_buyer.append(cid)
        if d.get("needs_seller_sig") and not seller_sig.exists():
            unsigned_seller.append(cid)
        if buyer_sig.exists() and (not d.get("needs_seller_sig") or seller_sig.exists()):
            complete += 1
    total = len(contracts)
    if unsigned_buyer:
        return False, f"buyer не підписав: {len(unsigned_buyer)}/{total}"
    if unsigned_seller:
        return False, f"seller не підписав: {len(unsigned_seller)}/{total}"
    if pending == total:
        return True, f"всі {total} у draft/awaiting (підпис пізніше)"
    return True, f"всі активні підписані ({complete}/{total}, draft: {pending})"

CONTROLLERS = [
    ("level",      "LevelController (EVO7)",  c_level),
    ("exoskeleton", "Exoskeleton",             c_exoskeleton),
    ("binmix",     "BinaryMixer",              c_binary_mixer),
    ("node_state", "NodeStateController",      c_node_state),
    ("integrity",  "IntegrityController",      c_integrity),
    ("git_sync",   "GitSyncController",        c_git_sync),
    ("backend",    "BackendController",        c_backend),
    ("signatures", "SignatureController",      c_signatures),
]

def check_all():
    out = []
    for cid, name, fn in CONTROLLERS:
        try:
            ok, msg = fn()
        except Exception as e:
            ok, msg = False, str(e)[:100]
        out.append({"id": cid, "name": name, "ok": ok, "msg": msg})
        _log({"controller": cid, "ok": ok, "msg": msg})
    return out

def auto_fix():
    """Автовиправлення контролерів."""
    fixes = []
    for c in check_all():
        if c["ok"]: continue
        cid = c["id"]
        if cid == "backend":
            rc, _ = _run("cybra-pm start-all", timeout=60)
            fixes.append(("backend", rc == 0, "cybra-pm start-all"))
        elif cid == "node_state":
            rc, _ = _run("cybra-pm restart autonode", timeout=30)
            fixes.append(("node_state", rc == 0, "restart autonode"))
        elif cid == "git_sync":
            rc, _ = _run("cd ~/CYBRA/git_module && git add -A && git commit -m 'autoheal' --allow-empty", timeout=30)
            fixes.append(("git_sync", rc == 0, "git commit"))
        elif cid == "integrity":
            rc, _ = _run(f"python3 {M}/module_121_parlament/completion.py run", timeout=60)
            fixes.append(("integrity", rc == 0, "completion run"))
    return fixes

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    if cmd == "check":
        G='\033[32m'; R='\033[31m'; B='\033[36m'; N='\033[0m'
        for c in check_all():
            col = G if c["ok"] else R
            mark = "✓" if c["ok"] else "✗"
            print(f"  {col}{mark}{N} {c['name']:28s} {c['msg']}")
    elif cmd == "fix":
        for cid, ok, msg in auto_fix():
            col = "\033[32m" if ok else "\033[31m"
            print(f"  {col}·{chr(27)}[0m {cid:14s} {msg}")
    elif cmd == "json":
        print(json.dumps(check_all(), indent=2, ensure_ascii=False))
