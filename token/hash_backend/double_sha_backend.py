#!/usr/bin/env python3
import hashlib, json, sys
from pathlib import Path

def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def double_sha(data: bytes) -> str:
    return hashlib.sha256(hashlib.sha256(data).digest()).hexdigest()

files = sys.argv[1:]
result = {}

for f in files:
    p = Path(f)
    if p.exists() and p.is_file():
        data = p.read_bytes()
        result[str(p)] = {
            "sha256": sha256(data),
            "double_sha256": double_sha(data),
            "size": len(data)
        }

Path("token/hash_backend/double_sha_report.json").write_text(
    json.dumps(result, indent=2, ensure_ascii=False),
    encoding="utf-8"
)

print(json.dumps(result, indent=2, ensure_ascii=False))
