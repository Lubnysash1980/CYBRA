#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== BIND KIBRA MINER TO WALLET ==="

WALLET="${1:-FesrWxqM67HrjFqsCoCHsUkRocZZBgWeg4P3T4b9FD9Y}"
TS="$(date +%Y%m%d_%H%M%S)"
BIND_ID="KIBRA-MINER-WALLET-BIND-${TS}"

mkdir -p \
  data/cybra_mainnet/miners \
  data/cybra_mainnet/claims \
  data/cybra_mainnet/reports \
  blockchain/kibra_chain/mainnet/blocks \
  blockchain/kibra_chain/mainnet/state \
  posts feeds proofs logs/mainnet

python3 - <<PY
import json, time, hashlib, re
from pathlib import Path

ROOT = Path.home() / "CYBRA"
WALLET = "$WALLET"
BIND_ID = "$BIND_ID"

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

def valid_wallet(w):
    return bool(re.fullmatch(r"[1-9A-HJ-NP-Za-km-z]{32,60}", w))

now = time.strftime("%Y-%m-%dT%H:%M:%S")

if not valid_wallet(WALLET):
    raise SystemExit(f"Invalid wallet format: {WALLET}")

state_path = ROOT / "blockchain/kibra_chain/mainnet/state/latest_state.json"
live_path = ROOT / "data/cybra_mainnet/live/internal_mainnet_live_state.json"
claims_path = ROOT / "data/cybra_mainnet/claims/mainnet_candidate_claim_registry.json"
pre_claims_path = ROOT / "data/cybra_mainnet/claims/latest_pre_mainnet_claims.json"
block1_path = ROOT / "blockchain/kibra_chain/mainnet/blocks/block_000001.json"

state = read_json(state_path, {})
live_state = read_json(live_path, state)
claim_registry = read_json(claims_path, {})
pre_claims = read_json(pre_claims_path, {})
block1 = read_json(block1_path, {})

balances = state.get("balances", {})
old_miner = "unknown_miner"

if old_miner in balances:
    old_balance = balances.pop(old_miner)
else:
    old_balance = {
        "pre_mainnet_claim_blocks": pre_claims.get("blocks_count", 60),
        "internal_candidate_credit": pre_claims.get("blocks_count", 60),
        "real_reward_now": 0,
        "claim_status": "REGISTERED_INTERNAL_MAINNET_TEST_ONLY"
    }

old_balance["wallet"] = WALLET
old_balance["previous_miner_id"] = old_miner
old_balance["claim_status"] = "WALLET_BOUND_INTERNAL_MAINNET_TEST_ONLY"
old_balance["real_reward_now"] = 0

balances[WALLET] = old_balance

registry = {
    "bind_id": BIND_ID,
    "timestamp": now,
    "status": "MINER_WALLET_BOUND",
    "network": state.get("network", "KIBRA_INTERNAL_MAINNET_TEST"),
    "chain_id": state.get("chain_id"),
    "previous_miner_id": old_miner,
    "wallet": WALLET,
    "pre_mainnet_claim_blocks": old_balance.get("pre_mainnet_claim_blocks", 0),
    "internal_candidate_credit": old_balance.get("internal_candidate_credit", 0),
    "real_reward_now": 0,
    "binding_scope": "INTERNAL_MAINNET_TEST_AND_MAINNET_CANDIDATE_CLAIM",
    "safety": {
        "real_payment_now": False,
        "automatic_external_tx": False,
        "automatic_withdrawals": False,
        "automatic_real_rewards": False,
        "wallet_binding_is_not_payout": True,
        "manual_OWNER_approval_required_for_external_live": True,
        "cyber_parliament_approval_required_for_external_live": True
    }
}

previous_hash = state.get("latest_block_hash") or block1.get("hash") or "0" * 64

binding_tx = {
    "tx_id": BIND_ID,
    "timestamp": now,
    "type": "MINER_WALLET_BINDING",
    "from": old_miner,
    "to_wallet": WALLET,
    "amount": 0,
    "external": False,
    "note": "Bind miner claim to wallet. No payout. No external transaction."
}

block2 = {
    "network": state.get("network", "KIBRA_INTERNAL_MAINNET_TEST"),
    "chain_id": state.get("chain_id"),
    "timestamp": now,
    "height": int(state.get("latest_height", 1)) + 1,
    "previous_hash": previous_hash,
    "status": "MINER_WALLET_BINDING_BLOCK",
    "miner": "cybra_internal_mainnet_miner",
    "transactions": [binding_tx],
    "wallet_binding": registry,
    "external_tx": False,
    "reward": {
        "internal_reward": 0,
        "real_reward": 0,
        "claim_only": True
    }
}
block2["hash"] = sha_obj(block2)

state["timestamp"] = now
state["latest_height"] = block2["height"]
state["latest_block_hash"] = block2["hash"]
state["blocks_count"] = int(state.get("blocks_count", 2)) + 1
state["balances"] = balances
state["last_wallet_binding"] = registry
state["external_live"] = False

live_state = state

claim_registry["timestamp"] = now
claim_registry["status"] = "PRE_MAINNET_CLAIMS_REGISTERED_WITH_WALLET_BINDING"
claim_registry["wallet_binding"] = registry
claim_registry["mainnet_rewards_now"] = 0

