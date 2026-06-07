#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== CYBRA/KIBRA MAINNET MIGRATION FIX ==="

TS="$(date +%Y%m%d_%H%M%S)"
TASK_ID="MAINNET-MIGRATION-FIX-${TS}"

mkdir -p \
  data/cybra_mainnet/{tasks,reports,snapshots,genesis,claims,readiness} \
  data/cybra_coin/approval/tasks \
  data/cybra_mgs/tasks \
  data/cybra_oracle/tasks \
  parliament/committees/mainnet_migration_committee/tasks \
  blockchain/kibra_chain/mainnet_candidate \
  posts feeds proofs logs/mainnet runtime/redis

if command -v redis-cli >/dev/null 2>&1; then
  if ! redis-cli ping >/dev/null 2>&1; then
    redis-server --daemonize yes \
      --bind 127.0.0.1 \
      --port 6379 \
      --dir "$HOME/CYBRA/runtime/redis" \
      --save "" \
      --appendonly no >/dev/null 2>&1 || true
    sleep 1
  fi
fi

python3 - <<PY
import json, time, hashlib
from pathlib import Path

ROOT = Path.home() / "CYBRA"
TS = "$TS"
TASK_ID = "$TASK_ID"

sources = [
    ROOT / "blockchain/kibra_chain/task_blocks",
    ROOT / "blockchain/kibra_chain/blocks",
    ROOT / "data/cybra_ai_pool_launcher/dispatched",
    ROOT / "data/cybra_mainnet/test_blocks"
]

blocks = []
for d in sources:
    if not d.exists():
        continue
    for f in sorted(d.glob("*.json")):
        try:
            data = json.loads(f.read_text(encoding="utf-8", errors="ignore"))
        except Exception:
            data = {"raw_file": str(f)}
        raw = json.dumps(data, ensure_ascii=False, sort_keys=True)
        blocks.append({
            "file": str(f.relative_to(ROOT)),
            "sha256": hashlib.sha256(raw.encode()).hexdigest(),
            "detected_status": "TEST_BLOCK_OR_TASK_BLOCK",
            "mainnet_status": "NOT_MAINNET_YET",
            "data_hint": {
                "height": data.get("height") or data.get("block_height") or data.get("index"),
                "miner": data.get("miner") or data.get("miner_address") or data.get("wallet") or data.get("owner"),
                "reward": data.get("reward") or data.get("amount") or data.get("kibra_reward"),
                "task_id": data.get("task_id") or data.get("id")
            }
        })

miners = {}
for b in blocks:
    m = b["data_hint"].get("miner") or "unknown_miner"
    miners[m] = miners.get(m, 0) + 1

snapshot = {
    "snapshot_id": f"TEST-BLOCK-SNAPSHOT-{TS}",
    "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
    "status": "TEST_BLOCKS_SNAPSHOTTED_FOR_MAINNET_REVIEW",
    "blocks_count": len(blocks),
    "miners_count": len(miners),
    "blocks": blocks,
    "miners_block_counts": miners,
    "policy": {
        "test_blocks_are_not_deleted": True,
        "test_blocks_are_not_real_mainnet_blocks_yet": True,
        "test_blocks_can_become_pre_mainnet_claims_after_approval": True,
        "mainnet_conversion_requires_owner_approval": True,
        "mainnet_conversion_requires_cyber_parliament_approval": True,
        "anti_sybil_review_required": True,
        "no_automatic_real_payout": True
    }
}

claim = {
    "claim_id": f"PRE-MAINNET-CLAIM-{TS}",
    "timestamp": snapshot["timestamp"],
    "status": "CLAIM_DRAFT_LOCKED",
    "description": "Майнери отримали тестові блоки. Вони переводяться в pre-mainnet claim snapshot, а не в реальні mainnet rewards автоматично.",
    "miners": [
        {
            "miner": miner,
            "test_blocks": count,
            "claim_status": "PENDING_REVIEW",
            "mainnet_reward_now": 0
        }
        for miner, count in miners.items()
    ],
    "safety": {
        "real_payment_now": False,
        "automatic_external_tx": False,
        "automatic_withdrawals": False,
        "mainnet_live_now": False,
        "manual_OWNER_approval_required": True,
        "cyber_parliament_approval_required": True
    }
}

