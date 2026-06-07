#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== CREATE MAINNET CANDIDATE APPROVAL TICKETS ==="

TS="$(date +%Y%m%d_%H%M%S)"
TICKET_ID="MAINNET-CANDIDATE-APPROVAL-${TS}"

mkdir -p \
  data/cybra_mainnet/approval/{owner,parliament,combined,reports} \
  data/cybra_mainnet/tasks \
  data/cybra_mgs/tasks \
  data/cybra_oracle/tasks \
  parliament/committees/mainnet_migration_committee/tasks \
  parliament/committees/mainnet_approval_committee/tasks \
  parliament/committees/coin_approval_committee/tasks \
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
TICKET_ID = "$TICKET_ID"

def read_json(path, default=None):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except Exception:
        return default if default is not None else {}

def write_json(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

now = time.strftime("%Y-%m-%dT%H:%M:%S")

snapshot = read_json(ROOT / "data/cybra_mainnet/snapshots/latest_test_blocks_snapshot.json", {})
claims = read_json(ROOT / "data/cybra_mainnet/claims/latest_pre_mainnet_claims.json", {})
genesis = read_json(ROOT / "data/cybra_mainnet/genesis/latest_mainnet_genesis_candidate.json", {})
test_report = read_json(ROOT / "data/cybra_mainnet/reports/mainnet_migration_test_latest.json", {})

blocks_count = snapshot.get("blocks_count", 0)
miners_count = snapshot.get("miners_count", 0)

base_safety = {
    "mainnet_live_now": False,
    "automatic_mainnet_launch": False,
    "automatic_real_rewards": False,
    "automatic_external_tx": False,
    "automatic_withdrawals": False,
    "automatic_liquidity_creation": False,
    "real_payment_now": False,
    "manual_OWNER_approval_required": True,
    "cyber_parliament_approval_required": True,
    "anti_sybil_review_required": True
}

owner_ticket = {
    "ticket_id": TICKET_ID + "-OWNER",
    "timestamp": now,
    "type": "OWNER_APPROVAL_TICKET",
    "status": "WAITING_OWNER_APPROVAL",
    "title": "OWNER approval for moving test-block snapshot/claims into mainnet candidate stage",
    "decision_requested": "Approve preparation of KIBRA mainnet candidate stage from preserved test block snapshot and pre-mainnet miner claims.",
    "not_approved_automatically": [
        "mainnet live launch",
        "real rewards",
        "external transfers",
        "withdrawals",
        "liquidity creation",
        "exchange listing"
    ],
    "source_snapshot": "data/cybra_mainnet/snapshots/latest_test_blocks_snapshot.json",
    "source_claims": "data/cybra_mainnet/claims/latest_pre_mainnet_claims.json",
    "source_genesis_candidate": "data/cybra_mainnet/genesis/latest_mainnet_genesis_candidate.json",
    "detected": {
        "test_blocks_count": blocks_count,
        "miners_count": miners_count,
        "migration_test_status": test_report.get("status"),
        "migration_test_score": test_report.get("score_percent")
    },
    "owner_manual_action_required": True,
    "owner_approval_value": "PENDING",
    "safety": base_safety
}

parliament_ticket = {
    "ticket_id": TICKET_ID + "-PARLIAMENT",
    "timestamp": now,
    "type": "CYBER_PARLIAMENT_APPROVAL_TICKET",
    "status": "WAITING_CYBER_PARLIAMENT_VOTE",
    "title": "Cyber Parliament vote for KIBRA mainnet candidate stage",
    "vote_subject": "Move preserved test-block snapshot and pre-mainnet miner claims into KIBRA mainnet candidate stage.",
    "vote_options": [
        "APPROVE_MAINNET_CANDIDATE_STAGE_ONLY",
        "REJECT_AND_KEEP_TESTNET_ONLY",
        "REQUEST_ADDITIONAL_AUDIT"
    ],
    "recommended_vote": "APPROVE_MAINNET_CANDIDATE_STAGE_ONLY",
    "vote_does_not_enable": [
        "mainnet live launch",
        "real rewards",
        "external transfers",
        "withdrawals",
        "liquidity creation"
    ],
    "required_before_live": [
        "OWNER approval",
        "Cyber Parliament approval",
        "anti-sybil miner audit",
        "mainnet readiness gate",
        "finance live gate review"
    ],
    "detected": {
        "test_blocks_count": blocks_count,
        "miners_count": miners_count,
        "migration_test_status": test_report.get("status"),
        "migration_test_score": test_report.get("score_percent")
    },
    "safety": base_safety
}

combined = {
    "ticket_id": TICKET_ID,
    "timestamp": now,
    "status": "MAINNET_CANDIDATE_APPROVAL_GATE_CREATED",
    "stage_requested": "MAINNET_CANDIDATE_STAGE",
    "mainnet_live_now": False,
    "owner_ticket": owner_ticket["ticket_id"],
    "parliament_ticket": parliament_ticket["ticket_id"],
    "requirements": {
        "owner_approval": "PENDING",
        "cyber_parliament_approval": "PENDING",
        "anti_sybil_review": "PENDING",
        "mainnet_readiness_gate": "LOCKED",
        "finance_live_gate": "LOCKED"
    },
    "detected": {
        "test_blocks_count": blocks_count,
        "miners_count": miners_count,
        "migration_test_status": test_report.get("status"),
        "migration_test_score": test_report.get("score_percent")
    },
    "decision": "Approval tickets created. Snapshot/claims can move to mainnet candidate stage only after manual approvals.",
    "safety": base_safety
}

task = {
    "task_id": TICKET_ID,
    "timestamp": now,
    "title": "OWNER + Cyber Parliament approval for KIBRA mainnet candidate stage",
    "priority": "HIGH",
    "status": "QUEUED_FOR_APPROVAL",
    "routes": [
        "mainnet_approval_committee",
        "mainnet_migration_committee",
        "coin_approval_committee",
        "cybra_mgs_all",
        "cybra_oracle_tasks",
        "ai_block_inbox",
        "it_department",
        "parliament_inbox"
    ],
    "owner_ticket": owner_ticket,
    "parliament_ticket": parliament_ticket,
    "combined_approval_gate": combined,
    "safety": base_safety
}

files = {
    "owner": ROOT / f"data/cybra_mainnet/approval/owner/{owner_ticket['ticket_id']}.json",
    "parliament": ROOT / f"data/cybra_mainnet/approval/parliament/{parliament_ticket['ticket_id']}.json",
    "combined": ROOT / f"data/cybra_mainnet/approval/combined/{TICKET_ID}.json",
    "task": ROOT / f"data/cybra_mainnet/tasks/{TICKET_ID}.json",
    "report": ROOT / "data/cybra_mainnet/approval/reports/latest_mainnet_candidate_approval.json",
    "feed": ROOT / "feeds/cybra_mainnet_candidate_approval.json",
    "post": ROOT / "posts/cybra_mainnet_candidate_approval.md"
}

write_json(files["owner"], owner_ticket)
write_json(files["parliament"], parliament_ticket)
write_json(files["combined"], combined)
write_json(files["task"], task)
write_json(files["report"], combined)
write_json(files["feed"], combined)

for d in [
    ROOT / "data/cybra_mgs/tasks",
    ROOT / "data/cybra_oracle/tasks",
    ROOT / "parliament/committees/mainnet_migration_committee/tasks",
    ROOT / "parliament/committees/mainnet_approval_committee/tasks",
    ROOT / "parliament/committees/coin_approval_committee/tasks"
]:
    write_json(d / f"{TICKET_ID}.json", task)

md = f"""# KIBRA Mainnet Candidate Approval

Ticket ID: `{TICKET_ID}`

Status: **MAINNET_CANDIDATE_APPROVAL_GATE_CREATED**

## Requested stage

Move preserved test-block snapshot and pre-mainnet miner claims into:

`MAINNET_CANDIDATE_STAGE`

## Detected

- Test blocks count: `{blocks_count}`
- Miners count: `{miners_count}`
- Migration test status: `{test_report.get("status")}`
- Migration test score: `{test_report.get("score_percent")}%`

## OWNER Approval Ticket

`{owner_ticket["ticket_id"]}`

Status: `WAITING_OWNER_APPROVAL`

## Cyber Parliament Approval Ticket

`{parliament_ticket["ticket_id"]}`

Status: `WAITING_CYBER_PARLIAMENT_VOTE`

## Important

This approval ticket does **not** enable live mainnet automatically.

Still locked:

- mainnet_live_now: false
- automatic_mainnet_launch: false
- automatic_real_rewards: false
- automatic_external_tx: false
- automatic_withdrawals: false
- automatic_liquidity_creation: false

## Required before live

1. OWNER approval.
2. Cyber Parliament approval.
3. Anti-sybil miner audit.
4. Mainnet readiness gate.
5. Finance live gate review.
"""
files["post"].write_text(md, encoding="utf-8")

proof = ROOT / "proofs/cybra_mainnet_candidate_approval.sha256"
proof.write_text(
    "".join(
        f"{sha(p)}  {p.relative_to(ROOT)}\n"
        for p in [
            files["owner"],
            files["parliament"],
            files["combined"],
            files["task"],
            files["report"],
            files["feed"],
            files["post"]
        ]
    ),
    encoding="utf-8"
)

print(json.dumps(combined, ensure_ascii=False, indent=2))
PY

for q in cybra_mgs_all cybra_oracle_tasks ai_block_inbox it_department parliament_inbox cybra_mainnet_approval cybra_coin_approval; do
  if command -v redis-cli >/dev/null 2>&1; then
    redis-cli LPUSH "$q" "$(cat data/cybra_mainnet/tasks/${TICKET_ID}.json)" >/dev/null 2>&1 || true
  fi
done

cat > cybra-mainnet-approval <<'EOF'
#!/usr/bin/env bash
cd "$HOME/CYBRA" || exit 1

case "$1" in
  status)
    cat posts/cybra_mainnet_candidate_approval.md 2>/dev/null || true
    ;;
  proof)
    sha256sum -c proofs/cybra_mainnet_candidate_approval.sha256
    ;;
  owner)
    ls -1 data/cybra_mainnet/approval/owner/*.json 2>/dev/null | tail -1 | xargs -r cat
    ;;
  parliament)
    ls -1 data/cybra_mainnet/approval/parliament/*.json 2>/dev/null | tail -1 | xargs -r cat
    ;;
  combined)
    ls -1 data/cybra_mainnet/approval/combined/*.json 2>/dev/null | tail -1 | xargs -r cat
    ;;
  *)
    echo "Commands:"
    echo "  cybra-mainnet-approval status"
    echo "  cybra-mainnet-approval owner"
    echo "  cybra-mainnet-approval parliament"
    echo "  cybra-mainnet-approval combined"
    echo "  cybra-mainnet-approval proof"
    ;;
esac
EOF

chmod +x cybra-mainnet-approval
ln -sf "$HOME/CYBRA/cybra-mainnet-approval" "$PREFIX/bin/cybra-mainnet-approval" 2>/dev/null || true

echo
echo "✅ MAINNET CANDIDATE APPROVAL TICKETS CREATED"
echo
echo "Check:"
echo "  cybra-mainnet-approval status"
echo "  cybra-mainnet-approval proof"
