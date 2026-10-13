import json, hmac, hashlib, time, os, secrets, base64
from pathlib import Path

ROOT = Path(__file__).resolve().parent
KEY     = ROOT / "keys" / "hmac.key"
ED_PRIV = ROOT / "keys" / "ed25519.priv"
ED_PUB  = ROOT / "keys" / "ed25519.pub"
NONCES  = ROOT / "nonces.json"
ANCHORS = ROOT / "anchors.jsonl"

LEVELS = {
    1: "URL + CID (формат)",
    2: "URL + CID + перевірка формату/довжини",
    3: "+ HMAC-SHA256(cid|url)",
    4: "+ expiry (TTL)",
    5: "+ одноразовий nonce",
    6: "+ Ed25519 підпис payload",
    7: "+ on-chain anchor (BSC)",
    8: "+ парламентські підписи (N-of-M)",
    9: "+ multi-sig повний (2-of-3, 3-of-5)",
}

def load_key():
    KEY.parent.mkdir(parents=True, exist_ok=True)
    if not KEY.exists():
        KEY.write_bytes(secrets.token_bytes(32)); os.chmod(KEY, 0o600)
    return KEY.read_bytes()

def load_ed():
    try:
        from nacl.signing import SigningKey
    except ImportError:
        return None
    ED_PRIV.parent.mkdir(parents=True, exist_ok=True)
    if not ED_PRIV.exists():
        sk = SigningKey.generate()
        ED_PRIV.write_bytes(bytes(sk)); os.chmod(ED_PRIV, 0o600)
        ED_PUB.write_bytes(bytes(sk.verify_key))
    return SigningKey(ED_PRIV.read_bytes())

def hmac_hex(b): return hmac.new(load_key(), b, hashlib.sha256).hexdigest()
def canon(d):    return json.dumps(d, sort_keys=True, separators=(",", ":")).encode()

def load_nonces():
    if not NONCES.exists(): return {}
    try: return json.loads(NONCES.read_text())
    except: return {}
def save_nonces(d): NONCES.write_text(json.dumps(d, indent=2))

def generate(level: int, url: str, cid: str, ttl: int = 900) -> dict:
    now = int(time.time())
    p = {"v": level, "u": url, "c": cid, "t": now}
    if not (cid.startswith("C-INV-") and len(cid) >= 20):
        raise ValueError("bad CID format")

    if level == 1: pass
    elif level == 2: pass
    elif level == 3:
        p["h"] = hmac_hex(canon({"c": cid, "u": url}))
    elif level == 4:
        p["exp"] = now + ttl
        p["h"] = hmac_hex(canon({"c": cid, "u": url, "exp": p["exp"]}))
    elif level == 5:
        n = secrets.token_hex(16)
        p["n"] = n; p["exp"] = now + ttl
        p["h"] = hmac_hex(canon({"c": cid, "u": url, "exp": p["exp"], "n": n}))
        reg = load_nonces()
        reg[n] = {"cid": cid, "exp": p["exp"], "used": False, "created": now}
        save_nonces(reg)
    elif level == 6:
        sk = load_ed()
        if not sk: raise RuntimeError("pip install pynacl")
        msg = canon({"c": cid, "u": url, "t": now})
        sig = sk.sign(msg).signature
        p["sig"] = base64.b64encode(sig).decode()
        p["pub"] = base64.b64encode(bytes(sk.verify_key)).decode()
    elif level == 7:
        sk = load_ed()
        if not sk: raise RuntimeError("pip install pynacl")
        ah = hashlib.sha256(canon({"c": cid, "u": url, "t": now})).hexdigest()
        p["ah"] = ah
        sig = sk.sign(bytes.fromhex(ah)).signature
        p["sig"] = base64.b64encode(sig).decode()
        p["pub"] = base64.b64encode(bytes(sk.verify_key)).decode()
        with ANCHORS.open("a") as f:
            f.write(json.dumps({"t": now, "cid": cid, "hash": ah, "anchored": False}) + "\n")
    elif level == 8:
        # парламентський QR: містить PID + список approver-адрес
        # самі підписи верифікуються через 121
        try:
            sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
            import parliament_check
            info = parliament_check.get_approvers(cid)
        except Exception:
            info = {"approvers": [], "quorum_met": False}
        p["approvers"] = info.get("approvers", [])
        p["quorum_met"] = info.get("quorum_met", False)
        p["pid"] = info.get("pid")
        p["h"] = hmac_hex(canon({"c": cid, "u": url, "approvers": p["approvers"],
                                 "pid": p.get("pid","")}))
    elif level == 9:
        # Multi-sig QR: містить sid + список підписів з 123
        try:
            sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                            "..", "module_123_multisig"))
            import multisig as MS
            sessions = [s for s in MS.sessions() if s["cid"] == cid]
            sess = sessions[0] if sessions else None
        except Exception:
            sess = None
        if sess:
            p["ms_sid"] = sess["sid"]
            p["ms_threshold"] = sess["threshold"]
            p["ms_sigs"] = len(sess["signatures"])
            p["ms_signed"] = sess["status"] == "complete"
        p["h"] = hmac_hex(canon({"c": cid, "u": url, "ms_sid": p.get("ms_sid","")}))
    else:
        raise ValueError(f"unknown level {level}")
    return p

