#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from pathlib import Path

try:
    import redis
except Exception:
    redis = None

ROOT = Path.home() / "CYBRA"

def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def double_sha_text(text: str) -> str:
    return sha256_text(sha256_text(text))

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def git_cmd(cmd):
    try:
        return subprocess.check_output(cmd, cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def file_exists(path):
    return (ROOT / path).exists()

def main():
    (ROOT / "logs/hash").mkdir(parents=True, exist_ok=True)
    (ROOT / "hash_storage/test").mkdir(parents=True, exist_ok=True)
    (ROOT / "posts").mkdir(exist_ok=True)
    (ROOT / "feeds").mkdir(exist_ok=True)
    (ROOT / "proofs").mkdir(exist_ok=True)

    payload = {
        "module": "CYBRA Hash Module Test",
        "status": "testing",
        "time": time.time(),
        "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "checks": [
            "double_sha_text",
            "manifest_hash",
            "proof_file",
            "hash_storage_write",
            "redis_audit_optional",
            "existing_hash_modules_detection"
        ],
        "git": {
            "branch": git_cmd(["git", "branch", "--show-current"]),
            "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"]),
            "dirty_files": len(git_cmd(["git", "status", "--short"]).splitlines())
        }
    }

    canonical = json.dumps(payload, ensure_ascii=False, sort_keys=True)
    payload_hash = sha256_text(canonical)
    payload_double_sha = double_sha_text(canonical)

    payload["sha256"] = payload_hash
    payload["double_sha"] = payload_double_sha

    payload_file = ROOT / "logs/hash/hash_test_payload.json"
    payload_file.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    manifest = {
        "name": "CYBRA Hash Module Test Manifest",
        "status": "generated",
        "time": time.time(),
        "payload_file": "logs/hash/hash_test_payload.json",
        "payload_sha256_file": sha256_file(payload_file),
        "payload_double_sha": payload_double_sha,
        "detected_modules": {
            "gitcybrahash_double_backend.mjs": file_exists("gitcybrahash_double_backend.mjs"),
            "hash_memory.py": file_exists("hash_memory.py"),
            "hash_daemon.mjs": file_exists("hash_daemon.mjs"),
            "cybra_sha_core_manager.sh": file_exists("cybra_sha_core_manager.sh"),
            "hash_storage/root_hash.json": file_exists("hash_storage/root_hash.json")
        }
    }

    manifest_base = json.dumps(manifest, ensure_ascii=False, sort_keys=True)
    manifest["root_double_sha"] = double_sha_text(manifest_base)

    manifest_file = ROOT / "hash_storage/test/hash_module_test_manifest.json"
    manifest_file.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

    feed = {
        "status": "hash_module_test_generated",
        "payload_double_sha": payload_double_sha,
        "root_double_sha": manifest["root_double_sha"],
        "manifest_file": "hash_storage/test/hash_module_test_manifest.json",
        "detected_modules": manifest["detected_modules"],
        "time": time.time()
    }

    feed_file = ROOT / "feeds/hash_module_test.json"
    feed_file.write_text(json.dumps(feed, ensure_ascii=False, indent=2), encoding="utf-8")

    detected_lines = ""
    for k, v in manifest["detected_modules"].items():
        detected_lines += f"- `{k}`: {v}\n"

    md = f"""# CYBRA Hash Module Test

Status: generated

Payload SHA256:
`{payload_hash}`

Payload Double SHA:
`{payload_double_sha}`

Root Double SHA:
`{manifest["root_double_sha"]}`

Manifest:
`hash_storage/test/hash_module_test_manifest.json`

## Detected hash modules

{detected_lines}

## Result

Hash module base pipeline works if:

- payload file exists;
- manifest file exists;
- proof file verifies;
- double SHA is generated;
- root double SHA is generated.
"""

    post_file = ROOT / "posts/hash_module_test.md"
    post_file.write_text(md, encoding="utf-8")

    proof_file = ROOT / "proofs/hash_module_test.sha256"
    with proof_file.open("w") as f:
        subprocess.run(
            [
                "sha256sum",
                "logs/hash/hash_test_payload.json",
                "hash_storage/test/hash_module_test_manifest.json",
                "feeds/hash_module_test.json",
                "posts/hash_module_test.md"
            ],
            cwd=ROOT,
            stdout=f,
            stderr=subprocess.DEVNULL
        )

    redis_status = "not_available"
    if redis is not None:
        try:
            r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)
            r.ping()
            r.lpush("cybra:hash:audit", json.dumps({
                "status": "hash_module_test_generated",
                "payload_double_sha": payload_double_sha,
                "root_double_sha": manifest["root_double_sha"],
                "time": time.time()
            }, ensure_ascii=False))
            redis_status = "audit_written"
        except Exception as e:
            redis_status = f"redis_error:{e}"

    print("✅ CYBRA hash module test generated")
    print("Payload Double SHA:", payload_double_sha)
    print("Root Double SHA:", manifest["root_double_sha"])
    print("Redis:", redis_status)
    print("Report: posts/hash_module_test.md")
    print("Feed: feeds/hash_module_test.json")
    print("Proof: proofs/hash_module_test.sha256")

if __name__ == "__main__":
    main()
