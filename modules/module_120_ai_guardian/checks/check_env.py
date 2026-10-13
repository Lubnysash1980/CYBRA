"""Перевірка системного середовища."""
import shutil, subprocess, sys, json, os

def run():
    out = []
    for tool, lvl in [("python3","critical"),("curl","critical"),
                      ("cloudflared","warn"),("git","warn"),
                      ("qrencode","warn"),("termux-notification","warn")]:
        p = shutil.which(tool)
        out.append({
            "id": f"env.{tool}",
            "name": f"Утиліта {tool}",
            "status": "ok" if p else ("fail" if lvl=="critical" else "warn"),
            "detail": p or "не знайдено",
            "fix_hint": f"pkg install -y {tool}" if not p else ""
        })

    # Python-модулі
    for mod, lvl in [("qrcode","warn"),("nacl","warn"),("eth_account","warn")]:
        try:
            __import__(mod)
            out.append({"id":f"py.{mod}","name":f"Python · {mod}",
                        "status":"ok","detail":"встановлено","fix_hint":""})
        except ImportError:
            out.append({"id":f"py.{mod}","name":f"Python · {mod}",
                        "status":lvl,"detail":"відсутній",
                        "fix_hint":f"pip install {mod if mod!='eth_account' else 'eth-account'}"})
    return out
