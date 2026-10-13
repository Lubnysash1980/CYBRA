"""Git: чи є .git, чи є незакомічені зміни."""
import subprocess
from pathlib import Path

H = Path.home() / "CYBRA"

def run():
    out = []
    for sub in ["", "git_module"]:
        p = H / sub
        if not (p / ".git").exists():
            continue
        r = subprocess.run(["git","-C",str(p),"status","--porcelain"],
                           capture_output=True, text=True, timeout=10)
        n = len([l for l in r.stdout.splitlines() if l.strip()])
        tag = sub or "root"
        out.append({"id":f"git.{tag}","name":f"Git · {tag}",
                    "status":"ok" if n==0 else "warn",
                    "detail":f"{n} незакомічених","fix_hint":"" if n==0 else "зроби коміт"})
    if not out:
        out.append({"id":"git","name":"Git","status":"ok",
                    "detail":"немає репо (не критично)","fix_hint":""})
    return out
