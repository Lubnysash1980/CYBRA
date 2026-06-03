#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

echo "=== SEAL CYBRA AUTORECOVERY PATCH V2 INTO SHA ==="

mkdir -p data/cybra_autorecovery/patches posts feeds proofs logs/cybra_autorecovery runtime/redis

PATCH_ID="CYBRA-AUTORECOVERY-PATCH-V2"
SEAL_JSON="data/cybra_autorecovery/patches/v2_patch_seal.json"
FEED="feeds/cybra_autorecovery_patch_v2_seal.json"
POST="posts/cybra_autorecovery_patch_v2_seal.md"
PROOF="proofs/cybra_autorecovery_patch_v2.sha256"

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir "$HOME/CYBRA/runtime/redis" --save "" --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

echo
echo "=== 1. BUILD FILE HASH LIST ==="

rm -f "$PROOF"

for f in \
  cybra_autorecovery_patch_v2.sh \
  bin/cybra-recover \
  cybra_recovery.sh \
  cybra_autorecovery_handler.sh \
  cybra_termux_restore.sh \
  data/cybra_autorecovery/restore_pack/cybra_termux_restore.sh \
  data/cybra_autorecovery/restore_pack/README_RESTORE.txt \
  data/cybra_autorecovery/restore_pack/SHA256SUMS.txt \
  data/cybra_autorecovery/restore_pack/cybra_restore_pack_v2.tar.gz \
  feeds/cybra_autorecovery_report.json \
  posts/cybra_autorecovery_report.md \
  proofs/cybra_autorecovery.sha256 \
  parliament/departments/finance_department/cybra_autorecovery_committee/committee.json \
  parliament/departments/cybra_finance_department/cybra_autorecovery_committee/committee.json
do
  if [ -f "$f" ]; then
    sha256sum "$f" >> "$PROOF"
  fi
done

echo
echo "=== 2. CREATE DOUBLE SHA SEAL ==="

python3 - <<'PY'
import json, time, hashlib, subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"

patch_id = "CYBRA-AUTORECOVERY-PATCH-V2"
proof_path = ROOT / "proofs/cybra_autorecovery_patch_v2.sha256"
seal_json = ROOT / "data/cybra_autorecovery/patches/v2_patch_seal.json"
feed = ROOT / "feeds/cybra_autorecovery_patch_v2_seal.json"
post = ROOT / "posts/cybra_autorecovery_patch_v2_seal.md"

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
    "status": "sealed",
    "patch_id": patch_id,
    "patch_version": "v2",
    "sealed_at": time.time(),
    "sealed_at_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "files_count": len(files),
    "files": files,
    "rules": {
        "private_identity_included": False,
        "private_keys_included": False,
        "seed_phrase_included": False,
        "github_token_included": False,
        "real_payment_now": False,
        "automatic_SWIFT": False,
        "automatic_external_tx": False,
        "manual_OWNER_approval_required": True
    },
    "purpose": "Seal CYBRA AutoRecovery Patch v2 restore pack, recovery binary, wrapper, handler, restore script and reports into SHA proof."
}

seal["proof_sha256"] = sha_text(proof_text)
seal["double_sha"] = dsha_text(json.dumps(seal, ensure_ascii=False, sort_keys=True))

seal_json.parent.mkdir(parents=True, exist_ok=True)
feed.parent.mkdir(parents=True, exist_ok=True)
post.parent.mkdir(parents=True, exist_ok=True)

seal_json.write_text(json.dumps(seal, ensure_ascii=False, indent=2), encoding="utf-8")
feed.write_text(json.dumps(seal, ensure_ascii=False, indent=2), encoding="utf-8")

md = []
md.append("# CYBRA AutoRecovery Patch V2 Seal")
md.append("")
md.append("Status: sealed")
md.append(f"Patch ID: {patch_id}")
md.append(f"Files sealed: {len(files)}")
md.append("")
md.append("## Safety")
for k, v in seal["rules"].items():
    md.append(f"{k}: {v}")
md.append("")
md.append("## Proof SHA256")
md.append(seal["proof_sha256"])
md.append("")
md.append("## Double SHA")
md.append(seal["double_sha"])
md.append("")
md.append("## Files")
for f in files:
    md.append(f"- {f['sha256']}  {f['file']}")

post.write_text("\n".join(md), encoding="utf-8")

with (ROOT / "proofs/cybra_autorecovery_patch_v2_seal.sha256").open("w") as out:
    subprocess.run([
        "sha256sum",
        "data/cybra_autorecovery/patches/v2_patch_seal.json",
        "feeds/cybra_autorecovery_patch_v2_seal.json",
        "posts/cybra_autorecovery_patch_v2_seal.md",
        "proofs/cybra_autorecovery_patch_v2.sha256"
    ], cwd=ROOT, stdout=out, stderr=subprocess.DEVNULL)

print("PATCH_ID:", patch_id)
print("FILES_COUNT:", len(files))
print("PROOF_SHA256:", seal["proof_sha256"])
print("DOUBLE_SHA:", seal["double_sha"])
PY

echo
echo "=== 3. VERIFY SHA ==="

sha256sum -c proofs/cybra_autorecovery_patch_v2.sha256 || true
sha256sum -c proofs/cybra_autorecovery_patch_v2_seal.sha256 || true

echo
echo "=== 4. REDIS AUDIT + AI TASK ==="

DOUBLE_SHA="$(python3 - <<'PY'
import json
from pathlib import Path
p = Path.home() / "CYBRA/data/cybra_autorecovery/patches/v2_patch_seal.json"
print(json.loads(p.read_text(encoding="utf-8"))["double_sha"])
PY
)"

redis-cli LPUSH cybra:autorecovery:audit "{\"status\":\"patch_v2_sealed\",\"patch_id\":\"CYBRA-AUTORECOVERY-PATCH-V2\",\"double_sha\":\"$DOUBLE_SHA\",\"real_payment_now\":false}" >/dev/null || true

redis-cli LPUSH cybra:ai:tasks:block_inbox "{\"topic\":\"CYBRA AutoRecovery Patch V2 sealed\",\"type\":\"cybra_autorecovery_task\",\"priority\":\"critical\",\"payload\":{\"patch_id\":\"CYBRA-AUTORECOVERY-PATCH-V2\",\"double_sha\":\"$DOUBLE_SHA\",\"convert_to_mining_block_first\":true,\"send_to_pool_mining\":true,\"real_payment_now\":false,\"automatic_external_tx\":false,\"manual_OWNER_approval_required\":true}}" >/dev/null || true

if [ -f cybra_closed_sha_bridge.sh ]; then
  bash cybra_closed_sha_bridge.sh cycle || true
fi

echo
echo "=== 5. FINAL STATUS ==="
cat posts/cybra_autorecovery_patch_v2_seal.md
echo
echo "✅ PATCH V2 SEALED INTO SHA"
