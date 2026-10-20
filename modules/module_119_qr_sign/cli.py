#!/usr/bin/env python3
import sys, json, argparse, base64, io
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import levels

def qr_terminal(payload_str: str):
    # спроба через qrencode
    import subprocess, shutil
    if shutil.which("qrencode"):
        try:
            r = subprocess.run(["qrencode","-t","ANSIUTF8","-o","-", payload_str],
                               capture_output=True, text=True, timeout=10)
            if r.returncode == 0:
                print(r.stdout); return True
        except Exception: pass
    # fallback — python qrcode
    try:
        import qrcode
        qr = qrcode.QRCode(border=1)
        qr.add_data(payload_str); qr.make(fit=True)
        m = qr.get_matrix()
        # ASCII
        for row in m:
            print("  " + "".join("██" if c else "  " for c in row))
        return True
    except ImportError:
        return False

def qr_png(payload_str: str, out: str):
    try:
        import qrcode
        qr = qrcode.QRCode(border=2, box_size=8)
        qr.add_data(payload_str); qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")
        img.save(out); return True
    except ImportError:
        return False

def cmd_gen(a):
    p = levels.generate(a.level, a.url, a.cid, a.ttl)
    p["buyer"] = "Грабовський Олександр Миколайович"
    p["seller"] = "ТОВ 'КОМФІ ТРЕЙД'"
    p["sum_uah"] = 137475.0
    p["sum_bnb"] = 0.8064114
    payload = json.dumps(p, separators=(",", ":"))
    b64 = base64.urlsafe_b64encode(payload.encode()).decode().rstrip("=")
    # QR містить URL з вбудованим payload — так MetaMask одразу відкриє сторінку
    full = f"{a.url}?p={b64}"

    print(f"  Рівень:  {a.level} — {levels.LEVELS[a.level]}")
    print(f"  CID:     {a.cid}")
    print(f"  URL:     {a.url}")
    print(f"  Payload: {payload}")
    print()

    if a.format == "json":
        print(json.dumps({"level": a.level, "url": full, "payload": p}, indent=2))
        return
    if a.format in ("qr","png"):
        png = a.out or f"/data/data/com.termux/files/home/CYBRA/public/sign/qr_L{a.level}.png"
        if qr_png(full, png):
            print(f"  PNG: {png}")
        else:
            print("  ! pip install qrcode[pil] для PNG")
    # завжди ASCII в термінал
    if not qr_terminal(full):
        print("  ! встанови qrencode: pkg install qrencode")
        print(f"  Deep-link: {full}")

def cmd_verify(a):
    data = None
    if a.file:
        data = Path(a.file).read_text()
    elif a.payload:
        data = a.payload
    else:
        data = sys.stdin.read()

    data = data.strip()
    # підтримка base64
    try:
        if not data.startswith("{"):
            pad = "=" * (-len(data) % 4)
            data = base64.urlsafe_b64decode(data + pad).decode()
    except Exception: pass

    try:
        p = json.loads(data)
    except Exception as e:
        print(f"  ✗ не JSON: {e}"); sys.exit(1)

    r = levels.verify(p, consume_nonce=a.consume)
    color = "\033[32m" if r["ok"] else "\033[31m"
    reset = "\033[0m"
    print(f"  {color}{'✓ OK' if r['ok'] else '✗ FAIL'}{reset} · level={r.get('level')}")
    print(f"  CID: {r.get('cid')}")
    if r.get("reason"): print(f"  Reason: {r['reason']}")
    for n in r.get("notes", []): print(f"  · {n}")
    sys.exit(0 if r["ok"] else 2)

def cmd_anchor(a):
    r = levels.anchor_tx(a.cid, a.tx, a.net)
    print(json.dumps(r))

def cmd_list(a):
    print("Рівні верифікації:")
    for k, v in sorted(levels.LEVELS.items()):
        print(f"  {k}. {v}")

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    g = sub.add_parser("gen")
    g.add_argument("--level", type=int, required=True)
    g.add_argument("--url", required=True)
    g.add_argument("--cid", required=True)
    g.add_argument("--ttl", type=int, default=900)
    g.add_argument("--format", choices=["qr","png","json"], default="qr")
    g.add_argument("--out")
    g.set_defaults(fn=cmd_gen)

    v = sub.add_parser("verify")
    v.add_argument("--file")
    v.add_argument("--payload")
    v.add_argument("--consume", action="store_true", default=True)
    v.set_defaults(fn=cmd_verify)

    an = sub.add_parser("anchor")
    an.add_argument("--cid", required=True)
    an.add_argument("--tx", required=True)
    an.add_argument("--net", default="bsc")
    an.set_defaults(fn=cmd_anchor)

    l = sub.add_parser("levels"); l.set_defaults(fn=cmd_list)

    a = ap.parse_args()
    a.fn(a)
