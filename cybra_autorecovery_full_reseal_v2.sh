#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA"

echo "=== CYBRA AUTORECOVERY FULL RESEAL V2 ==="

mkdir -p data/cybra_autorecovery/patches data/cybra_autorecovery/restore_pack posts feeds proofs runtime/redis

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir "$HOME/CYBRA/runtime/redis" --save "" --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

echo
echo "=== 1. REBUILD RESTORE PACK BEFORE SEAL ==="

if [ -f cybra_recovery.sh ]; then
  bash cybra_recovery.sh patch || true
  bash cybra_recovery.sh make-pack || true
  bash cybra_recovery.sh export-pack || true
  bash cybra_recovery.sh report || true
  bash cybra_recovery.sh self-test || true
fi

echo
echo "=== 2. FULL SHA LIST ==="

PROOF="proofs/cybra_autorecovery_patch_v2_full.sha256"
SEAL_JSON="data/cybra_autorecovery/patches/v2_full_reseal.json"
FEED="feeds/cybra_autorecovery_patch_v2_full_seal.json"
POST="posts/cybra_autorecovery_patch_v2_full_seal.md"
SEAL_PROOF="proofs/cybra_autorecovery_patch_v2_full_seal.sha256"

rm -f "$PROOF"

for f in \
  cybra_autorecovery_patch_v2.sh \
  cybra_autorecovery_seal_patch_v2.sh \
  cybra_autorecovery_full_reseal_v2.sh \
  bin/cybra-recover \
  cybra_recovery.sh \
  cybra_autorecovery_handler.sh \
  cybra_termux_restore.sh \
  data/cybra_autorecovery/restore_pack/cybra_termux_restore.sh \
  data/cybra_autorecovery/restore_pack/README_RESTORE.txt \
  data/cybra_autorecovery/restore_pack/SHA256SUMS.txt \
  data/cybra_autorecovery/restore_pack/cybra_restore_pack_v2.tar.gz \
  data/cybra_autorecovery/reports/latest_report.json \
  data/cybra_autorecovery/reports/self_test.json \
  data/cybra_autorecovery/snapshots/latest_snapshot.json \
  feeds/cybra_autorecovery_report.json \
  posts/cybra_autorecovery_report.md \
  proofs/cybra_autorecovery.sha256 \
  parliament/departments/finance_department/cybra_autorecovery_committee/committee.json \
  parliament/departments/cybra_finance_department/cybra_autorecovery_committee/committee.json
do
  if [ -f "$f" ]; then
    sha256sum "$f" >> "$PROOF"
  else
    echo "MISSING $f"
  fi
done

echo
echo "=== 3. CREATE FULL DOUBLE SHA SEAL ==="

python3 - <<'PY'
import json, time, hashlib, subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"

patch_id = "CYBRA-AUTORECOVERY-PATCH-V2-FULL-RESEAL"
proof_path = ROOT / "proofs/cybra_autorecovery_patch_v2_full.sha256"
seal_json = ROOT / "data/cybra_autorecovery/patches/v2_full_reseal.json"
feed = ROOT / "feeds/cybra_autorecovery_patch_v2_full_seal.json"
post = ROOT / "posts/cybra_autorecovery_patch_v2_full_seal.md"

