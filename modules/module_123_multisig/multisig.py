#!/usr/bin/env python3
"""Multi-sig для великих контрактів: 2-of-3, 3-of-5, кастомні схеми.
Кожен підпис — MetaMask через 108/QR. Підписи збираються локально,
фінальний `.sig` містить усі підписи для контракту."""
import json, os, time, hashlib, secrets, sys
from pathlib import Path

D = Path(__file__).resolve().parent
H = Path.home() / "CYBRA"
DATA = D / "data"
DATA.mkdir(parents=True, exist_ok=True)
CFG = DATA / "schemes.json"
SESSIONS = DATA / "sessions.jsonl"

DEFAULT_SCHEMES = {
    "small":  {"threshold": 1, "signers": "any"},        # 1-of-N
    "medium": {"threshold": 2, "signers": "any"},        # 2-of-N
    "large":  {"threshold": 3, "signers": "any"},        # 3-of-N
    "critical": {"threshold": 3, "signers": "founder+2"}, # founder + 2
}

def _now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def _load(path, default=None):
    if not path.exists(): return default if default is not None else {}
    try: return json.loads(path.read_text())
    except Exception: return default if default is not None else {}

def _save(path, obj):
    tmp = str(path) + ".tmp"
    Path(tmp).write_text(json.dumps(obj, indent=2, ensure_ascii=False))
    os.replace(tmp, path)

def schemes():
    c = _load(CFG, None) or {}
    merged = dict(DEFAULT_SCHEMES); merged.update(c)
    return merged

def add_scheme(name, threshold, signers="any"):
    c = schemes(); c[name] = {"threshold": int(threshold), "signers": signers}
    _save(CFG, c); return True, "додано"

def pick_scheme(amount_bnb):
    """Автоматично вибирає схему за сумою."""
    s = schemes()
    if amount_bnb < 1:     return "small"
    if amount_bnb < 10:    return "medium"
    if amount_bnb < 100:   return "large"
    return "critical"

def start_session(cid, scheme, contract_data=None):
    """Створює сесію мультипідпису для CID."""
    s = schemes().get(scheme)
    if not s: return False, f"немає схеми {scheme}", None
    sid = "MS-" + time.strftime("%Y%m%d%H%M%S") + "-" + secrets.token_hex(3)
    entry = {
        "sid": sid, "cid": cid, "scheme": scheme,
        "threshold": s["threshold"],
        "signers_rule": s.get("signers","any"),
        "created": _now(),
        "status": "collecting",
        "signatures": [],
        "contract": contract_data or {},
    }
    with open(SESSIONS, "a") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    return True, "створено", sid

def _last_session(sid):
    if not SESSIONS.exists(): return None
    best = None
    for line in SESSIONS.read_text().splitlines():
        try: e = json.loads(line)
        except Exception: continue
        if e["sid"] == sid: best = e
    return best

def _append_session(s):
    with open(SESSIONS, "a") as f:
        f.write(json.dumps(s, ensure_ascii=False) + "\n")

def get_session(sid):
    return _last_session(sid)

def sessions(status=None):
    if not SESSIONS.exists(): return []
    by = {}
    for line in SESSIONS.read_text().splitlines():
        try: e = json.loads(line)
        except Exception: continue
        by[e["sid"]] = e
    out = list(by.values())
    if status: out = [e for e in out if e.get("status")==status]
    return sorted(out, key=lambda x: x["created"], reverse=True)

def sign_message(sid, signer):
    s = _last_session(sid)
    if not s: return None
    return (f"CYBRA Multi-Sig Approval\n"
            f"Session: {sid}\n"
            f"CID: {s['cid']}\n"
            f"Scheme: {s['scheme']} ({s['threshold']} of N)\n"
            f"Signer: {signer.lower()}\n"
            f"Timestamp: {_now()}")