genesis_candidate = {
    "network": "KIBRA_MAINNET_CANDIDATE",
    "timestamp": snapshot["timestamp"],
    "status": "GENESIS_CANDIDATE_LOCKED",
    "source_snapshot": snapshot["snapshot_id"],
    "test_blocks_included_as_history": True,
    "test_blocks_count": len(blocks),
    "miners_count": len(miners),
    "mainnet_height_start": 0,
    "mainnet_live_now": False,
    "conversion_rule": "test blocks stay as audit history and pre-mainnet claims until OWNER + Cyber Parliament approval",
    "safety": {
        "automatic_mainnet_launch": False,
        "automatic_real_rewards": False,
        "automatic_external_tx": False,
        "manual_OWNER_approval_required": True
    }
}

task = {
    "task_id": TASK_ID,
    "timestamp": snapshot["timestamp"],
    "title": "Fix test blocks and prepare KIBRA coin for mainnet migration",
    "priority": "HIGH",
    "status": "QUEUED_FOR_MAINNET_APPROVAL",
    "objective": "Виправити ситуацію, де майнери отримали тестові блоки: зберегти їх як snapshot/claim, підготувати mainnet candidate, створити approval gate.",
    "routes": [
        "mainnet_migration_committee",
        "coin_approval_committee",
        "finance_it_department",
        "cybra_mgs_all",
        "cybra_oracle_tasks",
        "ai_block_inbox",
        "it_department",
        "parliament_inbox"
    ],
    "required_work": [
        "розділити TESTNET/MAINNET статуси",
        "зробити snapshot тестових блоків",
        "створити pre-mainnet miner claims",
        "створити mainnet genesis candidate",
        "заборонити автоматичне перетворення test rewards у real rewards",
        "підготувати OWNER approval ticket",
        "підготувати Cyber Parliament vote",
        "підготувати anti-sybil/miner audit",
        "підготувати mainnet readiness checklist"
    ],
    "safety": genesis_candidate["safety"]
}

paths = {
    "snapshot": ROOT / f"data/cybra_mainnet/snapshots/test_blocks_snapshot_{TS}.json",
    "claim": ROOT / f"data/cybra_mainnet/claims/pre_mainnet_claims_{TS}.json",
    "genesis": ROOT / f"data/cybra_mainnet/genesis/mainnet_genesis_candidate_{TS}.json",
    "latest_snapshot": ROOT / "data/cybra_mainnet/snapshots/latest_test_blocks_snapshot.json",
    "latest_claim": ROOT / "data/cybra_mainnet/claims/latest_pre_mainnet_claims.json",
    "latest_genesis": ROOT / "data/cybra_mainnet/genesis/latest_mainnet_genesis_candidate.json",
    "task": ROOT / f"data/cybra_mainnet/tasks/{TASK_ID}.json"
}

for p, data in [
    (paths["snapshot"], snapshot),
    (paths["claim"], claim),
    (paths["genesis"], genesis_candidate),
    (paths["latest_snapshot"], snapshot),
    (paths["latest_claim"], claim),
    (paths["latest_genesis"], genesis_candidate),
    (paths["task"], task)
]:
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

for d in [
    ROOT / "data/cybra_coin/approval/tasks",
    ROOT / "data/cybra_mgs/tasks",
    ROOT / "data/cybra_oracle/tasks",
    ROOT / "parliament/committees/mainnet_migration_committee/tasks"
]:
    d.mkdir(parents=True, exist_ok=True)
    (d / f"{TASK_ID}.json").write_text(json.dumps(task, ensure_ascii=False, indent=2), encoding="utf-8")

report = {
    "timestamp": snapshot["timestamp"],
    "status": "MAINNET_MIGRATION_FIX_PREPARED",
    "task_id": TASK_ID,
    "test_blocks_count": len(blocks),
    "miners_count": len(miners),
    "mainnet_live_now": False,
    "snapshot_file": str(paths["latest_snapshot"].relative_to(ROOT)),
    "claim_file": str(paths["latest_claim"].relative_to(ROOT)),
    "genesis_candidate_file": str(paths["latest_genesis"].relative_to(ROOT)),
    "decision": "Test blocks are preserved as pre-mainnet claims. Mainnet conversion requires approval.",
    "safety": genesis_candidate["safety"]
}

