"""Перевірка: цілісність hash-chain парламенту + виконань + dossier."""
import sys, os, json
from pathlib import Path

H = Path.home() / "CYBRA"
PRL = H / "modules/module_121_parlament"

def run():
    out = []
    if not PRL.exists():
        return [{"id":"parlament.chain","name":"Парламент·chain",
                 "status":"ok","detail":"не встановлено","fix_hint":""}]
    try:
        sys.path.insert(0, str(PRL))
        import parliament as P
        rep = P.verify_chain()
    except Exception as e:
        return [{"id":"parlament.chain","name":"Парламент·chain",
                 "status":"warn","detail":f"не читається: {e}","fix_hint":""}]

    broken = sum(r["broken"] for r in rep.values())
    total = sum(r["entries"] for r in rep.values())
    if broken > 0:
        out.append({"id":"parlament.chain","name":"Парламент·chain",
                    "status":"critical",
                    "detail":f"{broken} порушень з {total}",
                    "fix_hint":"перевір data/*.jsonl"})
    else:
        out.append({"id":"parlament.chain","name":"Парламент·chain",
                    "status":"ok","detail":f"{total} записів цілісні",
                    "fix_hint":""})

    # виконання контрактів — hash-chain у verify_7
    try:
        import verify_7
        EX = PRL / "data" / "executions"
        bad = 0; n = 0
        for f in EX.glob("C-*.json"):
            try: st = json.loads(f.read_text())
            except Exception: continue
            prev = "0"*64
            for h in st.get("history", []):
                n += 1
                if h.get("_prev") != prev or h.get("_hash") != verify_7._hash(h):
                    bad += 1
                prev = h.get("_hash")
        if bad > 0:
            out.append({"id":"execution.chain","name":"Виконання·chain",
                        "status":"critical",
                        "detail":f"{bad} порушень з {n}","fix_hint":""})
        else:
            out.append({"id":"execution.chain","name":"Виконання·chain",
                        "status":"ok","detail":f"{n} записів цілісні",
                        "fix_hint":""})
    except Exception as e:
        out.append({"id":"execution.chain","name":"Виконання·chain",
                    "status":"warn","detail":str(e)[:60],"fix_hint":""})

    # dossier-файли — валідний JSON?
    try:
        EX = PRL / "data" / "executions"
        bad_d = []
        for f in EX.glob("*_dossier.json"):
            try: json.loads(f.read_text())
            except Exception: bad_d.append(f.name)
        if bad_d:
            out.append({"id":"dossier.files","name":"Dossier-файли",
                        "status":"warn",
                        "detail":f"битих: {len(bad_d)}","fix_hint":""})
        else:
            out.append({"id":"dossier.files","name":"Dossier-файли",
                        "status":"ok","detail":"всі валідні","fix_hint":""})
    except Exception: pass

    return out
