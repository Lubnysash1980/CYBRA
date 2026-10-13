"""Перевірка цілісності останніх підписів (ecrecover)."""
import json, os
from pathlib import Path

H = Path.home() / "CYBRA"
E = H / "modules/module_19_contract_tui_menu/evidence"

def run():
    sigs = sorted(E.glob("*.sig"), key=lambda p: p.stat().st_mtime, reverse=True)[:10]
    if not sigs:
        return [{"id":"sigs","name":"Підписи","status":"ok",
                 "detail":"немає підписів (нормально для нового)", "fix_hint":""}]
    try:
        from eth_account import Account
        from eth_account.messages import encode_defunct
    except ImportError:
        return [{"id":"sigs","name":"Перевірка підписів","status":"warn",
                 "detail":"eth_account відсутній","fix_hint":"pip install eth-account"}]

    bad = []
    for f in sigs:
        try:
            d = json.loads(f.read_text())
            msg = encode_defunct(text=d["message"])
            rec = Account.recover_message(msg, signature=d["signature"])
            if rec.lower() != d["address"].lower():
                bad.append(f.name)
        except Exception as e:
            bad.append(f"{f.name}: {e}")
    if bad:
        return [{"id":"sigs","name":"Перевірка підписів","status":"critical",
                 "detail":f"{len(bad)} пошкоджених: {bad[:3]}","fix_hint":""}]
    return [{"id":"sigs","name":"Перевірка підписів","status":"ok",
             "detail":f"{len(sigs)} валідних","fix_hint":""}]
