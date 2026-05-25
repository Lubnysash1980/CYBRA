import json, time, hashlib
from pathlib import Path

CHAIN_FILE = Path.home() / "CYBRA" / "tps6" / "chain.json"

def double_sha(data: str) -> str:
    first = hashlib.sha256(data.encode()).digest()
    return hashlib.sha256(first).hexdigest()

def load_chain():
    if CHAIN_FILE.exists():
        return json.loads(CHAIN_FILE.read_text(encoding="utf-8"))
    return []

def save_chain(chain):
    CHAIN_FILE.write_text(json.dumps(chain, ensure_ascii=False, indent=2), encoding="utf-8")

def create_genesis(owner_wallet="FesrWxqM67HrjFqsCoCHsUkRocZZBgWeg4P3T4b9FD9Y", supply=1000000):
    chain = load_chain()
    if chain:
        return chain[0]
    block = {
        "index": 0,
        "time": time.time(),
        "type": "genesis",
        "prev_hash": "0",
        "transactions": [
            {"to": owner_wallet, "amount": supply, "symbol": "TPS6"}
        ]
    }
    block["hash"] = double_sha(json.dumps(block, sort_keys=True))
    save_chain([block])
    return block

def add_block(transactions):
    chain = load_chain()
    prev = chain[-1] if chain else create_genesis()
    block = {
        "index": len(chain),
        "time": time.time(),
        "type": "block",
        "prev_hash": prev["hash"],
        "transactions": transactions
    }
    block["hash"] = double_sha(json.dumps(block, sort_keys=True))
    chain.append(block)
    save_chain(chain)
    return block

def balances():
    out = {}
    for block in load_chain():
        for tx in block.get("transactions", []):
            if "from" in tx:
                out[tx["from"]] = out.get(tx["from"], 0) - int(tx["amount"])
            out[tx["to"]] = out.get(tx["to"], 0) + int(tx["amount"])
    return out