def verify(payload: dict, consume_nonce: bool = True) -> dict:
    lv = payload.get("v")
    if lv not in LEVELS:
        return {"ok": False, "level": lv, "reason": "unknown level"}
    now = int(time.time())
    r = {"ok": True, "level": lv, "cid": payload.get("c"), "notes": []}

    if lv >= 2:
        c = payload.get("c", "")
        if not (c.startswith("C-INV-") and len(c) >= 20):
            return {"ok": False, "level": lv, "reason": "bad CID format"}
        r["notes"].append("CID format ok")

    if lv == 3:
        exp = hmac_hex(canon({"c": payload["c"], "u": payload["u"]}))
        if not hmac.compare_digest(exp, payload.get("h","")):
            return {"ok": False, "level": lv, "reason": "HMAC mismatch"}
        r["notes"].append("HMAC ok")

    if lv == 4:
        if now > payload.get("exp", 0):
            return {"ok": False, "level": lv, "reason": "expired"}
        exp = hmac_hex(canon({"c": payload["c"], "u": payload["u"], "exp": payload["exp"]}))
        if not hmac.compare_digest(exp, payload.get("h","")):
            return {"ok": False, "level": lv, "reason": "HMAC mismatch"}
        r["notes"].append(f"HMAC ok, TTL {payload['exp']-now}s")

    if lv == 5:
        if now > payload.get("exp", 0):
            return {"ok": False, "level": lv, "reason": "expired"}
        exp = hmac_hex(canon({"c": payload["c"], "u": payload["u"],
                              "exp": payload["exp"], "n": payload["n"]}))
        if not hmac.compare_digest(exp, payload.get("h","")):
            return {"ok": False, "level": lv, "reason": "HMAC mismatch"}
        reg = load_nonces()
        e = reg.get(payload["n"])
        if not e: return {"ok": False, "level": lv, "reason": "nonce unknown"}
        if e.get("used"): return {"ok": False, "level": lv, "reason": "nonce already used"}
        if e.get("cid") != payload["c"]:
            return {"ok": False, "level": lv, "reason": "nonce↔CID mismatch"}
        if consume_nonce:
            e["used"] = True; e["used_at"] = now
            save_nonces(reg)
            r["notes"].append("nonce consumed")
        else:
            r["notes"].append("nonce valid (не спожито)")

    if lv in (6, 7):
        try:
            from nacl.signing import VerifyKey
            vk = VerifyKey(base64.b64decode(payload["pub"]))
            if lv == 6:
                msg = canon({"c": payload["c"], "u": payload["u"], "t": payload["t"]})
                vk.verify(msg, base64.b64decode(payload["sig"]))
                r["notes"].append("ed25519 ok")
            else:
                vk.verify(bytes.fromhex(payload["ah"]), base64.b64decode(payload["sig"]))
                r["notes"].append("ed25519 ok")
        except Exception as e:
            return {"ok": False, "level": lv, "reason": f"ed25519 fail: {e}"}

    if lv == 8:
        # перевіряємо що парламент схвалив пропозицію для цього CID
        try:
            sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
            import parliament_check
            info = parliament_check.get_approvers(payload["c"])
        except Exception as e:
            return {"ok": False, "level": lv, "reason": f"parliament check: {e}"}
        if not info.get("quorum_met"):
            return {"ok": False, "level": lv,
                    "reason": "парламент не схвалив цей контракт"}
        exp_h = hmac_hex(canon({"c": payload["c"], "u": payload["u"],
                                "approvers": payload.get("approvers", []),
                                "pid": payload.get("pid","")}))
        if not hmac.compare_digest(exp_h, payload.get("h","")):
            return {"ok": False, "level": lv, "reason": "HMAC mismatch"}
        r["notes"].append(f"парламент OK: {len(info['approvers'])} підписів")
        r["notes"].append(f"PID: {info.get('pid')}")

    if lv == 9:
        sid = payload.get("ms_sid")
        if not sid:
            return {"ok": False, "level": lv, "reason": "немає MS-сесії"}
        try:
            sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                            "..", "module_123_multisig"))
            import multisig as MS
            s = MS.get_session(sid)
            if not s: return {"ok": False, "level": lv, "reason": "сесія не знайдена"}
            if s["status"] != "complete":
                return {"ok": False, "level": lv,
                        "reason": f"не завершено: {len(s['signatures'])}/{s['threshold']}"}
            r["notes"].append(f"multi-sig OK: {len(s['signatures'])}/{s['threshold']}")
            r["notes"].append(f"SID: {sid}")
        except Exception as e:
            return {"ok": False, "level": lv, "reason": str(e)}

    if lv == 7:
        ah = payload.get("ah")
        found = None
        try:
            for line in ANCHORS.read_text().splitlines():
                e = json.loads(line)
                if e.get("hash") == ah and e.get("cid") == payload["c"]:
                    found = e; break
        except Exception: pass
        if found:
            r["notes"].append("anchor: " + ("on-chain" if found.get("anchored") else "pending"))
        else:
            r["notes"].append("anchor запис відсутній")

    return r

def anchor_tx(cid: str, tx_hash: str, net: str = "bsc"):
    """Позначає anchor як on-chain після публікації TX."""
    lines = []
    updated = 0
    try:
        for line in ANCHORS.read_text().splitlines():
            e = json.loads(line)
            if e.get("cid") == cid and not e.get("anchored"):
                e["anchored"] = True; e["tx"] = tx_hash; e["net"] = net
                updated += 1
            lines.append(json.dumps(e))
        ANCHORS.write_text("\n".join(lines) + "\n")
    except Exception as ex:
        return {"ok": False, "reason": str(ex)}
    return {"ok": True, "updated": updated}
