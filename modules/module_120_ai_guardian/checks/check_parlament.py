"""Перевіряє цілісність журналів парламенту (hash-chain)."""
import sys, os, json
from pathlib import Path

H = Path.home() / "CYBRA"
PRL = H / "modules/module_121_parlament"

def run():
    out = []
    if not PRL.exists():
        return [{"id":"parlament","name":"Парламент","status":"ok",
                 "detail":"не встановлено","fix_hint":""}]
    try:
        sys.path.insert(0, str(PRL))
        import parliament as P
        rep = P.verify_chain()
    except Exception as e:
        return [{"id":"parlament.chain","name":"Hash-chain парламенту",
                 "status":"warn","detail":f"не читається: {e}","fix_hint":""}]

    total_broken = sum(r["broken"] for r in rep.values())
    total_entries = sum(r["entries"] for r in rep.values())
    if total_broken > 0:
        out.append({"id":"parlament.chain","name":"Hash-chain парламенту",
                    "status":"critical",
                    "detail":f"{total_broken} порушених з {total_entries}",
                    "fix_hint":"перевір data/*.jsonl на підміну"})
    else:
        out.append({"id":"parlament.chain","name":"Hash-chain парламенту",
                    "status":"ok",
                    "detail":f"{total_entries} записів цілісні","fix_hint":""})

    # мертвий PID watchdog
    PID = H / "run/parlament.pid"
    if PID.exists():
        try:
            pid = int(PID.read_text().strip())
            os.kill(pid, 0)
            out.append({"id":"parlament.watchdog","name":"Watchdog парламенту",
                        "status":"ok","detail":f"PID {pid}","fix_hint":""})
        except (ProcessLookupError, ValueError):
            out.append({"id":"parlament.watchdog","name":"Watchdog парламенту",
                        "status":"warn","detail":"PID мертвий",
                        "fix_hint":"rm run/parlament.pid; watchdog.sh start"})
    else:
        out.append({"id":"parlament.watchdog","name":"Watchdog парламенту",
                    "status":"warn","detail":"не запущений",
                    "fix_hint":"module_121_parlament/watchdog.sh start"})
    return out
