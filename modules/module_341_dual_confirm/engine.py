#!/usr/bin/env python3
"""Dual Confirmation — подвійне підтвердження контракту.

  Підтвердження #1 (ORDER)  — підпис покупця при замовленні (вже зроблено)
  Підтвердження #2 (RECEIPT) — підпис покупця через 3 дні після отримання

  Для Комфі: тільки #1 потрібне (їх рахунок = їх підтвердження)
  Для тебе: обидва — захист від недобросовісного продавця

  Gate: тільки при health 100%.
"""
import base64, json, os, sys, time, hashlib
from pathlib import Path

H = Path.home() / "CYBRA"
M = H / "modules"
D = Path(__file__).resolve().parent
E = M / "module_19_contract_tui_menu/evidence"
DATA = D / "data"

# ─── HEALTH GATE ───
def check_health():
    try:
        sys.path.insert(0, str(M/"module_121_parlament"))
        import health
        h = health.health_all()
        return h["overall"] >= 100, h
    except Exception as e:
        return False, {"error": str(e)}

def require_100():
    ok, h = check_health()
    if not ok: raise RuntimeError(f"Система не 100%: {h.get('overall','?')}%")

# ─── СТРУКТУРА ───
def _now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
def _now_unix(): return int(time.time())

def _file(cid): return DATA / f"{cid}_dual.json"

def load(cid):
    f = _file(cid)
    if not f.exists(): return None
    try: return json.loads(f.read_text())
    except Exception: return None

def save(cid, d):
    d["updated_at"] = _now()
    _file(cid).write_text(json.dumps(d, indent=2, ensure_ascii=False))

# ─── СТВОРЕННЯ ───
def create(cid, receipt_window_days=3):
    """Ініціалізує dual-confirm для контракту."""
    inv = None
    for p in [E/f"{cid}.json", E/f"{cid}_buyer.sig"]:
        if p.exists():
            try: inv = json.loads(p.read_text()); break
            except Exception: pass
    if not inv:
        return False, f"не знайдено контракт {cid}"

    d = {
        "cid": cid,
        "created": _now(),
        "confirmations": {
            "order": {
                "status": "pending",
                "label": "1. Підтвердження замовлення (ти + Комфі)",
                "description": "Твій підпис контракту + їхній рахунок",
                "signed_at": None,
                "signature": None,
                "party": "buyer",
            },
            "receipt": {
                "status": "pending",
                "label": "2. Підтвердження отримання товару (тільки ти)",
                "description": f"Через {receipt_window_days} дні після доставки",
                "window_days": receipt_window_days,
                "delivered_at": None,
                "expires_at": None,
                "signed_at": None,
                "signature": None,
                "party": "buyer",
            },
        },
        "comfy_side": {
            "invoice_no": inv.get("invoice", {}).get("no"),
            "invoice_date": inv.get("invoice", {}).get("date"),
            "amount_uah": inv.get("total_uah"),
            "status": "invoice_received",  # invoice_received → paid → shipped → delivered
        },
        "state": "awaiting_order_confirm",
        "history": [],
    }

    # Якщо вже є .sig — order вже підписано
    sig_path = E / f"{cid}_buyer.sig"
    if sig_path.exists():
        try:
            sig = json.loads(sig_path.read_text())
            d["confirmations"]["order"]["status"] = "signed"
            d["confirmations"]["order"]["signed_at"] = sig.get("signed_at") or _now()
            d["confirmations"]["order"]["signature"] = sig.get("signature")
            d["state"] = "awaiting_payment"
        except Exception: pass

    save(cid, d)
    return True, d

# ─── ПІДПИС #2 (отримання) ───
def mark_delivered(cid):
    """Комфі каже що доставили — починається 3-денне вікно."""
    d = load(cid) or create(cid)[1]
    if not d: return False, "немає"
    now = _now_unix()
    window = d["confirmations"]["receipt"]["window_days"]
    d["confirmations"]["receipt"]["delivered_at"] = _now()
    d["confirmations"]["receipt"]["expires_at"] = now + window * 86400
    d["confirmations"]["receipt"]["status"] = "awaiting_buyer"
    d["comfy_side"]["status"] = "delivered"
    d["state"] = "awaiting_receipt"
    save(cid, d)
    return True, d

def sign_receipt(cid, message, signature):
    """Покупець підписує отримання (MetaMask)."""
    d = load(cid)
    if not d: return False, "немає dual"
    r = d["confirmations"]["receipt"]
    if r["status"] == "signed": return False, "вже підписано"
    # перевірка вікна
    if r.get("expires_at") and _now_unix() > r["expires_at"]:
        r["status"] = "expired"
        save(cid, d)
        return False, "вікно минуло"

    # ecrecover
    try:
        sys.path.insert(0, str(M/"module_108_metamask_sign"))
        from eth_account import Account
        from eth_account.messages import encode_defunct
        rec = Account.recover_message(encode_defunct(text=message), signature=signature)
    except Exception as e:
        return False, f"verify: {e}"

    r["status"] = "signed"
    r["signed_at"] = _now()
    r["signature"] = signature
    r["message"] = message
    r["recovered"] = rec
    d["state"] = "complete"
    d["comfy_side"]["status"] = "confirmed"
    save(cid, d)
    return True, d

