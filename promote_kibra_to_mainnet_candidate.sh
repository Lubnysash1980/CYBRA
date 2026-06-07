#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== PROMOTE KIBRA TO MAINNET CANDIDATE STAGE ==="

mkdir -p \
  data/cybra_mainnet/{candidate,approval,reports,claims,genesis} \
  blockchain/kibra_chain/mainnet_candidate \
  posts feeds proofs logs/mainnet

CONFIRM="$1"

if [ "$CONFIRM" != "I_APPROVE_MAINNET_CANDIDATE_ONLY" ]; then
  echo "Для безпеки команда потребує ручного підтвердження."
  echo
  echo "Запусти так:"
  echo "  bash promote_kibra_to_mainnet_candidate.sh I_APPROVE_MAINNET_CANDIDATE_ONLY"
  echo
  echo "Це НЕ запускає live mainnet і НЕ робить реальні виплати."
  exit 1
fi

python3 - <<'PY'
import json, time, hashlib
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

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

now = time.strftime("%Y-%m-%dT%H:%M:%S")

snapshot = read_json(ROOT / "data/cybra_mainnet/snapshots/latest_test_blocks_snapshot.json", {})
claims = read_json(ROOT / "data/cybra_mainnet/claims/latest_pre_mainnet_claims.json", {})
genesis_old = read_json(ROOT / "data/cybra_mainnet/genesis/latest_mainnet_genesis_candidate.json", {})
approval = read_json(ROOT / "data/cybra_mainnet/approval/reports/latest_mainnet_candidate_approval.json", {})

blocks_count = snapshot.get("blocks_count", 0)
miners_count = snapshot.get("miners_count", 0)

snapshot_hash = hashlib.sha256(
    json.dumps(snapshot, ensure_ascii=False, sort_keys=True).encode()
).hexdigest()

claims_hash = hashlib.sha256(
    json.dumps(claims, ensure_ascii=False, sort_keys=True).encode()
).hexdigest()

candidate = {
    "network": "KIBRA_MAINNET_CANDIDATE",
    "timestamp": now,
    "status": "MAINNET_CANDIDATE_READY",
    "stage": "MAINNET_CANDIDATE_STAGE",
    "mainnet_live_now": False,
    "real_rewards_now": False,
    "external_transactions_now": False,
    "source_snapshot_hash": snapshot_hash,
    "source_claims_hash": claims_hash,
    "test_blocks_count": blocks_count,
    "miners_count": miners_count,
    "height_start": 0,
    "chain_mode": "CANDIDATE_LOCKED",
    "approval_gate": {
        "owner_ticket_created": bool(approval.get("owner_ticket")),
        "parliament_ticket_created": bool(approval.get("parliament_ticket")),
        "owner_approval_status": approval.get("requirements", {}).get("owner_approval", "PENDING"),
        "parliament_approval_status": approval.get("requirements", {}).get("cyber_parliament_approval", "PENDING")
    },
    "safety": {
        "automatic_mainnet_launch": False,
        "automatic_real_rewards": False,
        "automatic_external_tx": False,
        "automatic_withdrawals": False,
        "automatic_liquidity_creation": False,
        "manual_OWNER_approval_required": True,
        "cyber_parliament_approval_required": True,
        "anti_sybil_review_required": True
    }
}

genesis_candidate_block = {
    "block_type": "KIBRA_MAINNET_CANDIDATE_GENESIS",
    "timestamp": now,
    "height": 0,
    "previous_hash": "0" * 64,
    "snapshot_hash": snapshot_hash,
    "claims_hash": claims_hash,
    "blocks_count_from_test_snapshot": blocks_count,
    "miners_count_from_claims": miners_count,
    "status": "CANDIDATE_GENESIS_LOCKED",
    "live": False,
    "note": "Candidate genesis only. Not live mainnet. No real rewards."
}

genesis_raw = json.dumps(genesis_candidate_block, ensure_ascii=False, sort_keys=True)
genesis_candidate_block["hash"] = hashlib.sha256(genesis_raw.encode()).hexdigest()

