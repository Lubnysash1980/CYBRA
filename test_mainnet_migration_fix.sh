#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== TEST KIBRA MAINNET MIGRATION FIX ==="

mkdir -p data/cybra_mainnet/reports posts feeds proofs logs/mainnet

python3 - <<'PY'
import json, time, hashlib, subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"

files = {
    "snapshot": ROOT / "data/cybra_mainnet/snapshots/latest_test_blocks_snapshot.json",
    "claims": ROOT / "data/cybra_mainnet/claims/latest_pre_mainnet_claims.json",
    "genesis": ROOT / "data/cybra_mainnet/genesis/latest_mainnet_genesis_candidate.json",
    "report": ROOT / "data/cybra_mainnet/reports/latest_mainnet_migration_fix.json",
    "post": ROOT / "posts/cybra_mainnet_migration_fix.md",
    "feed": ROOT / "feeds/cybra_mainnet_migration_fix.json",
    "proof": ROOT / "proofs/cybra_mainnet_migration_fix.sha256"
}

def read_json(p):
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return {}

snapshot = read_json(files["snapshot"])
claims = read_json(files["claims"])
genesis = read_json(files["genesis"])
report = read_json(files["report"])

checks = {}

for name, path in files.items():
    checks[f"exists:{name}"] = path.exists()

checks["snapshot_status_ok"] = snapshot.get("status") == "TEST_BLOCKS_SNAPSHOTTED_FOR_MAINNET_REVIEW"
checks["claims_status_ok"] = claims.get("status") == "CLAIM_DRAFT_LOCKED"
checks["genesis_status_ok"] = genesis.get("status") == "GENESIS_CANDIDATE_LOCKED"

checks["mainnet_live_false"] = genesis.get("mainnet_live_now") is False
checks["automatic_mainnet_launch_false"] = genesis.get("safety", {}).get("automatic_mainnet_launch") is False
checks["automatic_real_rewards_false"] = genesis.get("safety", {}).get("automatic_real_rewards") is False
checks["automatic_external_tx_false"] = genesis.get("safety", {}).get("automatic_external_tx") is False
checks["owner_approval_required"] = genesis.get("safety", {}).get("manual_OWNER_approval_required") is True

checks["test_blocks_not_deleted"] = snapshot.get("policy", {}).get("test_blocks_are_not_deleted") is True
checks["test_blocks_not_mainnet_yet"] = snapshot.get("policy", {}).get("test_blocks_are_not_real_mainnet_blocks_yet") is True
checks["claims_pending_review"] = all(
    x.get("claim_status") == "PENDING_REVIEW" and x.get("mainnet_reward_now") == 0
    for x in claims.get("miners", [])
)

p = subprocess.run(
    "sha256sum -c proofs/cybra_mainnet_migration_fix.sha256",
    shell=True,
    cwd=ROOT,
    text=True,
    capture_output=True
)
checks["sha256_proof_ok"] = p.returncode == 0

blocks_count = snapshot.get("blocks_count", 0)
miners_count = snapshot.get("miners_count", 0)

checks["snapshot_has_block_counter"] = isinstance(blocks_count, int)
checks["snapshot_has_miner_counter"] = isinstance(miners_count, int)

passed = sum(1 for v in checks.values() if v is True)
total = len(checks)
score = round((passed / total) * 100, 2) if total else 0

status = "MAINNET_MIGRATION_TEST_PASS" if score == 100 else "MAINNET_MIGRATION_TEST_PARTIAL"

test_report = {
    "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
    "status": status,
    "score_percent": score,
    "blocks_count": blocks_count,
    "miners_count": miners_count,
    "checks": checks,
    "decision": "Test blocks are preserved as snapshot/claims. Mainnet is still locked until OWNER + Cyber Parliament approval.",
    "safety": {
        "mainnet_live_now": False,
        "automatic_mainnet_launch": False,
        "automatic_real_rewards": False,
        "automatic_external_tx": False,
        "manual_OWNER_approval_required": True,
        "cyber_parliament_approval_required": True
    }
}

out_json = ROOT / "data/cybra_mainnet/reports/mainnet_migration_test_latest.json"
out_feed = ROOT / "feeds/cybra_mainnet_migration_test.json"
out_md = ROOT / "posts/cybra_mainnet_migration_test.md"
out_proof = ROOT / "proofs/cybra_mainnet_migration_test.sha256"

out_json.write_text(json.dumps(test_report, ensure_ascii=False, indent=2), encoding="utf-8")
out_feed.write_text(json.dumps(test_report, ensure_ascii=False, indent=2), encoding="utf-8")

lines = [
    "# KIBRA Mainnet Migration Test",
    "",
    f"Timestamp: {test_report['timestamp']}",
    f"Status: **{status}**",
    f"Score: **{score}%**",
    "",
    "## Detected",
    f"- Test blocks count: `{blocks_count}`",
    f"- Miners count: `{miners_count}`",
    "",
    "## Checks"
]
for k, v in checks.items():
    lines.append(f"- {k}: `{v}`")

lines += [
    "",
    "## Decision",
    "Тестові блоки збережені як snapshot/claims.",
    "Mainnet досі заблокований до OWNER approval + Cyber Parliament approval.",
    "",
    "## Safety",
    "- mainnet_live_now: false",
    "- automatic_mainnet_launch: false",
    "- automatic_real_rewards: false",
    "- automatic_external_tx: false",
    "- manual_OWNER_approval_required: true",
    "- cyber_parliament_approval_required: true"
]

out_md.write_text("\n".join(lines) + "\n", encoding="utf-8")

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

out_proof.write_text(
    f"{sha(out_json)}  data/cybra_mainnet/reports/mainnet_migration_test_latest.json\n"
    f"{sha(out_feed)}  feeds/cybra_mainnet_migration_test.json\n"
    f"{sha(out_md)}  posts/cybra_mainnet_migration_test.md\n",
    encoding="utf-8"
)

print(json.dumps(test_report, ensure_ascii=False, indent=2))
PY

echo
echo "=== REPORT ==="
cat posts/cybra_mainnet_migration_test.md

echo
echo "=== PROOF CHECK ==="
sha256sum -c proofs/cybra_mainnet_migration_test.sha256

echo
echo "=== ORIGINAL MAINNET PROOF ==="
sha256sum -c proofs/cybra_mainnet_migration_fix.sha256

echo
echo "✅ MAINNET MIGRATION TEST DONE"