claim_items = claim_registry.get("claims", [])
if not claim_items:
    claim_items = [{
        "miner": old_miner,
        "test_blocks": old_balance.get("pre_mainnet_claim_blocks", 0),
        "claim_status": "PENDING_REVIEW",
        "mainnet_reward_now": 0
    }]

for item in claim_items:
    if item.get("miner") == old_miner or item.get("miner") == WALLET:
        item["previous_miner_id"] = old_miner
        item["miner"] = WALLET
        item["wallet"] = WALLET
        item["claim_status"] = "WALLET_BOUND_PENDING_FINAL_APPROVAL"
        item["mainnet_reward_now"] = 0

claim_registry["claims"] = claim_items

files = {
    "registry": ROOT / "data/cybra_mainnet/miners/miner_wallet_registry.json",
    "registry_latest": ROOT / f"data/cybra_mainnet/miners/{BIND_ID}.json",
    "claims": claims_path,
    "state": state_path,
    "live": live_path,
    "block2": ROOT / f"blockchain/kibra_chain/mainnet/blocks/block_{block2['height']:06d}.json",
    "report": ROOT / "data/cybra_mainnet/reports/miner_wallet_binding_latest.json",
    "feed": ROOT / "feeds/cybra_miner_wallet_binding.json",
    "post": ROOT / "posts/cybra_miner_wallet_binding.md"
}

write_json(files["registry"], registry)
write_json(files["registry_latest"], registry)
write_json(files["claims"], claim_registry)
write_json(files["state"], state)
write_json(files["live"], live_state)
write_json(files["block2"], block2)
write_json(files["report"], registry)
write_json(files["feed"], registry)

md = f"""# KIBRA Miner Wallet Binding

Status: **MINER_WALLET_BOUND**

Bind ID: `{BIND_ID}`

## Wallet

`{WALLET}`

## Previous miner ID

`{old_miner}`

## Claim

- Pre-mainnet claim blocks: `{old_balance.get("pre_mainnet_claim_blocks", 0)}`
- Internal candidate credit: `{old_balance.get("internal_candidate_credit", 0)}`
- Real reward now: `0`

## New internal block

- Height: `{block2["height"]}`
- Hash: `{block2["hash"]}`
- Previous hash: `{previous_hash}`

## Safety

- wallet binding is not payout: true
- real_payment_now: false
- automatic_external_tx: false
- automatic_withdrawals: false
- automatic_real_rewards: false
- OWNER approval required for external live: true
- Cyber Parliament approval required for external live: true
"""

files["post"].write_text(md, encoding="utf-8")

proof = ROOT / "proofs/cybra_miner_wallet_binding.sha256"
proof.write_text(
    "".join(
        f"{sha_file(p)}  {p.relative_to(ROOT)}\n"
        for p in [
            files["registry"],
            files["registry_latest"],
            files["claims"],
            files["state"],
            files["live"],
            files["block2"],
            files["report"],
            files["feed"],
            files["post"]
        ]
    ),
    encoding="utf-8"
)

print(json.dumps(registry, ensure_ascii=False, indent=2))
PY

cat > cybra-miner-wallet <<'EOF'
#!/usr/bin/env bash
cd "$HOME/CYBRA" || exit 1

case "$1" in
  status)
    cat posts/cybra_miner_wallet_binding.md
    ;;
  registry)
    cat data/cybra_mainnet/miners/miner_wallet_registry.json
    ;;
  claims)
    cat data/cybra_mainnet/claims/mainnet_candidate_claim_registry.json
    ;;
  state)
    cat blockchain/kibra_chain/mainnet/state/latest_state.json
    ;;
  proof)
    sha256sum -c proofs/cybra_miner_wallet_binding.sha256
    ;;
  *)
    echo "Commands:"
    echo "  cybra-miner-wallet status"
    echo "  cybra-miner-wallet registry"
    echo "  cybra-miner-wallet claims"
    echo "
EOF

# repair cybra-miner-wallet command, бо попередній EOF міг обірватися
cat > cybra-miner-wallet <<'EOF'
#!/usr/bin/env bash
cd "$HOME/CYBRA" || exit 1

case "$1" in
  status)
    cat posts/cybra_miner_wallet_binding.md
    ;;
  registry)
    cat data/cybra_mainnet/miners/miner_wallet_registry.json
    ;;
  claims)
    cat data/cybra_mainnet/claims/mainnet_candidate_claim_registry.json
    ;;
  state)
    cat blockchain/kibra_chain/mainnet/state/latest_state.json
    ;;
  proof)
    sha256sum -c proofs/cybra_miner_wallet_binding.sha256
    ;;
  *)
    echo "Commands:"
    echo "  cybra-miner-wallet status"
    echo "  cybra-miner-wallet registry"
    echo "  cybra-miner-wallet claims"
    echo "  cybra-miner-wallet state"
    echo "  cybra-miner-wallet proof"
    ;;
esac
EOF

chmod +x cybra-miner-wallet
ln -sf "$HOME/CYBRA/cybra-miner-wallet" "$PREFIX/bin/cybra-miner-wallet" 2>/dev/null || true

echo
echo "=== CHECK ==="
cybra-miner-wallet status
echo
cybra-miner-wallet proof
echo
echo "✅ WALLET BINDING DONE"