def time_left(cid):
    """Скільки часу лишилось до кінця вікна."""
    d = load(cid)
    if not d: return None
    r = d["confirmations"]["receipt"]
    if not r.get("expires_at"): return None
    left = r["expires_at"] - _now_unix()
    if left <= 0: return {"expired": True, "seconds": 0}
    days = left // 86400
    hours = (left % 86400) // 3600
    return {"expired": False, "seconds": left, "days": days, "hours": hours}

# ─── URL для Комфі (посилання на оплату) ───
def payment_url(cid, base_url):
    """Генерує посилання для Комфі — підтвердження оплати."""
    d = load(cid)
    if not d: return None
    payload = {
        "cid": cid,
        "invoice": d["comfy_side"]["invoice_no"],
        "amount_uah": d["comfy_side"]["amount_uah"],
        "buyer_signed": d["confirmations"]["order"]["status"] == "signed",
        "signature": d["confirmations"]["order"].get("signature", "")[:20] + "…",
        "at": _now(),
    }
    b64 = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().rstrip("=")
    return f"{base_url}/confirm?t={b64}"

# ─── CLI ───
if __name__ == "__main__":
    import sys
    G='\033[32m'; R='\033[31m'; Y='\033[33m'; B='\033[36m'; D='\033[2m'; BOLD='\033[1m'; N='\033[0m'
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "check":
        ok, h = check_health()
        col = G if ok else R
        print(f"\n  Health: {col}{h.get('overall','?')}%{N}")
        sys.exit(0 if ok else 1)

    elif cmd == "create":
        cid = sys.argv[2]
        ok, d = create(cid)
        if ok:
            print(f"  {G}✓{N} dual-confirm створено: {cid}")
            print(f"  Стан: {d['state']}")
        else:
            print(f"  {R}✗{N} {d}"); sys.exit(1)

    elif cmd == "status":
        cid = sys.argv[2] if len(sys.argv) > 2 else None
        if not cid:
            # всі контракти
            files = sorted(DATA.glob("*_dual.json"))
            if not files: print("  (порожньо)"); sys.exit(0)
            for f in files:
                d = json.loads(f.read_text())
                c = d["confirmations"]
                o = "✓" if c["order"]["status"]=="signed" else "·"
                r = "✓" if c["receipt"]["status"]=="signed" else ("…" if c["receipt"]["status"]=="awaiting_buyer" else "·")
                print(f"  {o} {r}  {d['cid'][:26]:28s}  {d['state']}")
            sys.exit(0)
        d = load(cid)
        if not d:
            print(f"  {R}✗{N} немає dual-confirm для {cid}"); sys.exit(1)
        print(f"\n  {B}{BOLD}Dual Confirmation: {cid}{N}\n")
        c = d["confirmations"]
        for key in ["order", "receipt"]:
            e = c[key]
            status = e["status"]
            col = G if status == "signed" else (Y if status in ("awaiting_buyer","pending") else R)
            print(f"  {col}[{status:14s}]{N} {e['label']}")
            if key == "receipt" and e.get("expires_at"):
                left = time_left(cid)
                if left and not left.get("expired"):
                    print(f"     {D}Залишилось: {left['days']}д {left['hours']}г{N}")
                elif left and left.get("expired"):
                    print(f"     {R}ПРОСТРОЧЕНО{N}")
        print(f"\n  {B}Комфі:{N} {d['comfy_side']['status']}")
        print(f"  {B}Стан:{N} {d['state']}")

    elif cmd == "delivered":
        cid = sys.argv[2]
        ok, d = mark_delivered(cid)
        print(f"  {'✓' if ok else '✗'} {d if isinstance(d,str) else 'window started'}")

    elif cmd == "receipt":
        # sign receipt
        cid = sys.argv[2]
        msg = sys.argv[3] if len(sys.argv) > 3 else f"CYBRA Receipt Confirm {cid} {_now()}"
        sig = sys.argv[4] if len(sys.argv) > 4 else "manual"
        ok, d = sign_receipt(cid, msg, sig)
        print(f"  {'✓' if ok else '✗'} {d if isinstance(d,str) else 'signed'}")

    elif cmd == "json":
        cid = sys.argv[2]
        d = load(cid)
        print(json.dumps(d, indent=2, ensure_ascii=False) if d else "{}")