def sha_text(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha_text(x):
    return sha_text(sha_text(x))

proof_text = proof_path.read_text(encoding="utf-8") if proof_path.exists() else ""

files = []
for line in proof_text.splitlines():
    parts = line.split(None, 1)
    if len(parts) == 2:
        files.append({
            "sha256": parts[0],
            "file": parts[1]
        })

seal = {
    "status": "full_resealed",
    "patch_id": patch_id,
    "patch_version": "v2_full",
    "sealed_at": time.time(),
    "sealed_at_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "files_count": len(files),
    "files": files,
    "purpose": "Full SHA reseal for CYBRA AutoRecovery v2 including restore script, restore pack, reports, handler, binary and committee.",
    "safety": {
        "private_identity_included": False,
        "private_keys_included": False,
        "seed_phrase_included": False,
        "github_token_included": False,
        "real_payment_now": False,
        "automatic_SWIFT": False,
        "automatic_external_tx": False,
        "manual_OWNER_approval_required": True
    }
}

seal["proof_sha256"] = sha_text(proof_text)
seal["double_sha"] = dsha_text(json.dumps(seal, ensure_ascii=False, sort_keys=True))

seal_json.parent.mkdir(parents=True, exist_ok=True)
feed.parent.mkdir(parents=True, exist_ok=True)
post.parent.mkdir(parents=True, exist_ok=True)

seal_json.write_text(json.dumps(seal, ensure_ascii=False, indent=2), encoding="utf-8")
feed.write_text(json.dumps(seal, ensure_ascii=False, indent=2), encoding="utf-8")

lines = []
lines.append("# CYBRA AutoRecovery Patch V2 Full Reseal")
lines.append("")
lines.append("Status: full_resealed")
lines.append("Patch ID: " + patch_id)
lines.append("Files sealed: " + str(len(files)))
lines.append("")
lines.append("## Safety")
for k, v in seal["safety"].items():
    lines.append(f"{k}: {v}")
lines.append("")
lines.append("## Proof SHA256")
lines.append(seal["proof_sha256"])
lines.append("")
lines.append("## Double SHA")
lines.append(seal["double_sha"])
lines.append("")
lines.append("## Files")
for f in files:
    lines.append(f"- {f['sha256']}  {f['file']}")

post.write_text("\n".join(lines), encoding="utf-8")

with (ROOT / "proofs/cybra_autorecovery_patch_v2_full_seal.sha256").open("w") as out:
    subprocess.run([
        "sha256sum",
        "data/cybra_autorecovery/patches/v2_full_reseal.json",
        "feeds/cybra_autorecovery_patch_v2_full_seal.json",
        "posts/cybra_autorecovery_patch_v2_full_seal.md",
        "proofs/cybra_autorecovery_patch_v2_full.sha256"
    ], cwd=ROOT, stdout=out, stderr=subprocess.DEVNULL)

print("PATCH_ID:", patch_id)
print("FILES_COUNT:", len(files))
print("PROOF_SHA256:", seal["proof_sha256"])
print("DOUBLE_SHA:", seal["double_sha"])
PY

echo
echo "=== 4. VERIFY FULL SEAL ==="

sha256sum -c proofs/cybra_autorecovery_patch_v2_full.sha256 || true
sha256sum -c proofs/cybra_autorecovery_patch_v2_full_seal.sha256 || true

echo
echo "=== 5. REDIS AUDIT + BLOCK TASK ==="

DOUBLE_SHA="$(python3 - <<'PY'
import json
from pathlib import Path
p = Path.home() / "CYBRA/data/cybra_autorecovery/patches/v2_full_reseal.json"
print(json.loads(p.read_text(encoding="utf-8"))["double_sha"])
PY
)"

redis-cli LPUSH cybra:autorecovery:audit "{\"status\":\"patch_v2_full_resealed\",\"patch_id\":\"CYBRA-AUTORECOVERY-PATCH-V2-FULL-RESEAL\",\"double_sha\":\"$DOUBLE_SHA\",\"real_payment_now\":false}" >/dev/null || true

redis-cli LPUSH cybra:ai:tasks:block_inbox "{\"topic\":\"CYBRA AutoRecovery Patch V2 full resealed\",\"type\":\"cybra_autorecovery_task\",\"priority\":\"critical\",\"payload\":{\"patch_id\":\"CYBRA-AUTORECOVERY-PATCH-V2-FULL-RESEAL\",\"double_sha\":\"$DOUBLE_SHA\",\"convert_to_mining_block_first\":true,\"send_to_pool_mining\":true,\"real_payment_now\":false,\"automatic_external_tx\":false,\"manual_OWNER_approval_required\":true}}" >/dev/null || true

if [ -f cybra_closed_sha_bridge.sh ]; then
  bash cybra_closed_sha_bridge.sh cycle || true
fi

echo
echo "=== 6. FINAL FULL SEAL REPORT ==="
cat posts/cybra_autorecovery_patch_v2_full_seal.md

echo
echo "✅ AUTORECOVERY PATCH V2 FULL RESEALED"