def add_signature(sid, signer, signature, message=None):
    """Додає підпис у сесію. Перевіряє чи не дублікат."""
    s = _last_session(sid)
    if not s: return False, "сесія не знайдена"
    if s["status"] != "collecting":
        return False, f"сесія {s['status']}"
    signer = signer.lower()
    for sig in s["signatures"]:
        if sig["signer"] == signer:
            return False, f"{signer[:10]}… вже підписав"
    # верифікація підпису
    try:
        from eth_account import Account
        from eth_account.messages import encode_defunct
        msg = message or sign_message(sid, signer)
        rec = Account.recover_message(encode_defunct(text=msg),
                                      signature=signature)
        if rec.lower() != signer:
            return False, f"ecrecover не співпадає: {rec[:10]}…"
    except ImportError:
        pass
    except Exception as e:
        return False, f"підпис невалідний: {e}"

    entry = {"signer": signer, "signature": signature,
             "message": message or sign_message(sid, signer),
             "at": _now()}
    s["signatures"].append(entry)

    # перевірка кворуму
    got = len(s["signatures"])
    if got >= s["threshold"]:
        s["status"] = "complete"
        s["completed"] = _now()
    _append_session(s)
    return True, f"{got}/{s['threshold']} підписів"

def finalize(sid):
    """Пише фінальний .sig з усіма підписами."""
    s = _last_session(sid)
    if not s: return False, "не знайдено"
    if s["status"] != "complete":
        return False, f"ще не завершено: {len(s['signatures'])}/{s['threshold']}"
    # шукаємо базовий .sig щоб узяти message
    cid = s["cid"]
    base = H / f"modules/module_19_contract_tui_menu/evidence/{cid}_buyer.sig"
    if base.exists():
        try:
            d = json.loads(base.read_text())
        except Exception:
            d = {"cid": cid, "message": f"CYBRA Multi-Sig {cid}"}
    else:
        d = {"cid": cid, "message": f"CYBRA Multi-Sig {cid}"}

    # розширюємо .sig
    d["multisig"] = {
        "sid": sid, "scheme": s["scheme"], "threshold": s["threshold"],
        "signatures": s["signatures"], "completed": s.get("completed"),
    }
    out = H / f"modules/module_19_contract_tui_menu/evidence/{cid}_multisig.sig"
    out.write_text(json.dumps(d, indent=2, ensure_ascii=False))
    return True, str(out)

def verify_multisig(path):
    """Перевіряє повний мультипідпис."""
    try:
        d = json.loads(Path(path).read_text())
    except Exception as e:
        return False, f"не JSON: {e}", {}
    ms = d.get("multisig")
    if not ms:
        return False, "немає multisig-блоку", {}
    try:
        from eth_account import Account
        from eth_account.messages import encode_defunct
    except ImportError:
        return False, "eth_account відсутній", {}

    ok_count = 0
    bad = []
    for sig in ms["signatures"]:
        try:
            rec = Account.recover_message(
                encode_defunct(text=sig["message"]),
                signature=sig["signature"])
            if rec.lower() == sig["signer"].lower():
                ok_count += 1
            else:
                bad.append(f"{sig['signer'][:10]}… (rec {rec[:10]}…)")
        except Exception as e:
            bad.append(f"{sig['signer'][:10]}… ({e})")

    met = ok_count >= ms["threshold"]
    return met, f"{ok_count}/{ms['threshold']} OK" + (f" · проблемні: {bad}" if bad else ""), {
        "ok_count": ok_count, "threshold": ms["threshold"],
        "signed": [s["signer"] for s in ms["signatures"]],
    }

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "list":
        for s in sessions():
            print(f"  {s['sid']}  {s['cid'][:22]:24s}  {s['scheme']:10s}  "
                  f"{len(s['signatures'])}/{s['threshold']}  [{s['status']}]")
    elif cmd == "show":
        print(json.dumps(get_session(sys.argv[2]), indent=2, ensure_ascii=False))
    elif cmd == "start":
        ok, msg, sid = start_session(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "medium")
        print(("✓ " if ok else "✗ ") + msg + (f" {sid}" if sid else ""))
    elif cmd == "verify":
        met, msg, info = verify_multisig(sys.argv[2])
        print(("✓ " if met else "✗ ") + msg)
    elif cmd == "finalize":
        ok, msg = finalize(sys.argv[2])
        print(("✓ " if ok else "✗ ") + msg)
    elif cmd == "schemes":
        print(json.dumps(schemes(), indent=2, ensure_ascii=False))
