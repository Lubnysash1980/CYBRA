import time, json, hashlib

def double_sha(data: str) -> str:
    first = hashlib.sha256(data.encode()).digest()
    return hashlib.sha256(first).hexdigest()

def create_tx(sender, receiver, amount, symbol="TPS6"):
    tx = {
        "time": time.time(),
        "from": sender,
        "to": receiver,
        "amount": int(amount),
        "symbol": symbol
    }
    tx["hash"] = double_sha(json.dumps(tx, sort_keys=True))
    return tx
