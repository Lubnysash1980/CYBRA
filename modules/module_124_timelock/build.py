#!/usr/bin/env python3
"""Компіляція TimeLock.sol через solcx."""
import json, os, sys
from pathlib import Path

D = Path(__file__).resolve().parent
CONTRACTS = D / "contracts"
OUT = D / "artifacts"; OUT.mkdir(exist_ok=True)

def ensure_solc():
    try:
        import solcx
    except ImportError:
        print("  ! pip install py-solc-x"); sys.exit(1)
    try:
        solcx.install_solc("0.8.20")
    except Exception: pass
    solcx.set_solc_version("0.8.20")
    return solcx

def build(name="TimeLock"):
    solcx = ensure_solc()
    src = CONTRACTS / f"{name}.sol"
    if not src.exists():
        return False, f"немає {src}"
    print(f"  ▸ compile {name}.sol")
    compiled = solcx.compile_standard({
        "language": "Solidity",
        "sources": {f"{name}.sol": {"content": src.read_text()}},
        "settings": {
            "optimizer": {"enabled": True, "runs": 200},
            "outputSelection": {"*": {"*": ["abi", "evm.bytecode"]}}
        }
    })
    c = compiled["contracts"][f"{name}.sol"][name]
    abi = c["abi"]
    bytecode = c["evm"]["bytecode"]["object"]
    out = {
        "name": name,
        "compiler": "0.8.20",
        "abi": abi,
        "bytecode": "0x" + bytecode,
        "bytecode_size": len(bytecode)//2,
        "compiled_at": __import__("time").strftime("%Y-%m-%dT%H:%M:%SZ", __import__("time").gmtime()),
    }
    (OUT / f"{name}.json").write_text(json.dumps(out, indent=2))
    print(f"  ✓ {name}.json · bytecode {out['bytecode_size']} B · abi {len(abi)} items")
    return True, str(OUT / f"{name}.json")

if __name__ == "__main__":
    name = sys.argv[1] if len(sys.argv) > 1 else "TimeLock"
    ok, m = build(name)
    print(("✓ " if ok else "✗ ") + m)
    sys.exit(0 if ok else 1)