claim_registry = {
    "timestamp": now,
    "status": "PRE_MAINNET_CLAIMS_REGISTERED_IN_CANDIDATE",
    "mainnet_rewards_now": 0,
    "claims": claims.get("miners", []),
    "policy": {
        "claims_registered": True,
        "claims_payable_now": False,
        "requires_owner_approval": True,
        "requires_parliament_approval": True,
        "requires_anti_sybil_review": True
    }
}

files = {
    "candidate": ROOT / "data/cybra_mainnet/candidate/latest_mainnet_candidate_stage.json",
    "genesis": ROOT / "blockchain/kibra_chain/mainnet_candidate/genesis_candidate_block.json",
    "claims": ROOT / "data/cybra_mainnet/claims/mainnet_candidate_claim_registry.json",
    "report": ROOT / "data/cybra_mainnet/reports/mainnet_candidate_stage_latest.json",
    "feed": ROOT / "feeds/cybra_mainnet_candidate_stage.json",
    "post": ROOT / "posts/cybra_mainnet_candidate_stage.md"
}

write_json(files["candidate"], candidate)
write_json(files["genesis"], genesis_candidate_block)
write_json(files["claims"], claim_registry)
write_json(files["report"], candidate)
write_json(files["feed"], candidate)

md = f"""# KIBRA Mainnet Candidate Stage

Status: **MAINNET_CANDIDATE_READY**

## What happened

KIBRA moved from test-block snapshot / pre-mainnet claims into:

`MAINNET_CANDIDATE_STAGE`

## Detected

- Test blocks count: `{blocks_count}`
- Miners count: `{miners_count}`
- Candidate genesis hash: `{genesis_candidate_block["hash"]}`

## Important

This is **not live mainnet**.

Still locked:

- mainnet_live_now: false
- real_rewards_now: false
- automatic_external_tx: false
- automatic_withdrawals: false
- automatic_liquidity_creation: false

## Required before live

1. OWNER final approval.
2. Cyber Parliament final approval.
3. Anti-sybil miner audit.
4. Finance live gate review.
5. Mainnet launch script with manual confirmation.
"""

files["post"].write_text(md, encoding="utf-8")

proof = ROOT / "proofs/cybra_mainnet_candidate_stage.sha256"
proof.write_text(
    "".join(
        f"{sha(p)}  {p.relative_to(ROOT)}\n"
        for p in [
            files["candidate"],
            files["genesis"],
            files["claims"],
            files["report"],
            files["feed"],
            files["post"]
        ]
    ),
    encoding="utf-8"
)

print(json.dumps(candidate, ensure_ascii=False, indent=2))
PY

cat > cybra-mainnet-stage <<'EOF'
#!/usr/bin/env bash
cd "$HOME/CYBRA" || exit 1

case "$1" in
  status)
    cat posts/cybra_mainnet_candidate_stage.md
    ;;
  candidate)
    cat data/cybra_mainnet/candidate/latest_mainnet_candidate_stage.json
    ;;
  genesis)
    cat blockchain/kibra_chain/mainnet_candidate/genesis_candidate_block.json
    ;;
  claims)
    cat data/cybra_mainnet/claims/mainnet_candidate_claim_registry.json
    ;;
  proof)
    sha256sum -c proofs/cybra_mainnet_candidate_stage.sha256
    ;;
  *)
    echo "Commands:"
    echo "  cybra-mainnet-stage status"
    echo "  cybra-mainnet-stage candidate"
    echo "  cybra-mainnet-stage genesis"
    echo "  cybra-mainnet-stage claims"
    echo "  cybra-mainnet-stage proof"
    ;;
esac
EOF

chmod +x cybra-mainnet-stage
ln -sf "$HOME/CYBRA/cybra-mainnet-stage" "$PREFIX/bin/cybra-mainnet-stage" 2>/dev/null || true

echo
echo "✅ KIBRA MAINNET CANDIDATE STAGE CREATED"
echo
echo "Check:"
echo "  cybra-mainnet-stage status"
echo "  cybra-mainnet-stage proof"
