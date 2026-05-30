#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p sha/{vault,patches,proofs,runtime,watchdog,autoheal,autofix,audit,neural,coin} posts proofs

cat > sha/runtime/sha_core_policy.json <<'JSON'
{
  "system": "CYBRA SHA CORE",
  "status": "active",
  "visibility": "closed_local",
  "layers": [
    "patches",
    "double_sha_proofs",
    "watchdog",
    "autoheal",
    "autofix",
    "audit",
    "coin_runtime",
    "neural_runtime"
  ],
  "rules": [
    "no_secrets_in_git",
    "patch_per_task",
    "double_sha_required",
    "audit_required",
    "owner_approval_for_critical"
  ]
}
JSON

cat > sha/runtime/sha_core_manager.py <<'PY'
#!/usr/bin/env python3
import json, hashlib, time, re
from pathlib import Path

BASE = Path("sha")
for d in ["patches", "proofs", "audit", "coin", "runtime"]:
    (BASE / d).mkdir(parents=True, exist_ok=True)

def double_sha(text: str) -> str:
    b = text.encode()
    return hashlib.sha256(hashlib.sha256(b).digest()).hexdigest()

def safe_name(text: str) -> str:
    return re.sub(r"[^a-zA-Z0-9а-яА-ЯіїєґІЇЄҐ_-]+", "_", text).strip("_")[:80] or "unknown"

def create_patch(topic, task_type, conclusion="created"):
    patch_id = f"{int(time.time())}_{safe_name(topic)}"
    patch = {
        "patch_id": patch_id,
        "topic": topic,
        "type": task_type,
        "status": "created",
        "conclusion": conclusion,
        "created_at": time.time()
    }
    raw = json.dumps(patch, ensure_ascii=False, indent=2)
    proof = double_sha(raw)
    patch["double_sha"] = proof

    patch_file = BASE / "patches" / f"{patch_id}.json"
    patch_file.write_text(json.dumps(patch, ensure_ascii=False, indent=2), encoding="utf-8")

    audit_file = BASE / "audit" / "sha_core_audit.jsonl"
    with audit_file.open("a", encoding="utf-8") as f:
        f.write(json.dumps({"event": "patch_created", "patch": str(patch_file), "proof": proof}, ensure_ascii=False) + "\n")

    return patch

if __name__ == "__main__":
    p = create_patch("SHA Core Manager Init", "sha_core_task", "SHA Core Manager initialized")
    print(json.dumps(p, ensure_ascii=False, indent=2))
PY

chmod +x sha/runtime/sha_core_manager.py
python3 sha/runtime/sha_core_manager.py > sha/runtime/init_patch.json

sha256sum \
  sha/runtime/sha_core_policy.json \
  sha/runtime/sha_core_manager.py \
  sha/runtime/init_patch.json \
  > sha/proofs/sha_core_manager.sha256

cat > posts/sha_core_manager_status.md <<'MD'
# CYBRA SHA Core Manager

Status: active

Created:
- sha/vault
- sha/patches
- sha/proofs
- sha/runtime
- sha/watchdog
- sha/autoheal
- sha/autofix
- sha/audit
- sha/neural
- sha/coin

Rules:
- patch per task
- double SHA proof
- closed local storage
- no secrets in Git
MD

sha256sum posts/sha_core_manager_status.md sha/proofs/sha_core_manager.sha256 > proofs/sha_core_manager_public.sha256

echo "✅ SHA Core Manager installed"
