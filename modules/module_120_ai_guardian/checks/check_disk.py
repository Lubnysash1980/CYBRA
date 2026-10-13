"""Місце на диску + розмір логів/бекапів."""
import shutil, subprocess
from pathlib import Path

H = Path.home() / "CYBRA"

def size_mb(p):
    try:
        out = subprocess.run(["du","-sm",str(p)], capture_output=True, text=True, timeout=15)
        return int(out.stdout.split()[0]) if out.returncode==0 else 0
    except Exception: return 0

def run():
    out = []
    total, used, free = shutil.disk_usage(str(H))
    free_mb = free // (1024*1024)
    if free_mb < 200:
        out.append({"id":"disk.free","name":"Вільне місце","status":"critical",
                    "detail":f"{free_mb} MB","fix_hint":"очисти ~/CYBRA/backups, ~/CYBRA/logs"})
    elif free_mb < 1000:
        out.append({"id":"disk.free","name":"Вільне місце","status":"warn",
                    "detail":f"{free_mb} MB","fix_hint":"очисти старі бекапи"})
    else:
        out.append({"id":"disk.free","name":"Вільне місце","status":"ok",
                    "detail":f"{free_mb} MB","fix_hint":""})

    for sub, lvl, limit in [("logs", "warn", 100), ("backups","warn",500)]:
        p = H / sub
        if p.exists():
            mb = size_mb(p)
            s = "ok"
            hint = ""
            if mb > limit:
                s = lvl; hint = f"module_106_cleanup/main.sh" if (H/"modules/module_106_cleanup").exists() else "rm -rf старі файли"
            out.append({"id":f"disk.{sub}","name":f"Розмір {sub}","status":s,
                        "detail":f"{mb} MB","fix_hint":hint})
    return out
