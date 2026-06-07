#!/usr/bin/env python3
import json, time, hashlib, re, sys, urllib.request
from pathlib import Path

ROOT = Path.home() / "CYBRA"

TOKEN_MINT = sys.argv[1] if len(sys.argv) > 1 else ""
WALLET = sys.argv[2] if len(sys.argv) > 2 else "FesrWxqM67HrjFqsCoCHsUkRocZZBgWeg4P3T4b9FD9Y"

def read_json(path, default=None):
    try:
        return Path(path).read_text(encoding="utf-8")
    except Exception:
        return default

def load_json(path, default=None):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except Exception:
        return default if default is not None else {}

def write_json(path, data):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

def sha_file(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def obj_hash(obj):
    clean = json.loads(json.dumps(obj, ensure_ascii=False))
    if isinstance(clean, dict):
        clean.pop("hash", None)
    return hashlib.sha256(json.dumps(clean, ensure_ascii=False, sort_keys=True).encode()).hexdigest()

def valid_base58(x):
    return bool(re.fullmatch(r"[1-9A-HJ-NP-Za-km-z]{32,60}", x or ""))

def solana_rpc(method, params):
    payload = json.dumps({
        "jsonrpc": "2.0",
        "id": 1,
        "method": method,
        "params": params
    }).encode()
    req = urllib.request.Request(
        "https://api.mainnet-beta.solana.com",
        data=payload,
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=12) as r:
        return json.loads(r.read().decode())

now = time.strftime("%Y-%m-%dT%H:%M:%S")

genesis = load_json(ROOT / "blockchain/kibra_chain/mainnet/genesis.json", {})
state = load_json(ROOT / "blockchain/kibra_chain/mainnet/state/latest_state.json", {})
claims = load_json(ROOT / "data/cybra_mainnet/claims/mainnet_candidate_claim_registry.json", {})
wallet_registry = load_json(ROOT / "data/cybra_mainnet/miners/miner_wallet_registry.json", {})

blocks = sorted((ROOT / "blockchain/kibra_chain/mainnet/blocks").glob("block_*.json"))

chain_links_ok = True
block_hashes_ok = True
no_external_tx = True
no_real_rewards = True

prev_hash = genesis.get("hash")
for bf in blocks:
    b = load_json(bf, {})
    if b.get("previous_hash") != prev_hash:
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
    prev_hash = b.get("hash")

balances = state.get("balances", {})
wallet_balance = balances.get(WALLET, {})

claim_wallet_ok = any(
    item.get("wallet") == WALLET or item.get("miner") == WALLET
    for item in claims.get("claims", [])
)

checks = {
    "wallet_format_ok": valid_base58(WALLET),
    "genesis_exists": bool(genesis.get("hash")),
    "genesis_hash_ok": bool(genesis.get("hash")) and genesis.get("hash") == obj_hash(genesis),
    "state_exists": bool(state),
    "blocks_exist": len(blocks) >= 1,
    "chain_links_ok": chain_links_ok,
    "block_hashes_ok": block_hashes_ok,
    "wallet_in_state": WALLET in balances,
    "wallet_claim_ok": claim_wallet_ok,
    "wallet_registry_ok": wallet_registry.get("wallet") == WALLET,
    "no_external_tx": no_external_tx,
    "no_real_rewards": no_real_rewards,
    "external_live_false": state.get("external_live") is False,
    "withdrawals_disabled": state.get("safety", {}).get("automatic_withdrawals") is False,
    "swift_disabled": state.get("safety", {}).get("automatic_SWIFT") is False
}

score = round(sum(1 for v in checks.values() if v is True) / len(checks) * 100, 2)
status = "KIBRA_TOKEN_CHECK_PASS" if score == 100 else "KIBRA_TOKEN_CHECK_PARTIAL"

placeholder_mints = {"", "MINT_ADDRESS_HERE", "REAL_SOLANA_MINT_ADDRESS_HERE"}

solana = {
    "requested": bool(TOKEN_MINT),
    "mint": TOKEN_MINT or None,
    "rpc_checked": False,
    "ok": None,
    "account_exists": None,
    "token_supply": None,
    "error": None,
    "note": "Local KIBRA check does not require Solana mint."
}

if TOKEN_MINT in placeholder_mints:
    solana["note"] = "Placeholder mint ignored. Local KIBRA token check only."
elif TOKEN_MINT:
    try:
        if not valid_base58(TOKEN_MINT):
            raise Exception("Invalid Solana mint/base58 format")
        acc = solana_rpc("getAccountInfo", [TOKEN_MINT, {"encoding": "base64", "commitment": "confirmed"}])
        supply = solana_rpc("getTokenSupply", [TOKEN_MINT, {"commitment": "confirmed"}])
        solana["rpc_checked"] = True
        solana["account_exists"] = bool(acc.get("result", {}).get("value"))
        solana["token_supply"] = supply.get("result", {}).get("value")
        solana["ok"] = solana["account_exists"] and solana["token_supply"] is not None
    except Exception as e:
        solana["rpc_checked"] = True
        solana["ok"] = False
        solana["error"] = str(e)

report = {
    "timestamp": now,
    "status": status,
    "score_percent": score,
    "wallet": WALLET,
    "token_mint_checked": TOKEN_MINT or None,
    "network": state.get("network"),
    "chain_id": state.get("chain_id"),
    "latest_height": state.get("latest_height"),
    "latest_block_hash": state.get("latest_block_hash"),
    "genesis_hash": genesis.get("hash"),
    "blocks_count": len(blocks) + (1 if genesis else 0),
    "wallet_balance": wallet_balance,
    "claims_status": claims.get("status"),
    "checks": checks,
    "solana_read_only_check": solana,
    "safety": {
        "real_payment_now": False,
        "automatic_external_tx": False,
        "automatic_withdrawals": False,
        "automatic_SWIFT": False,
        "automatic_real_rewards": False,
        "external_live": False
    }
}

out_json = ROOT / "data/cybra_token/checks/kibra_token_check_latest.json"
out_feed = ROOT / "feeds/kibra_token_check.json"
out_post = ROOT / "posts/kibra_token_check.md"
out_html = ROOT / "dashboard/kibra_mainnet/token_check.html"
out_proof = ROOT / "proofs/kibra_token_check.sha256"

write_json(out_json, report)
write_json(out_feed, report)

md = f"""# KIBRA / CYBRA Token Check

Status: **{status}**

Score: **{score}%**

## Wallet

`{WALLET}`

## Token mint checked

`{TOKEN_MINT or "LOCAL_KIBRA_INTERNAL_TOKEN_ONLY"}`

## Chain

- Network: `{state.get("network")}`
- Chain ID: `{state.get("chain_id")}`
- Latest height: `{state.get("latest_height")}`
- Latest block hash: `{state.get("latest_block_hash")}`
- Genesis hash: `{genesis.get("hash")}`
- Blocks count: `{report["blocks_count"]}`

## Wallet claim

- Wallet in state: `{checks["wallet_in_state"]}`
- Wallet claim ok: `{checks["wallet_claim_ok"]}`
- Wallet registry ok: `{checks["wallet_registry_ok"]}`
- Internal candidate credit: `{wallet_balance.get("internal_candidate_credit", 0)}`
- Real reward now: `{wallet_balance.get("real_reward_now", 0)}`

## Solana read-only RPC

- Requested: `{solana["requested"]}`
- RPC checked: `{solana["rpc_checked"]}`
- OK: `{solana["ok"]}`
- Account exists: `{solana["account_exists"]}`
- Token supply: `{solana["token_supply"]}`
- Error: `{solana["error"]}`
- Note: `{solana["note"]}`

## Safety

- real_payment_now: false
- automatic_external_tx: false
- automatic_withdrawals: false
- automatic_SWIFT: false
- automatic_real_rewards: false
- external_live: false
"""
out_post.write_text(md, encoding="utf-8")

html = f"""<!doctype html>
<html>
<head><meta charset="utf-8"><title>KIBRA Token Check</title></head>
<body>
<h1>KIBRA / CYBRA Token Check</h1>
<p>Status: <b>{status}</b></p>
<p>Score: <code>{score}%</code></p>
<p>Wallet:</p><code>{WALLET}</code>
<p>Token mint checked:</p><code>{TOKEN_MINT or "LOCAL_KIBRA_INTERNAL_TOKEN_ONLY"}</code>
<p>Network: <code>{state.get("network")}</code></p>
<p>Chain ID: <code>{state.get("chain_id")}</code></p>
<p>Latest height: <code>{state.get("latest_height")}</code></p>
<p>Latest block hash: <code>{state.get("latest_block_hash")}</code></p>
<p>Genesis hash: <code>{genesis.get("hash")}</code></p>
<p>External live: <code>false</code></p>
</body>
</html>
"""
out_html.write_text(html, encoding="utf-8")

targets = [out_json, out_feed, out_post, out_html]
out_proof.write_text(
    "".join(f"{sha_file(p)}  {p.relative_to(ROOT)}\n" for p in targets),
    encoding="utf-8"
)

print(json.dumps(report, ensure_ascii=False, indent=2))
