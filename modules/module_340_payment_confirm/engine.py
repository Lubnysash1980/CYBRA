#!/usr/bin/env python3
"""Payment Confirmation — NBU QR v002 + підтвердження для контрагента.
Працює ТІЛЬКИ при 100% health системи."""
import base64, json, os, sys, time, urllib.parse
from pathlib import Path

H = Path.home() / "CYBRA"
M = H / "modules"
D = Path(__file__).resolve().parent
E = M / "module_19_contract_tui_menu/evidence"

# ─── 100% GATE ───
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
    if not ok:
        raise RuntimeError(f"Система не 100%: {h.get('overall', '?')}%")
    return True

# ─── NBU QR v002 ───
def build_nbu_qr(recipient, iban, amount, edrpou, purpose, currency="UAH"):
    """Генерує NBU QR v002 URL.
    Формат: https://qr.bank.gov.ua/<base64url>"""
    # Сума без зайвих нулів: 137475.00 → 137475
    amt = f"{amount:.2f}".rstrip("0").rstrip(".") if amount else ""
    amount_str = f"{currency}{amt}"

    # Поля у порядку НБУ v002
    lines = [
        "BCD",
        "002",
        "2",
        "UCT",
        "",                # BIC (не обов'язково для UCT)
        recipient[:140],   # Найменування отримувача
        iban,              # IBAN
        amount_str,        # Сума
        edrpou,            # ЄДРПОУ
        "",                # Ціль (не використовується)
        "",                # Reference
        purpose[:420],     # Призначення платежу
        "",                # Display (не обов'язково)
    ]
    payload = "\n".join(lines)
    b64 = base64.urlsafe_b64encode(payload.encode("utf-8")).decode("ascii").rstrip("=")
    return f"https://qr.bank.gov.ua/{b64}", payload

# ─── ГЕНЕРАЦІЯ QR PNG ───
def make_qr_png(data, out_path):
    try:
        import qrcode
        qr = qrcode.QRCode(border=2, box_size=10)
        qr.add_data(data)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")
        img.save(out_path)
        return True, str(out_path)
    except ImportError:
        return False, "pip install qrcode pillow"

def make_qr_ascii(data):
    try:
        import qrcode
        qr = qrcode.QRCode(border=1)
        qr.add_data(data); qr.make(fit=True)
        m = qr.get_matrix()
        return "\n".join("  " + "".join("██" if c else "  " for c in row) for row in m)
    except ImportError: return None

# ─── ЗАВАНТАЖЕННЯ INVOICE ───
def load_invoice(cid):
    for p in [E/f"{cid}.json", E/f"{cid}_buyer.sig"]:
        if p.exists():
            try: return json.loads(p.read_text())
            except Exception: pass
    return None

# ─── STORE ───
def save_payment(cid, data):
    p = D / "data" / f"{cid}_confirm.json"
    data["generated_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    p.write_text(json.dumps(data, indent=2, ensure_ascii=False))
    return p

# ─── CLI ───
if __name__ == "__main__":
    import sys
    G='\033[32m'; R='\033[31m'; Y='\033[33m'; B='\033[36m'; BOLD='\033[1m'; N='\033[0m'
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"

    if cmd == "check":
        ok, h = check_health()
        col = G if ok else R
        print(f"\n  Health: {col}{h.get('overall','?')}%{N}")
        print(f"  Парламент: {h.get('parliament',{}).get('score','?')}%")
        print(f"  Система:   {h.get('system',{}).get('score','?')}%")
        print(f"\n  {col}{'✓ Можна генерувати' if ok else '✗ Заблоковано (треба 100%)'}{N}\n")
        sys.exit(0 if ok else 1)

    elif cmd == "generate":
        cid = sys.argv[2] if len(sys.argv) > 2 else None
        if not cid:
            print("usage: engine.py generate <cid>"); sys.exit(1)
        # gate
        try:
            require_100()
        except RuntimeError as e:
            print(f"  {R}✗{N} {e}"); sys.exit(1)
        inv = load_invoice(cid)
        if not inv:
            print(f"  {R}✗{N} контракт не знайдено: {cid}"); sys.exit(1)
        # дані
        inv_info = inv.get("invoice", {})
        supplier = inv_info.get("supplier", {})
        recipient = supplier.get("full_name") or supplier.get("name") or "?"
        iban = supplier.get("iban", "?")
        edrpou = supplier.get("edrpou", "?")
        amount = inv.get("total_uah", 0)
        purpose = f"Оплата за рахунком №{inv_info.get('no','?')} від {inv_info.get('date','?')}"

        # генерація
        url, payload = build_nbu_qr(recipient, iban, amount, edrpou, purpose)
        png_path = D / "data" / f"{cid}_nbu_qr.png"
        ok_png, msg_png = make_qr_png(url, png_path)

        print(f"\n  {B}{BOLD}NBU QR v002{N}")
        print(f"  Отримувач: {recipient[:60]}")
        print(f"  IBAN:      {iban}")
        print(f"  ЄДРПОУ:    {edrpou}")
        print(f"  Сума:      {amount:,.2f} UAH")
        print(f"  Призначення: {purpose}")
        print(f"\n  URL: {url}")
        if ok_png:
            print(f"  PNG: {png_path}")
        # ASCII в термінал
        print()
        ascii_qr = make_qr_ascii(url)
        if ascii_qr:
            print(ascii_qr)
        # зберегти
        save_payment(cid, {
            "cid": cid, "nbu_url": url, "payload": payload,
            "recipient": recipient, "iban": iban, "edrpou": edrpou,
            "amount_uah": amount, "purpose": purpose,
            "qr_png": str(png_path) if ok_png else None,
        })
        print(f"\n  {G}✓ збережено у data/{cid}_confirm.json{N}\n")

    elif cmd == "json":
        cid = sys.argv[2]
        p = D / "data" / f"{cid}_confirm.json"
        if p.exists(): print(p.read_text())
        else: print(f"  не знайдено: {cid}")
