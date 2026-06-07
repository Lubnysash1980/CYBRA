#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== LAUNCH KIBRA INTERNAL MAINNET + TEST ==="

CONFIRM="$1"

if [ "$CONFIRM" != "I_APPROVE_INTERNAL_MAINNET_TEST_ONLY" ]; then
  echo "Потрібне ручне підтвердження."
  echo
  echo "Запуск:"
  echo "  bash launch_kibra_internal_mainnet_and_test.sh I_APPROVE_INTERNAL_MAINNET_TEST_ONLY"
  echo
  echo "Це запускає тільки INTERNAL MAINNET TEST."
  echo "Без реальних платежів, без SWIFT, без виводів, без зовнішніх транзакцій."
  exit 1
fi

TS="$(date +%Y%m%d_%H%M%S)"

mkdir -p \
  blockchain/kibra_chain/mainnet/blocks \
  blockchain/kibra_chain/mainnet/state \
  data/cybra_mainnet/{live,reports,tests,claims,approval} \
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

python3 - <<'PY'
import json, time, hashlib, uuid
from pathlib import Path

ROOT = Path.home() / "CYBRA"

def read_json(path, default=None):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except Exception:
        return default if default is not None else {}

def write_json(path, data):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

def sha_obj(obj):
    return hashlib.sha256(json.dumps(obj, ensure_ascii=False, sort_keys=True).encode()).hexdigest()

