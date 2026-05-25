import json
from pathlib import Path

MEMPOOL = Path.home() / "CYBRA" / "tps6" / "mempool.json"

def load():
    if MEMPOOL.exists():
        return json.loads(MEMPOOL.read_text(encoding="utf-8"))
    return []

def add(tx):
    data = load()
    data.append(tx)
    MEMPOOL.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    return tx

def flush():
    data = load()
    MEMPOOL.write_text("[]", encoding="utf-8")
    return data
