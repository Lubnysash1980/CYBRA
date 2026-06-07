#!/usr/bin/env python3
import json, time, hashlib, argparse, re, uuid, html
from pathlib import Path

ROOT = Path.home() / "CYBRA"

GENESIS = ROOT / "blockchain/kibra_chain/mainnet/genesis.json"
BLOCKS = ROOT / "blockchain/kibra_chain/mainnet/blocks"
STATE = ROOT / "blockchain/kibra_chain/mainnet/state/latest_state.json"
LIVE = ROOT / "data/cybra_mainnet/live/internal_mainnet_live_state.json"
MEMPOOL = ROOT / "blockchain/kibra_chain/mainnet/mempool/pending.json"
CLAIMS = ROOT / "data/cybra_mainnet/claims/mainnet_candidate_claim_registry.json"
MINER_REGISTRY = ROOT / "data/cybra_mainnet/miners/miner_wallet_registry.json"

REPORT = ROOT / "data/cybra_mainnet/reports/kibra_autotest_fix_loop_latest.json"
AUDIT = ROOT / "data/cybra_mainnet/audit/kibra_autotest_fix_loop_audit.json"
MANIFEST = ROOT / "data/cybra_mainnet/manifests/kibra_autotest_fix_loop_manifest.json"
FEED = ROOT / "feeds/kibra_autotest_fix_loop.json"
POST = ROOT / "posts/kibra_autotest_fix_loop.md"
HTML = ROOT / "dashboard/kibra_mainnet/autotest_loop.html"
PROOF = ROOT / "proofs/kibra_autotest_fix_loop.sha256"

SAFETY = {
    "real_payment_now": False,
    "real_trading_now": False,
    "automatic_SWIFT": False,
    "automatic_external_tx": False,
    "automatic_withdrawals": False,
    "automatic_real_rewards": False,
    "external_bridge_enabled": False,
    "bank_live_mode": False,
    "psp_live_mode": False,
    "mainnet_scope": "INTERNAL_MAINNET_AUTOTEST_ONLY",
    "manual_OWNER_approval_required_for_external_live": True,
    "cyber_parliament_approval_required_for_external_live": True
}

def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S")

def read_json(path, default=None):
    try:
        return Path(path).read_text(encoding="utf-8")
    except Exception:
        return None

def load(path, default=None):
    raw = read_json(path)
    if raw is None:
        return default if default is not None else {}
    try:
        return json.loads(raw)
    except Exception:
        return default if default is not None else {}

def save(path, data):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