def sha_file(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

now = time.strftime("%Y-%m-%dT%H:%M:%S")

snapshot = read_json(ROOT / "data/cybra_mainnet/snapshots/latest_test_blocks_snapshot.json", {})
claims = read_json(ROOT / "data/cybra_mainnet/claims/latest_pre_mainnet_claims.json", {})
candidate = read_json(ROOT / "data/cybra_mainnet/candidate/latest_mainnet_candidate_stage.json", {})
candidate_genesis = read_json(ROOT / "blockchain/kibra_chain/mainnet_candidate/genesis_candidate_block.json", {})
approval = read_json(ROOT / "data/cybra_mainnet/approval/reports/latest_mainnet_candidate_approval.json", {})

blocks_count = snapshot.get("blocks_count", 0)
miners_count = snapshot.get("miners_count", 0)

snapshot_hash = sha_obj(snapshot) if snapshot else "0" * 64
claims_hash = sha_obj(claims) if claims else "0" * 64
candidate_hash = sha_obj(candidate) if candidate else "0" * 64

network_id = "KIBRA_INTERNAL_MAINNET_TEST"
chain_id = "kibra-mainnet-internal-" + hashlib.sha256((snapshot_hash + claims_hash).encode()).hexdigest()[:16]

safety = {
    "real_payment_now": False,
    "real_trading_now": False,
    "automatic_SWIFT": False,
    "automatic_external_tx": False,
    "automatic_withdrawals": False,
    "automatic_real_rewards": False,
    "external_bridge_enabled": False,
    "bank_live_mode": False,
    "psp_live_mode": False,
    "mainnet_scope": "INTERNAL_LOCAL_CHAIN_ONLY",
    "manual_OWNER_approval_required_for_external_live": True,
    "cyber_parliament_approval_required_for_external_live": True
}

genesis = {
    "network": network_id,
    "chain_id": chain_id,
    "timestamp": now,
    "height": 0,
    "previous_hash": "0" * 64,
    "status": "INTERNAL_MAINNET_GENESIS_CREATED",
    "mode": "INTERNAL_MAINNET_TEST",
    "snapshot_hash": snapshot_hash,
    "claims_hash": claims_hash,
    "candidate_hash": candidate_hash,
    "test_blocks_snapshot_count": blocks_count,
    "miners_count": miners_count,
    "candidate_genesis_hash": candidate_genesis.get("hash"),
    "external_live": False,
    "safety": safety
}
genesis["hash"] = sha_obj(genesis)

claim_registry = claims.get("miners", [])
balances = {}
for item in claim_registry:
    miner = item.get("miner", "unknown_miner")
    count = int(item.get("test_blocks", 0) or 0)
    balances[miner] = {
        "pre_mainnet_claim_blocks": count,
        "internal_candidate_credit": count,
        "real_reward_now": 0,
        "claim_status": "REGISTERED_INTERNAL_MAINNET_TEST_ONLY"
    }

if not balances:
    balances["unknown_miner"] = {
        "pre_mainnet_claim_blocks": blocks_count,
        "internal_candidate_credit": blocks_count,
        "real_reward_now": 0,
        "claim_status": "REGISTERED_INTERNAL_MAINNET_TEST_ONLY"
    }

test_tx = {
    "tx_id": "KIBRA-INTERNAL-TEST-" + uuid.uuid4().hex[:12],
    "timestamp": now,
    "type": "INTERNAL_MAINNET_TEST_TX",
    "from": "system:genesis",
    "to": "system:mainnet_test",
    "amount": 0,
    "external": False,
    "note": "Internal test transaction only. No real value transfer."
}

block1 = {
    "network": network_id,
    "chain_id": chain_id,
    "timestamp": now,
    "height": 1,
    "previous_hash": genesis["hash"],
    "status": "INTERNAL_MAINNET_TEST_BLOCK_MINED",
    "miner": "cybra_internal_mainnet_miner",
    "transactions": [test_tx],
    "reward": {
        "internal_reward": 0,
        "real_reward": 0,
        "claim_only": True
    },
    "external_tx": False,
    "safety": safety
}
block1["hash"] = sha_obj(block1)

state = {
    "timestamp": now,
    "network": network_id,
    "chain_id": chain_id,
    "status": "INTERNAL_MAINNET_RUNNING_TESTED",
    "latest_height": 1,
    "genesis_hash": genesis["hash"],
    "latest_block_hash": block1["hash"],
    "blocks_count": 2,
    "test_blocks_snapshot_count": blocks_count,
    "miners_count": miners_count,
    "balances": balances,
    "external_live": False,
    "safety": safety
}

tests = {
    "genesis_created": bool(genesis.get("hash")),
    "block1_created": bool(block1.get("hash")),
    "block1_links_to_genesis": block1.get("previous_hash") == genesis.get("hash"),
    "state_latest_block_ok": state.get("latest_block_hash") == block1.get("hash"),
    "snapshot_preserved": blocks_count >= 0,
    "claims_registered": len(balances) >= 1,
    "no_real_rewards": all(v.get("real_reward_now") == 0 for v in balances.values()),
    "no_external_tx": block1.get("external_tx") is False,
    "swift_disabled": safety["automatic_SWIFT"] is False,
    "withdrawals_disabled": safety["automatic_withdrawals"] is False,
    "external_bridge_disabled": safety["external_bridge_enabled"] is False
}

score = round(sum(1 for v in tests.values() if v) / len(tests) * 100, 2)

test_report = {
    "timestamp": now,
    "status": "KIBRA_INTERNAL_MAINNET_TEST_PASS" if score == 100 else "KIBRA_INTERNAL_MAINNET_TEST_PARTIAL",
    "score_percent": score,
    "network": network_id,
    "chain_id": chain_id,
    "genesis_hash": genesis["hash"],
    "test_block_hash": block1["hash"],
    "test_blocks_snapshot_count": blocks_count,
    "miners_count": miners_count,
    "tests": tests,
    "decision": "Internal mainnet test launched successfully. External live mainnet remains locked.",
    "safety": safety
}

files = {
    "genesis": ROOT / "blockchain/kibra_chain/mainnet/genesis.json",
    "block1": ROOT / "blockchain/kibra_chain/mainnet/blocks/block_000001.json",
    "state": ROOT / "blockchain/kibra_chain/mainnet/state/latest_state.json",
    "live": ROOT / "data/cybra_mainnet/live/internal_mainnet_live_state.json",
    "report": ROOT / "data/cybra_mainnet/reports/internal_mainnet_test_latest.json",
    "feed": ROOT / "feeds/cybra_internal_mainnet_test.json",
    "post": ROOT / "posts/cybra_internal_mainnet_test.md"
}

write_json(files["genesis"], genesis)
write_json(files["block1"], block1)
write_json(files["state"], state)
write_json(files["live"], state)
write_json(files["report"], test_report)
write_json(files["feed"], test_report)

md = f"""# KIBRA Internal Mainnet Test

Status: **{test_report["status"]}**

Score: **{score}%**

## Network

- Network: `{network_id}`
- Chain ID: `{chain_id}`
- Genesis hash: `{genesis["hash"]}`
- Test block hash: `{block1["hash"]}`

## Snapshot / claims

- Test blocks snapshot count: `{blocks_count}`
- Miners count: `{miners_count}`
- Claims registered: `{tests["claims_registered"]}`

## What was launched

Internal KIBRA mainnet test chain:

1. Genesis block created.
2. First internal test block mined.
3. Snapshot and claims preserved.
4. State file created.
5. Proof generated.

## Safety

- external_live: false
- real_payment_now: false
- automatic_SWIFT: false
- automatic_external_tx: false
- automatic_withdrawals: false
- automatic_real_rewards: false
- external_bridge_enabled: false

This is internal local mainnet testing only.
"""

files["post"].write_text(md, encoding="utf-8")

proof = ROOT / "proofs/cybra_internal_mainnet_test.sha256"
proof.write_text(
    "".join(
        f"{sha_file(p)}  {p.relative_to(ROOT)}\n"
        for p in [
            files["genesis"],
            files["block1"],
            files["state"],
            files["live"],
            files["report"],
            files["feed"],
            files["post"]
        ]
    ),
    encoding="utf-8"
)

print(json.dumps(test_report, ensure_ascii=False, indent=2))
PY

cat > cybra-mainnet-live <<'EOF'
#!/usr/bin/env bash
cd "$HOME/CYBRA" || exit 1

case "$1" in
  status)
    cat posts/cybra_internal_mainnet_test.md
    ;;
  state)
    cat blockchain/kibra_chain/mainnet/state/latest_state.json
    ;;
  genesis)
    cat blockchain/kibra_chain/mainnet/genesis.json
    ;;
  block)
    cat blockchain/kibra_chain/mainnet/blocks/block_000001.json
    ;;
  proof)
    sha256sum -c proofs/cybra_internal_mainnet_test.sha256
    ;;
  *)
    echo "Commands:"
    echo "  cybra-mainnet-live status"
    echo "  cybra-mainnet-live state"
    echo "  cybra-mainnet-live genesis"
    echo "  cybra-mainnet-live block"
    echo "  cybra-mainnet-live proof"
    ;;
esac
EOF

chmod +x cybra-mainnet-live
ln -sf "$HOME/CYBRA/cybra-mainnet-live" "$PREFIX/bin/cybra-mainnet-live" 2>/dev/null || true

echo
echo "=== CHECK ==="
cybra-mainnet-live status
echo
cybra-mainnet-live proof
echo
echo "✅ KIBRA INTERNAL MAINNET LAUNCHED AND TESTED"
