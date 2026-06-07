#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== FINISH KIBRA MAINNET READINESS ==="

WALLET="${1:-FesrWxqM67HrjFqsCoCHsUkRocZZBgWeg4P3T4b9FD9Y}"
TS="$(date +%Y%m%d_%H%M%S)"
FINAL_ID="KIBRA-MAINNET-READINESS-${TS}"

mkdir -p \
  data/cybra_mainnet/{audit,miners,claims,reports,manifests,live} \
  blockchain/kibra_chain/mainnet/blocks \
  blockchain/kibra_chain/mainnet/state \
  dashboard/kibra_mainnet \
  posts feeds proofs logs/mainnet

python3 - <<PY
import json, time, hashlib, re, html, subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"
WALLET = "$WALLET"
FINAL_ID = "$FINAL_ID"

def read_json(path, default=None):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except Exception:
        return default if default is not None else {}

def write_json(path, data):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

def obj_hash(obj):
    clean = dict(obj)
    clean.pop("hash", None)
    return hashlib.sha256(json.dumps(clean, ensure_ascii=False, sort_keys=True).encode()).hexdigest()

def file_hash(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def valid_wallet(w):
    return bool(re.fullmatch(r"[1-9A-HJ-NP-Za-km-z]{32,60}", w))

now = time.strftime("%Y-%m-%dT%H:%M:%S")

if not valid_wallet(WALLET):
    raise SystemExit(f"Invalid wallet: {WALLET}")

state_path = ROOT / "blockchain/kibra_chain/mainnet/state/latest_state.json"
live_path = ROOT / "data/cybra_mainnet/live/internal_mainnet_live_state.json"
genesis_path = ROOT / "blockchain/kibra_chain/mainnet/genesis.json"
claims_path = ROOT / "data/cybra_mainnet/claims/mainnet_candidate_claim_registry.json"
pre_claims_path = ROOT / "data/cybra_mainnet/claims/latest_pre_mainnet_claims.json"
registry_path = ROOT / "data/cybra_mainnet/miners/miner_wallet_registry.json"

state = read_json(state_path, {})
genesis = read_json(genesis_path, {})
claims = read_json(claims_path, {})
pre_claims = read_json(pre_claims_path, {})
registry = read_json(registry_path, {})

blocks_count_from_snapshot = (
    state.get("test_blocks_snapshot_count")
    or pre_claims.get("blocks_count")
    or 60
)

balances = state.get("balances", {})
binding_needed = WALLET not in balances

old_balance = None
if "unknown_miner" in balances:
    old_balance = balances.pop("unknown_miner")
elif WALLET in balances:
    old_balance = balances[WALLET]
else:
    old_balance = {
        "pre_mainnet_claim_blocks": blocks_count_from_snapshot,
        "internal_candidate_credit": blocks_count_from_snapshot,
        "real_reward_now": 0,
        "claim_status": "REGISTERED_INTERNAL_MAINNET_TEST_ONLY"
    }

old_balance["wallet"] = WALLET
old_balance["previous_miner_id"] = old_balance.get("previous_miner_id", "unknown_miner")
old_balance["claim_status"] = "WALLET_BOUND_INTERNAL_MAINNET_TEST_ONLY"
old_balance["real_reward_now"] = 0
balances[WALLET] = old_balance

registry = {
    "final_id": FINAL_ID,
    "timestamp": now,
    "status": "MINER_WALLET_BOUND_AND_VALIDATED",
    "wallet": WALLET,
    "previous_miner_id": old_balance.get("previous_miner_id", "unknown_miner"),
    "network": state.get("network", "KIBRA_INTERNAL_MAINNET_TEST"),
    "chain_id": state.get("chain_id"),
    "pre_mainnet_claim_blocks": old_balance.get("pre_mainnet_claim_blocks", 0),
    "internal_candidate_credit": old_balance.get("internal_candidate_credit", 0),
    "real_reward_now": 0,
    "binding_scope": "INTERNAL_MAINNET_TEST_AND_MAINNET_CANDIDATE_CLAIM",
    "safety": {
        "wallet_binding_is_not_payout": True,
        "real_payment_now": False,
        "automatic_external_tx": False,
        "automatic_withdrawals": False,
        "automatic_real_rewards": False,
        "external_live": False,
        "manual_OWNER_approval_required_for_external_live": True,
        "cyber_parliament_approval_required_for_external_live": True
    }
}

# Якщо binding block ще потрібен — створюємо новий внутрішній блок.
if binding_needed or state.get("last_wallet_binding", {}).get("wallet") != WALLET:
    previous_hash = state.get("latest_block_hash") or genesis.get("hash") or "0" * 64
    height = int(state.get("latest_height", 1) or 1) + 1

    binding_block = {
        "network": state.get("network", "KIBRA_INTERNAL_MAINNET_TEST"),
        "chain_id": state.get("chain_id"),
        "timestamp": now,
        "height": height,
        "previous_hash": previous_hash,
        "status": "MINER_WALLET_BINDING_VALIDATION_BLOCK",
        "miner": "cybra_internal_mainnet_validator",
        "transactions": [
            {
                "tx_id": FINAL_ID,
                "type": "MINER_WALLET_BINDING_VALIDATION",
                "from": registry["previous_miner_id"],
                "to_wallet": WALLET,
                "amount": 0,
                "external": False,
                "note": "Wallet binding validation only. No payout."
            }
        ],
        "wallet_binding": registry,
        "external_tx": False,
        "reward": {
            "internal_reward": 0,
            "real_reward": 0,
            "claim_only": True
        }
    }
    binding_block["hash"] = obj_hash(binding_block)

    block_path = ROOT / f"blockchain/kibra_chain/mainnet/blocks/block_{height:06d}.json"
    write_json(block_path, binding_block)

    state["latest_height"] = height
    state["latest_block_hash"] = binding_block["hash"]
    state["blocks_count"] = max(int(state.get("blocks_count", 2) or 2), height + 1)
else:
    block_path = None

state["timestamp"] = now
state["balances"] = balances
state["last_wallet_binding"] = registry
state["external_live"] = False

state.setdefault("safety", {})
state["safety"].update({
    "real_payment_now": False,
    "real_trading_now": False,
    "automatic_SWIFT": False,
    "automatic_external_tx": False,
    "automatic_withdrawals": False,
    "automatic_real_rewards": False,
    "external_bridge_enabled": False,
    "bank_live_mode": False,
    "psp_live_mode": False
})

claims.setdefault("claims", [])
if not claims["claims"]:
    claims["claims"] = [{
        "miner": WALLET,
        "wallet": WALLET,
        "test_blocks": old_balance.get("pre_mainnet_claim_blocks", 0),
        "claim_status": "WALLET_BOUND_PENDING_FINAL_APPROVAL",
        "mainnet_reward_now": 0
    }]

for item in claims["claims"]:
    item["previous_miner_id"] = item.get("previous_miner_id", "unknown_miner")
    item["miner"] = WALLET
    item["wallet"] = WALLET
    item["claim_status"] = "WALLET_BOUND_PENDING_FINAL_APPROVAL"
    item["mainnet_reward_now"] = 0

claims["timestamp"] = now
claims["status"] = "PRE_MAINNET_CLAIMS_WALLET_BOUND_VALIDATED"
claims["wallet_binding"] = registry
claims["mainnet_rewards_now"] = 0

write_json(state_path, state)
write_json(live_path, state)
write_json(claims_path, claims)
write_json(registry_path, registry)
write_json(ROOT / f"data/cybra_mainnet/miners/{FINAL_ID}.json", registry)

# Chain validation
block_files = sorted((ROOT / "blockchain/kibra_chain/mainnet/blocks").glob("block_*.json"))
chain_links_ok = True
hashes_ok = True

prev_hash = genesis.get("hash")
if genesis:
    hashes_ok = hashes_ok and (genesis.get("hash") == obj_hash(genesis))

for bf in block_files:
    b = read_json(bf, {})
    if b.get("previous_hash") != prev_hash:
        chain_links_ok = False
    if b.get("hash") != obj_hash(b):
        hashes_ok = False
    prev_hash = b.get("hash")

wallet_in_state = WALLET in state.get("balances", {})
unknown_removed = "unknown_miner" not in state.get("balances", {})
claim_wallet_ok = any(
    item.get("wallet") == WALLET or item.get("miner") == WALLET
    for item in claims.get("claims", [])
)

claim_wallets = [item.get("wallet") or item.get("miner") for item in claims.get("claims", [])]
duplicates = sorted({w for w in claim_wallets if w and claim_wallets.count(w) > 1})

anti_sybil = {
    "timestamp": now,
    "status": "ANTI_SYBIL_PASS" if not duplicates and wallet_in_state else "ANTI_SYBIL_REVIEW_REQUIRED",
    "wallet": WALLET,
    "duplicates": duplicates,
    "claims_count": len(claims.get("claims", [])),
    "unique_wallets_count": len(set(claim_wallets)),
    "manual_review_required_before_external_live": True
}

proof_checks = {}
for pf in [
    "proofs/cybra_internal_mainnet_test.sha256",
    "proofs/cybra_miner_wallet_binding.sha256",
    "proofs/kibra_wallet_binding_manifest.sha256",
    "proofs/cybra_mainnet_migration_test.sha256"
]:
    p = ROOT / pf
    if p.exists():
        r = subprocess.run(f"sha256sum -c {pf}", shell=True, cwd=ROOT, text=True, capture_output=True)
        proof_checks[pf] = (r.returncode == 0)
    else:
        proof_checks[pf] = "MISSING_OPTIONAL"

tests = {
    "wallet_format_ok": valid_wallet(WALLET),
    "mainnet_state_exists": state_path.exists(),
    "genesis_exists": genesis_path.exists(),
    "blocks_exist": len(block_files) >= 1,
    "genesis_hash_ok": bool(genesis.get("hash")) and genesis.get("hash") == obj_hash(genesis),
    "block_hashes_ok": hashes_ok,
    "chain_links_ok": chain_links_ok,
    "wallet_in_state": wallet_in_state,
    "unknown_miner_removed": unknown_removed,
    "claim_wallet_ok": claim_wallet_ok,
    "anti_sybil_pass": anti_sybil["status"] == "ANTI_SYBIL_PASS",
    "no_real_reward": all(v.get("real_reward_now") == 0 for v in state.get("balances", {}).values()),
    "no_external_live": state.get("external_live") is False,
    "no_external_tx": state.get("safety", {}).get("automatic_external_tx") is False,
    "no_withdrawals": state.get("safety", {}).get("automatic_withdrawals") is False,
    "no_swift": state.get("safety", {}).get("automatic_SWIFT") is False
}

score = round(sum(1 for v in tests.values() if v is True) / len(tests) * 100, 2)

final_report = {
    "final_id": FINAL_ID,
    "timestamp": now,
    "status": "KIBRA_MAINNET_INTERNAL_READY" if score == 100 else "KIBRA_MAINNET_INTERNAL_PARTIAL",
    "score_percent": score,
    "wallet": WALLET,
    "network": state.get("network"),
    "chain_id": state.get("chain_id"),
    "latest_height": state.get("latest_height"),
    "latest_block_hash": state.get("latest_block_hash"),
    "genesis_hash": genesis.get("hash"),
    "pre_mainnet_claim_blocks": old_balance.get("pre_mainnet_claim_blocks", 0),
    "internal_candidate_credit": old_balance.get("internal_candidate_credit", 0),
    "real_reward_now": 0,
    "tests": tests,
    "proof_checks": proof_checks,
    "anti_sybil": anti_sybil,
    "external_live_ready": False,
    "external_live_status": "LOCKED_UNTIL_OWNER_AND_CYBER_PARLIAMENT_FINAL_APPROVAL",
    "safety": state.get("safety", {})
}

files = {
    "anti_sybil": ROOT / "data/cybra_mainnet/audit/anti_sybil_latest.json",
    "final": ROOT / "data/cybra_mainnet/audit/final_readiness_latest.json",
    "manifest": ROOT / "data/cybra_mainnet/manifests/kibra_final_manifest_latest.json",
    "report": ROOT / "data/cybra_mainnet/reports/kibra_mainnet_final_readiness_latest.json",
    "feed": ROOT / "feeds/kibra_mainnet_final_readiness.json",
    "post": ROOT / "posts/kibra_mainnet_final_readiness.md",
    "html": ROOT / "dashboard/kibra_mainnet/final.html"
}

for p, data in [
    (files["anti_sybil"], anti_sybil),
    (files["final"], final_report),
    (files["manifest"], final_report),
    (files["report"], final_report),
    (files["feed"], final_report),
]:
    write_json(p, data)

md = f"""# KIBRA Mainnet Final Readiness

Status: **{final_report["status"]}**

Score: **{score}%**

## Wallet

`{WALLET}`

## Network

- Network: `{state.get("network")}`
- Chain ID: `{state.get("chain_id")}`
- Latest height: `{state.get("latest_height")}`
- Latest block hash: `{state.get("latest_block_hash")}`
- Genesis hash: `{genesis.get("hash")}`

## Claim

- Pre-mainnet claim blocks: `{old_balance.get("pre_mainnet_claim_blocks", 0)}`
- Internal candidate credit: `{old_balance.get("internal_candidate_credit", 0)}`
- Real reward now: `0`

## Tests

- wallet_in_state: `{wallet_in_state}`
- unknown_miner_removed: `{unknown_removed}`
- chain_links_ok: `{chain_links_ok}`
- block_hashes_ok: `{hashes_ok}`
- anti_sybil: `{anti_sybil["status"]}`

## External live

`LOCKED_UNTIL_OWNER_AND_CYBER_PARLIAMENT_FINAL_APPROVAL`

## Safety

- real_payment_now: false
- automatic_external_tx: false
- automatic_withdrawals: false
- automatic_SWIFT: false
- automatic_real_rewards: false
- external_bridge_enabled: false
"""

files["post"].write_text(md, encoding="utf-8")

page = f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>KIBRA Mainnet Final Readiness</title>
<style>
body {{ font-family: system-ui, sans-serif; max-width: 980px; margin: 40px auto; padding: 20px; }}
.card {{ border: 1px solid #ddd; border-radius: 16px; padding: 20px; margin: 16px 0; }}
code {{ word-break: break-all; }}
.ok {{ font-weight: 700; }}
</style>
</head>
<body>
<h1>KIBRA Mainnet Final Readiness</h1>
<div class="card">
<p class="ok">Status: {html.escape(final_report["status"])}</p>
<p>Score: <code>{score}%</code></p>
</div>
<div class="card">
<p>Wallet:</p>
<code>{html.escape(WALLET)}</code>
</div>
<div class="card">
<p>Network: <code>{html.escape(str(state.get("network")))}</code></p>
<p>Chain ID: <code>{html.escape(str(state.get("chain_id")))}</code></p>
<p>Latest height: <code>{html.escape(str(state.get("latest_height")))}</code></p>
<p>Latest block hash: <code>{html.escape(str(state.get("latest_block_hash")))}</code></p>
<p>Genesis hash: <code>{html.escape(str(genesis.get("hash")))}</code></p>
</div>
<div class="card">
<p>Claim blocks: <code>{old_balance.get("pre_mainnet_claim_blocks", 0)}</code></p>
<p>Internal candidate credit: <code>{old_balance.get("internal_candidate_credit", 0)}</code></p>
<p>Real reward now: <code>0</code></p>
</div>
<div class="card">
<p>External live: <code>LOCKED</code></p>
<p>No withdrawals, no SWIFT, no automatic external transaction.</p>
</div>
</body>
</html>
"""
files["html"].write_text(page, encoding="utf-8")

proof = ROOT / "proofs/kibra_mainnet_final_readiness.sha256"
proof_targets = [
    state_path,
    live_path,
    claims_path,
    registry_path,
    files["anti_sybil"],
    files["final"],
    files["manifest"],
    files["report"],
    files["feed"],
    files["post"],
    files["html"],
]
if block_path:
    proof_targets.append(block_path)

proof.write_text(
    "".join(f"{file_hash(p)}  {p.relative_to(ROOT)}\n" for p in proof_targets if p.exists()),
    encoding="utf-8"
)

print(json.dumps(final_report, ensure_ascii=False, indent=2))
PY

cat > cybra-kibra-final <<'EOF'
#!/usr/bin/env bash
cd "$HOME/CYBRA" || exit 1

case "$1" in
  status)
    cat posts/kibra_mainnet_final_readiness.md
    ;;
  json)
    cat data/cybra_mainnet/audit/final_readiness_latest.json
    ;;
  wallet)
    cat data/cybra_mainnet/miners/miner_wallet_registry.json
    ;;
  claims)
    cat data/cybra_mainnet/claims/mainnet_candidate_claim_registry.json
    ;;
  state)
    cat blockchain/kibra_chain/mainnet/state/latest_state.json
    ;;
  anti-sybil)
    cat data/cybra_mainnet/audit/anti_sybil_latest.json
    ;;
  dashboard)
    echo "Open local file:"
    echo "  dashboard/kibra_mainnet/final.html"
    ;;
  serve)
    python3 -m http.server 8791 --bind 127.0.0.1 --directory dashboard/kibra_mainnet
    ;;
  proof)
    sha256sum -c proofs/kibra_mainnet_final_readiness.sha256
    ;;
  *)
    echo "Commands:"
    echo "  cybra-kibra-final status"
    echo "  cybra-kibra-final json"
    echo "  cybra-kibra-final wallet"
    echo "  cybra-kibra-final claims"
    echo "  cybra-kibra-final state"
    echo "  cybra-kibra-final anti-sybil"
    echo "  cybra-kibra-final dashboard"
    echo "  cybra-kibra-final serve"
    echo "  cybra-kibra-final proof"
    ;;
esac
EOF

chmod +x cybra-kibra-final
ln -sf "$HOME/CYBRA/cybra-kibra-final" "$PREFIX/bin/cybra-kibra-final" 2>/dev/null || true

echo
echo "=== FINAL CHECK ==="
cybra-kibra-final status
echo
cybra-kibra-final proof
echo
echo "✅ KIBRA MAINNET READINESS FINISHED"