(ROOT / "feeds/cybra_mainnet_migration_fix.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
(ROOT / "data/cybra_mainnet/reports/latest_mainnet_migration_fix.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

md = ROOT / "posts/cybra_mainnet_migration_fix.md"
md.write_text(f"""# KIBRA Mainnet Migration Fix

Task ID: `{TASK_ID}`

Status: **MAINNET_MIGRATION_FIX_PREPARED**

## Що виправлено

Майнери отримали тестові блоки. Вони не видаляються і не губляться.  
Вони переведені в:

1. `test blocks snapshot`
2. `pre-mainnet miner claims`
3. `mainnet genesis candidate`

## Дані

- Test blocks count: `{len(blocks)}`
- Miners count: `{len(miners)}`
- Mainnet live now: `false`

## Правило

Тестові блоки **не є реальними mainnet блоками автоматично**.  
Вони можуть бути зараховані як pre-mainnet claims тільки після:

- OWNER approval
- Cyber Parliament approval
- miner/anti-sybil audit
- mainnet readiness gate

## Safety

- automatic_mainnet_launch: false
- automatic_real_rewards: false
- automatic_external_tx: false
- automatic_withdrawals: false
- manual_OWNER_approval_required: true
- cyber_parliament_approval_required: true
""", encoding="utf-8")

proof = ROOT / "proofs/cybra_mainnet_migration_fix.sha256"
files = [
    paths["latest_snapshot"],
    paths["latest_claim"],
    paths["latest_genesis"],
    paths["task"],
    ROOT / "feeds/cybra_mainnet_migration_fix.json",
    ROOT / "data/cybra_mainnet/reports/latest_mainnet_migration_fix.json",
    md
]
proof.write_text(
    "".join(f"{hashlib.sha256(f.read_bytes()).hexdigest()}  {f.relative_to(ROOT)}\n" for f in files if f.exists()),
    encoding="utf-8"
)

print(json.dumps(report, ensure_ascii=False, indent=2))
PY

for q in cybra_mgs_all cybra_oracle_tasks ai_block_inbox it_department parliament_inbox cybra_coin_approval cybra_mainnet_migration; do
  if command -v redis-cli >/dev/null 2>&1; then
    redis-cli LPUSH "$q" "$(cat data/cybra_mainnet/tasks/${TASK_ID}.json)" >/dev/null 2>&1 || true
  fi
done

cat > cybra-mainnet <<'EOF'
#!/usr/bin/env bash
cd "$HOME/CYBRA" || exit 1
case "$1" in
  status)
    cat posts/cybra_mainnet_migration_fix.md 2>/dev/null || true
    ;;
  snapshot)
    cat data/cybra_mainnet/snapshots/latest_test_blocks_snapshot.json 2>/dev/null || true
    ;;
  claims)
    cat data/cybra_mainnet/claims/latest_pre_mainnet_claims.json 2>/dev/null || true
    ;;
  genesis)
    cat data/cybra_mainnet/genesis/latest_mainnet_genesis_candidate.json 2>/dev/null || true
    ;;
  proof)
    sha256sum -c proofs/cybra_mainnet_migration_fix.sha256
    ;;
  *)
    echo "Commands:"
    echo "  cybra-mainnet status"
    echo "  cybra-mainnet snapshot"
    echo "  cybra-mainnet claims"
    echo "  cybra-mainnet genesis"
    echo "  cybra-mainnet proof"
    ;;
esac
EOF

chmod +x cybra-mainnet
ln -sf "$HOME/CYBRA/cybra-mainnet" "$PREFIX/bin/cybra-mainnet" 2>/dev/null || true

echo
echo "✅ MAINNET MIGRATION FIX CREATED"
echo
echo "Check:"
echo "  cybra-mainnet status"
echo "  cybra-mainnet proof"
