#!/usr/bin/env python3
import json, time, hashlib, sys
from pathlib import Path

ROOT = Path.home() / "CYBRA"
PROOFS = ROOT / "proofs"
PROOFS.mkdir(parents=True, exist_ok=True)

SAFETY = {
    "real_trading_now": False,
    "live_force_trading_disabled": True,
    "automatic_external_tx": False,
    "automatic_SWIFT": False,
    "mainnet_deploy_allowed": False,
    "manual_OWNER_approval_required": True
}

def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S")

def sha_text(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def sign_patch(kind, title, target_file, body):
    payload = {
        "kind": kind,
        "title": title,
        "timestamp": now(),
        "target_file": target_file,
        "body": body,
        "safety": SAFETY
    }

    raw = json.dumps(payload, ensure_ascii=False, sort_keys=True, indent=2)
    first = sha_text(raw)
    double = sha_text(first)

    payload["sha256"] = first
    payload["double_sha256"] = double
    payload["signature_type"] = "CYBRA_DOUBLE_SHA256_LOCAL_SIGNATURE"

    path = ROOT / target_file
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    proof = PROOFS / f"{Path(target_file).stem}.sha256"
    proof.write_text(f"{first}  {target_file}\nDOUBLE_SHA256 {double}\n", encoding="utf-8")

    print(json.dumps(payload, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    kind = sys.argv[1]
    title = sys.argv[2]
    target = sys.argv[3]
    body = " ".join(sys.argv[4:])
    sign_patch(kind, title, target, body)
