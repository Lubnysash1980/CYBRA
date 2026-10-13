"""AutoNode живий? Остання активність свіжа?"""
import json, os, time
from pathlib import Path

H = Path.home() / "CYBRA"
ST = H / "run/autonode.json"
PID = H / "run/autonode.pid"

def run():
    out = []
    if not PID.exists():
        return [{"id":"autonode.running","name":"AutoNode daemon","status":"warn",
                 "detail":"не запущений","fix_hint":"module_114_autonode/main.sh start"}]
    try:
        pid = int(PID.read_text().strip())
        os.kill(pid, 0)
        out.append({"id":"autonode.running","name":"AutoNode daemon",
                    "status":"ok","detail":f"PID {pid}","fix_hint":""})
    except (ProcessLookupError, ValueError):
        return [{"id":"autonode.running","name":"AutoNode daemon","status":"fail",
                 "detail":"PID мертвий, але файл залишився",
                 "fix_hint":"rm run/autonode.pid; module_114_autonode/main.sh start"}]
    except PermissionError:
        pass

    if ST.exists():
        try:
            d = json.loads(ST.read_text())
            nets = d.get("networks",{})
            bad = [k for k,v in nets.items() if v.get("state")!="ok"]
            if bad:
                out.append({"id":"autonode.networks","name":"AutoNode мережі",
                            "status":"warn","detail":f"down: {','.join(bad)}",
                            "fix_hint":"module_114_autonode/main.sh restart"})
            else:
                out.append({"id":"autonode.networks","name":"AutoNode мережі",
                            "status":"ok","detail":f"{len(nets)} online","fix_hint":""})
        except Exception as e:
            out.append({"id":"autonode.status","name":"AutoNode статус",
                        "status":"warn","detail":f"не читається: {e}","fix_hint":""})
    return out