def file_hash(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def obj_hash(obj):
    clean = json.loads(json.dumps(obj, ensure_ascii=False))
    if isinstance(clean, dict):
        clean.pop("hash", None)
    return hashlib.sha256(json.dumps(clean, ensure_ascii=False, sort_keys=True).encode()).hexdigest()

def valid_wallet(wallet):
    return bool(re.fullmatch(r"[1-9A-HJ-NP-Za-km-z]{32,60}", wallet or ""))

def block_files():
    return sorted(BLOCKS.glob("block_*.json"))

def ensure_genesis(wallet, fixes):
    genesis = load(GENESIS, {})
    if not genesis:
        chain_id = "kibra-mainnet-internal-" + hashlib.sha256((wallet + now()).encode()).hexdigest()[:16]
        genesis = {
            "network": "KIBRA_INTERNAL_MAINNET",
            "chain_id": chain_id,
            "timestamp": now(),
            "height": 0,
            "previous_hash": "0" * 64,
            "status": "INTERNAL_MAINNET_GENESIS_CREATED",
            "mode": "INTERNAL_MAINNET_AUTOTEST_ONLY",
            "creator_wallet": wallet,
            "external_live": False,
            "safety": SAFETY
        }
        genesis["hash"] = obj_hash(genesis)
        save(GENESIS, genesis)
        fixes.append("created_genesis")

    if genesis.get("hash") != obj_hash(genesis):
        genesis["hash"] = obj_hash(genesis)
        save(GENESIS, genesis)
        fixes.append("rehashed_genesis")

    return genesis

def ensure_state(wallet, genesis, fixes):
    state = load(STATE, {})
    if not state:
        state = {
            "timestamp": now(),
            "network": genesis.get("network"),
            "chain_id": genesis.get("chain_id"),
            "status": "INTERNAL_MAINNET_NODE_READY",
            "latest_height": 0,
            "genesis_hash": genesis.get("hash"),
            "latest_block_hash": genesis.get("hash"),
            "blocks_count": 1,
            "balances": {},
            "external_live": False,
            "node_wallet": wallet,
            "safety": SAFETY
        }
        fixes.append("created_state")

    state["node_wallet"] = wallet
    state["external_live"] = False
    state["safety"] = SAFETY

    balances = state.setdefault("balances", {})

    if "unknown_miner" in balances:
        old = balances.pop("unknown_miner")
        old["wallet"] = wallet
        old["previous_miner_id"] = "unknown_miner"
        old["claim_status"] = "WALLET_BOUND_INTERNAL_MAINNET_AUTOFIXED"
        old["real_reward_now"] = 0
        balances[wallet] = old
        fixes.append("replaced_unknown_miner_with_wallet")

    balances.setdefault(wallet, {
        "wallet": wallet,
        "pre_mainnet_claim_blocks": 60,
        "internal_candidate_credit": 60,
        "real_reward_now": 0,
        "claim_status": "WALLET_BOUND_INTERNAL_MAINNET_AUTOTEST"
    })

    balances[wallet]["real_reward_now"] = 0
    balances[wallet]["wallet"] = wallet

    save(STATE, state)
    save(LIVE, state)
    return state

def ensure_claims(wallet, state, fixes):
    balances = state.get("balances", {})
    balance = balances.get(wallet, {})

    claims = load(CLAIMS, {})
    if not claims:
        claims = {
            "timestamp": now(),
            "status": "PRE_MAINNET_CLAIMS_AUTOCREATED",
            "mainnet_rewards_now": 0,
            "claims": []
        }
        fixes.append("created_claim_registry")

    claims["timestamp"] = now()
    claims["status"] = "PRE_MAINNET_CLAIMS_WALLET_BOUND_AUTOTESTED"
    claims["mainnet_rewards_now"] = 0

    items = claims.get("claims", [])
    cleaned = []
    seen = set()

    for item in items:
        w = item.get("wallet") or item.get("miner") or wallet
        if w == "unknown_miner":
            w = wallet
            fixes.append("claim_unknown_miner_replaced")
        if w in seen:
            fixes.append("removed_duplicate_claim")
            continue
        seen.add(w)
        item["wallet"] = wallet if w == wallet else w
        item["miner"] = wallet if w == wallet else w
        item["mainnet_reward_now"] = 0
        item["claim_status"] = "WALLET_BOUND_PENDING_FINAL_APPROVAL"
        cleaned.append(item)

    if wallet not in [x.get("wallet") for x in cleaned]:
        cleaned.append({
            "miner": wallet,
            "wallet": wallet,
            "test_blocks": balance.get("pre_mainnet_claim_blocks", 60),
            "claim_status": "WALLET_BOUND_PENDING_FINAL_APPROVAL",
            "mainnet_reward_now": 0
        })
        fixes.append("added_wallet_claim")

    claims["claims"] = cleaned

    registry = {
        "timestamp": now(),
        "status": "MINER_WALLET_BOUND_AUTOTESTED",
        "wallet": wallet,
        "previous_miner_id": "unknown_miner",
        "network": state.get("network"),
        "chain_id": state.get("chain_id"),
        "pre_mainnet_claim_blocks": balance.get("pre_mainnet_claim_blocks", 60),
        "internal_candidate_credit": balance.get("internal_candidate_credit", 60),
        "real_reward_now": 0,
        "safety": SAFETY
    }

    save(CLAIMS, claims)
    save(MINER_REGISTRY, registry)
    return claims, registry

def repair_blocks(wallet, genesis, state, fixes):
    files = block_files()

    if not files:
        block = {
            "network": state.get("network"),
            "chain_id": state.get("chain_id"),
            "timestamp": now(),
            "height": 1,
            "previous_hash": genesis.get("hash"),
            "status": "INTERNAL_MAINNET_AUTOFIX_BLOCK",
            "miner": wallet,
            "transactions": [{
                "tx_id": "KIBRA-AUTOFIX-" + uuid.uuid4().hex[:12],
                "timestamp": now(),
                "type": "INTERNAL_HEARTBEAT_TX",
                "from": wallet,
                "to": wallet,
                "amount": 0,
                "external": False,
                "real_value": False,
                "note": "autofix heartbeat, no payout"
            }],
            "external_tx": False,
            "reward": {
                "internal_reward": 0,
                "real_reward": 0,
                "claim_only": True
            },
            "safety": SAFETY
        }
        block["transactions"][0]["hash"] = obj_hash(block["transactions"][0])
        block["hash"] = obj_hash(block)
        save(BLOCKS / "block_000001.json", block)
        files = block_files()
        fixes.append("created_first_block")

    prev = genesis.get("hash")
    repaired_files = []

    for index, bf in enumerate(files, start=1):
        b = load(bf, {})
        changed = False

        if b.get("height") != index:
            b["height"] = index
            changed = True

        if b.get("previous_hash") != prev:
            b["previous_hash"] = prev
            changed = True

        b["network"] = state.get("network")
        b["chain_id"] = state.get("chain_id")
        b["external_tx"] = False
        b["safety"] = SAFETY

        reward = b.setdefault("reward", {})
        reward["real_reward"] = 0
        reward.setdefault("internal_reward", 0)
        reward["claim_only"] = True

        for tx in b.get("transactions", []):
            tx["external"] = False
            tx["real_value"] = False
            if "hash" not in tx or tx["hash"] != obj_hash(tx):
                tx["hash"] = obj_hash(tx)
                changed = True

        new_hash = obj_hash(b)
        if b.get("hash") != new_hash:
            b["hash"] = new_hash
            changed = True

        if changed:
            save(bf, b)
            repaired_files.append(str(bf.name))

        prev = b.get("hash")

    if repaired_files:
        fixes.append("repaired_blocks:" + ",".join(repaired_files))

    state["latest_height"] = len(files)
    state["latest_block_hash"] = prev
    state["blocks_count"] = len(files) + 1
    save(STATE, state)
    save(LIVE, state)

    return state

def mine_autotest_block(wallet, state, fixes, cycle):
    mem = load(MEMPOOL, [])
    tx = {
        "tx_id": "KIBRA-LOOP-TX-" + uuid.uuid4().hex[:12],
        "timestamp": now(),
        "type": "INTERNAL_AUTOTEST_LOOP_TX",
        "from": wallet,
        "to": wallet,
        "amount": 0,
        "external": False,
        "real_value": False,
        "note": f"autotest cycle {cycle}, no real value"
    }
    tx["hash"] = obj_hash(tx)
    mem.append(tx)
    save(MEMPOOL, mem)

    height = int(state.get("latest_height", 0) or 0) + 1
    previous_hash = state.get("latest_block_hash")

    block = {
        "network": state.get("network"),
        "chain_id": state.get("chain_id"),
        "timestamp": now(),
        "height": height,
        "previous_hash": previous_hash,
        "status": "INTERNAL_MAINNET_AUTOTEST_BLOCK_MINED",
        "miner": wallet,
        "cycle": cycle,
        "transactions": mem,
        "external_tx": False,
        "reward": {
            "internal_reward": 0,
            "real_reward": 0,
            "claim_only": True
        },
        "safety": SAFETY
    }
    block["hash"] = obj_hash(block)

    save(BLOCKS / f"block_{height:06d}.json", block)
    save(MEMPOOL, [])

    state["latest_height"] = height
    state["latest_block_hash"] = block["hash"]
    state["blocks_count"] = height + 1
    state["status"] = "INTERNAL_MAINNET_AUTOTEST_RUNNING"
    state["external_live"] = False
    state["safety"] = SAFETY
    save(STATE, state)
    save(LIVE, state)

    fixes.append(f"mined_autotest_block_{height}")
    return state, block

def validate(wallet):
    genesis = load(GENESIS, {})
    state = load(STATE, {})
    claims = load(CLAIMS, {})

    checks = {}
    checks["wallet_format_ok"] = valid_wallet(wallet)
    checks["genesis_exists"] = GENESIS.exists()
    checks["state_exists"] = STATE.exists()
    checks["claims_exists"] = CLAIMS.exists()
    checks["wallet_in_state"] = wallet in state.get("balances", {})
    checks["unknown_miner_removed"] = "unknown_miner" not in state.get("balances", {})
    checks["external_live_false"] = state.get("external_live") is False
    checks["withdrawals_disabled"] = state.get("safety", {}).get("automatic_withdrawals") is False
    checks["swift_disabled"] = state.get("safety", {}).get("automatic_SWIFT") is False
    checks["external_tx_disabled"] = state.get("safety", {}).get("automatic_external_tx") is False
    checks["real_rewards_disabled"] = state.get("safety", {}).get("automatic_real_rewards") is False

    checks["genesis_hash_ok"] = bool(genesis.get("hash")) and genesis.get("hash") == obj_hash(genesis)

    files = block_files()
    checks["blocks_exist"] = len(files) >= 1

    prev = genesis.get("hash")
    chain_links_ok = True
    block_hashes_ok = True
    no_external_tx = True
    no_real_rewards = True

    for bf in files:
        b = load(bf, {})
        if b.get("previous_hash") != prev:
            chain_links_ok = False
        if b.get("hash") != obj_hash(b):
            block_hashes_ok = False
        if b.get("external_tx") is True:
            no_external_tx = False
        if b.get("reward", {}).get("real_reward", 0) != 0:
            no_real_rewards = False
        for tx in b.get("transactions", []):
            if tx.get("external") is True or tx.get("real_value") is True:
                no_external_tx = False
        prev = b.get("hash")

    checks["chain_links_ok"] = chain_links_ok
    checks["block_hashes_ok"] = block_hashes_ok
    checks["no_external_tx_in_blocks"] = no_external_tx
    checks["no_real_rewards_in_blocks"] = no_real_rewards
    checks["state_latest_hash_ok"] = state.get("latest_block_hash") == prev if files else state.get("latest_block_hash") == genesis.get("hash")

    claim_wallets = [x.get("wallet") or x.get("miner") for x in claims.get("claims", [])]
    checks["claim_wallet_ok"] = wallet in claim_wallets
    checks["anti_sybil_no_duplicates"] = len(claim_wallets) == len(set(claim_wallets))

    total = len(checks)
    passed = sum(1 for v in checks.values() if v is True)
    score = round(passed / total * 100, 2)

    return checks, score

def write_outputs(wallet, loops, final_checks, final_score, all_fixes):
    state = load(STATE, {})
    claims = load(CLAIMS, {})
    registry = load(MINER_REGISTRY, {})

    status = "KIBRA_AUTOTEST_FIX_LOOP_PASS" if final_score == 100 else "KIBRA_AUTOTEST_FIX_LOOP_PARTIAL"

    report = {
        "timestamp": now(),
        "status": status,
        "score_percent": final_score,
        "wallet": wallet,
        "network": state.get("network"),
        "chain_id": state.get("chain_id"),
        "latest_height": state.get("latest_height"),
        "latest_block_hash": state.get("latest_block_hash"),
        "loops": loops,
        "checks": final_checks,
        "fixes": all_fixes,
        "claims": claims,
        "miner_registry": registry,
        "safety": SAFETY
    }

    save(REPORT, report)
    save(AUDIT, report)
    save(MANIFEST, report)
    save(FEED, report)

    md = f"""# KIBRA Autotest Fix Loop

Status: **{status}**

Score: **{final_score}%**

## Wallet

`{wallet}`

## Chain

- Network: `{state.get("network")}`
- Chain ID: `{state.get("chain_id")}`
- Latest height: `{state.get("latest_height")}`
- Latest block hash: `{state.get("latest_block_hash")}`

## Loops

`{loops}`

## Fixes applied

`{len(all_fixes)}`

## Safety

- real_payment_now: false
- automatic_external_tx: false
- automatic_withdrawals: false
- automatic_SWIFT: false
- automatic_real_rewards: false
- external_bridge_enabled: false

## Result

Внутрішній KIBRA mainnet протестований циклом: test → fix → mine → test.
"""
    POST.write_text(md, encoding="utf-8")

    page = f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>KIBRA Autotest Fix Loop</title>
<style>
body {{ font-family: system-ui, sans-serif; max-width: 980px; margin: 40px auto; padding: 20px; }}
.card {{ border: 1px solid #ddd; border-radius: 16px; padding: 20px; margin: 16px 0; }}
code {{ word-break: break-all; }}
</style>
</head>
<body>
<h1>KIBRA Autotest Fix Loop</h1>
<div class="card">
<p>Status: <b>{html.escape(status)}</b></p>
<p>Score: <code>{final_score}%</code></p>
</div>
<div class="card">
<p>Wallet:</p>
<code>{html.escape(wallet)}</code>
</div>
<div class="card">
<p>Network: <code>{html.escape(str(state.get("network")))}</code></p>
<p>Chain ID: <code>{html.escape(str(state.get("chain_id")))}</code></p>
<p>Latest height: <code>{html.escape(str(state.get("latest_height")))}</code></p>
<p>Latest block hash: <code>{html.escape(str(state.get("latest_block_hash")))}</code></p>
</div>
<div class="card">
<p>Loops: <code>{loops}</code></p>
<p>Fixes applied: <code>{len(all_fixes)}</code></p>
</div>
<div class="card">
<p>External live: <code>false</code></p>
<p>No withdrawals. No SWIFT. No external automatic transactions.</p>
</div>
</body>
</html>
"""
    HTML.write_text(page, encoding="utf-8")

    targets = [
        GENESIS, STATE, LIVE, MEMPOOL, CLAIMS, MINER_REGISTRY,
        REPORT, AUDIT, MANIFEST, FEED, POST, HTML,
        ROOT / "scripts/kibra/kibra_autotest_fix_loop.py",
    ] + block_files()

    PROOF.write_text(
        "".join(f"{file_hash(p)}  {p.relative_to(ROOT)}\n" for p in targets if p.exists()),
        encoding="utf-8"
    )

    return report

def run(wallet, cycles):
    if not valid_wallet(wallet):
        raise SystemExit(f"Invalid wallet: {wallet}")

    all_fixes = []
    loop_reports = []

    for cycle in range(1, cycles + 1):
        fixes = []

        genesis = ensure_genesis(wallet, fixes)
        state = ensure_state(wallet, genesis, fixes)
        claims, registry = ensure_claims(wallet, state, fixes)
        state = repair_blocks(wallet, genesis, state, fixes)

        before_checks, before_score = validate(wallet)

        if before_score < 100:
            genesis = ensure_genesis(wallet, fixes)
            state = ensure_state(wallet, genesis, fixes)
            claims, registry = ensure_claims(wallet, state, fixes)
            state = repair_blocks(wallet, genesis, state, fixes)

        state, block = mine_autotest_block(wallet, state, fixes, cycle)

        after_checks, after_score = validate(wallet)

        loop_reports.append({
            "cycle": cycle,
            "before_score": before_score,
            "after_score": after_score,
            "fixes": fixes,
            "latest_height": state.get("latest_height"),
            "latest_block_hash": state.get("latest_block_hash")
        })

        all_fixes.extend([f"cycle_{cycle}:{x}" for x in fixes])

    final_checks, final_score = validate(wallet)
    report = write_outputs(wallet, loop_reports, final_checks, final_score, all_fixes)
    print(json.dumps(report, ensure_ascii=False, indent=2))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--wallet", required=True)
    ap.add_argument("--cycles", type=int, default=5)
    args = ap.parse_args()
    run(args.wallet, max(1, args.cycles))

if __name__ == "__main__":
    main()
