import json, hashlib
from pathlib import Path

CHAIN = Path.home() / "CYBRA" / "tps6" / "chain.json"
PROOF = Path.home() / "CYBRA" / "tps6" / "proof.json"

def double_sha(data: str) -> str:
    first = hashlib.sha256(data.encode()).digest()
    return hashlib.sha256(first).hexdigest()

def make_proof():
    raw = CHAIN.read_text(encoding="utf-8") if CHAIN.exists() else "[]"
    proof = {
        "chain_file": str(CHAIN),
        "double_sha256": double_sha(raw)
    }
    PROOF.write_text(json.dumps(proof, ensure_ascii=False, indent=2), encoding="utf-8")
    return proof
