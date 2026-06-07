#!/usr/bin/env python3
import json, time, hashlib, argparse, urllib.request
from pathlib import Path

ROOT = Path.home() / "CYBRA"
EVIDENCE_DIR = ROOT / "data/kibra_blockchain_market_proof/evidence"
REPORT_DIR = ROOT / "data/kibra_blockchain_market_proof/reports"
FEED = ROOT / "feeds/kibra_blockchain_market_proof.json"
POST = ROOT / "posts/kibra_blockchain_market_proof.md"
PROOF = ROOT / "proofs/kibra_blockchain_market_proof.sha256"

MIN_LIQUIDITY_USD = 100.0
MIN_BASE_AMOUNT = 1.0

RPCS = {
    "mainnet-beta": "https://api.mainnet-beta.solana.com",
    "devnet": "https://api.devnet.solana.com"
}

def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def sha(s):
    return hashlib.sha256(s.encode("utf-8")).hexdigest()

def dsha(obj):
    raw = json.dumps(obj, ensure_ascii=False, sort_keys=True)
    return sha(sha(raw))

def write_json(path, obj):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

def read_json(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except Exception:
        return None

def rpc_url(cluster_or_url):
    return RPCS.get(cluster_or_url, cluster_or_url)

def rpc_call(url, method, params):
    body = json.dumps({
        "jsonrpc": "2.0",
        "id": 1,
        "method": method,
        "params": params
    }).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body,
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=25) as r:
        data = json.loads(r.read().decode("utf-8"))
    if "error" in data:
        raise RuntimeError(str(data["error"]))
    return data.get("result")

def get_parsed_token_account(url, address):
    res = rpc_call(url, "getParsedAccountInfo", [
        address,
        {"encoding": "jsonParsed", "commitment": "confirmed"}
    ])
    val = res.get("value")
    if not val:
        raise RuntimeError(f"account_not_found:{address}")
    parsed = val["data"]["parsed"]
    info = parsed["info"]
    token_amount = info["tokenAmount"]
    return {
        "address": address,
        "mint": info.get("mint"),
        "owner": info.get("owner"),
        "amount": float(token_amount.get("uiAmountString") or token_amount.get("uiAmount") or 0),
        "decimals": token_amount.get("decimals"),
        "raw_amount": token_amount.get("amount")
    }

def get_token_supply(url, mint):
    res = rpc_call(url, "getTokenSupply", [mint, {"commitment": "confirmed"}])
    v = res.get("value", {})
    return {
        "mint": mint,
        "supply": float(v.get("uiAmountString") or v.get("uiAmount") or 0),
        "decimals": v.get("decimals"),
        "raw_amount": v.get("amount")
    }

def init_template():
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    t = {
        "type": "solana_pool_vaults",
        "name": "KIBRA_USDC_POOL_EXAMPLE",
        "cluster": "mainnet-beta",
        "rpc_url": "https://api.mainnet-beta.solana.com",
        "base_symbol": "KIBRA",
        "base_mint": "PUT_KIBRA_ONCHAIN_MINT_HERE",
        "base_vault": "PUT_KIBRA_POOL_VAULT_TOKEN_ACCOUNT_HERE",
        "quote_symbol": "USDC",
        "quote_mint": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
        "quote_vault": "PUT_USDC_POOL_VAULT_TOKEN_ACCOUNT_HERE",
        "quote_usd": 1,
        "pool_address": "PUT_REAL_POOL_ADDRESS_HERE",
        "source_url": "PUT_DEX_OR_EXPLORER_URL_HERE",
        "created_at": now(),
        "owner_approval_required": True,
        "fake_or_manual_price": False
    }
    write_json(EVIDENCE_DIR / "pool_template.json", t)
    print("✅ template:", "data/kibra_blockchain_market_proof/evidence/pool_template.json")

def add_pool(args):
    obj = {
        "type": "solana_pool_vaults",
        "name": args.name,
        "cluster": args.cluster,
        "rpc_url": rpc_url(args.cluster),
        "base_symbol": "KIBRA",
        "base_mint": args.base_mint,
        "base_vault": args.base_vault,
        "quote_symbol": args.quote_symbol,
        "quote_mint": args.quote_mint,
        "quote_vault": args.quote_vault,
        "quote_usd": float(args.quote_usd),
        "pool_address": args.pool_address,
        "source_url": args.source_url,
        "created_at": now(),
        "owner_approval_required": True,
        "fake_or_manual_price": False
    }
    name = f"{int(time.time())}_{args.name}.json".replace("/", "_")
    write_json(EVIDENCE_DIR / name, obj)
    print("✅ pool evidence added:", f"data/kibra_blockchain_market_proof/evidence/{name}")

def verify_pool(e):
    problems = []
    result = dict(e)

    for k in ["base_mint", "base_vault", "quote_mint", "quote_vault", "pool_address", "source_url"]:
        if not e.get(k) or str(e.get(k)).startswith("PUT_"):
            problems.append(f"missing_{k}")

    if problems:
        result["_valid"] = False
        result["_problems"] = problems
        return result

    url = rpc_url(e.get("rpc_url") or e.get("cluster", "mainnet-beta"))

    try:
        base_supply = get_token_supply(url, e["base_mint"])
        base_vault = get_parsed_token_account(url, e["base_vault"])
        quote_vault = get_parsed_token_account(url, e["quote_vault"])

        result["base_supply_onchain"] = base_supply
        result["base_vault_onchain"] = base_vault
        result["quote_vault_onchain"] = quote_vault

        if base_vault["mint"] != e["base_mint"]:
            problems.append("base_vault_mint_mismatch")
        if quote_vault["mint"] != e["quote_mint"]:
            problems.append("quote_vault_mint_mismatch")

        base_amount = float(base_vault["amount"])
        quote_amount = float(quote_vault["amount"])
        quote_usd = float(e.get("quote_usd", 1))

        if base_amount < MIN_BASE_AMOUNT:
            problems.append("base_liquidity_too_low")
        if quote_amount <= 0:
            problems.append("quote_liquidity_zero")

        if base_amount > 0 and quote_amount > 0:
            price_quote_per_kibra = quote_amount / base_amount
            price_usd_per_kibra = price_quote_per_kibra * quote_usd
            liquidity_usd_est = quote_amount * quote_usd * 2
        else:
            price_quote_per_kibra = 0
            price_usd_per_kibra = 0
            liquidity_usd_est = 0

        if liquidity_usd_est < MIN_LIQUIDITY_USD:
            problems.append("liquidity_usd_too_low")

        result["base_amount"] = base_amount
        result["quote_amount"] = quote_amount
        result["price_quote_per_kibra"] = price_quote_per_kibra
        result["price_usd_per_kibra"] = price_usd_per_kibra
        result["liquidity_usd_estimated"] = liquidity_usd_est
        result["real_orderbook_or_pool"] = True

    except Exception as ex:
        problems.append("rpc_error:" + str(ex))

    result["_valid"] = len(problems) == 0
    result["_problems"] = problems
    result["_double_sha"] = dsha(result)
    return result

def build_report():
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    checked = []
    valid = []

    for f in sorted(EVIDENCE_DIR.glob("*.json")):
        e = read_json(f)
        if not e or e.get("type") != "solana_pool_vaults":
            continue
        r = verify_pool(e)
        r["_file"] = str(f.relative_to(ROOT))
        checked.append(r)
        if r.get("_valid"):
            valid.append(r)

    if valid:
        prices = [float(x["price_usd_per_kibra"]) for x in valid]
        price = sum(prices) / len(prices)
        liquidity = sum(float(x["liquidity_usd_estimated"]) for x in valid)
        real = True
    else:
        price = 0
        liquidity = 0
        real = False

    report = {
        "status": "KIBRA_BLOCKCHAIN_MARKET_PROOF",
        "timestamp": now(),
        "chain": "solana",
        "token": "KIBRA",
        "price_usd_per_kibra": price,
        "real_market_confirmed": real,
        "valid_blockchain_sources": len(valid),
        "total_blockchain_sources": len(checked),
        "liquidity_usd_estimated_total": liquidity,
        "requirements": {
            "pool_vaults_required": True,
            "rpc_onchain_balances_required": True,
            "min_liquidity_usd": MIN_LIQUIDITY_USD,
            "manual_fake_price_blocked": True
        },
        "checked_sources": checked,
        "valid_sources": valid,
        "safety": {
            "real_payment_now": False,
            "automatic_SWIFT": False,
            "automatic_external_tx": False,
            "automatic_price_manipulation": False,
            "mainnet_deploy_allowed": False,
            "manual_OWNER_approval_required": True,
            "price_must_be_evidence_based": True
        }
    }
    report["double_sha"] = dsha(report)
    return report

def write_report(report):
    write_json(FEED, report)
    write_json(REPORT_DIR / "latest_report.json", report)

    if report["real_market_confirmed"]:
        ev = {
            "provider_name": "solana_onchain_pool_vaults",
            "proof_type": "blockchain_dex_pool_vault_reserves",
            "pair": "KIBRA/USDC_OR_USDT",
            "price_usd_per_kibra": report["price_usd_per_kibra"],
            "liquidity_usd": report["liquidity_usd_estimated_total"],
            "volume_24h_usd": 0,
            "source_url": report["valid_sources"][0].get("source_url"),
            "timestamp": report["timestamp"],
            "real_orderbook_or_pool": True,
            "fake_or_manual_price": False,
            "owner_approval_required": True,
            "blockchain_report_sha": report["double_sha"]
        }
        write_json(ROOT / "data/kibra_market_proof/evidence/blockchain_solana_pool_proof.json", ev)

    lines = []
    lines.append("# KIBRA Blockchain Market Proof")
    lines.append("")
    lines.append(f"Status: {report['status']}")
    lines.append(f"Timestamp: {report['timestamp']}")
    lines.append(f"Chain: {report['chain']}")
    lines.append("")
    lines.append("## Market")
    lines.append("")
    lines.append(f"PRICE_USD_PER_KIBRA: {report['price_usd_per_kibra']}")
    lines.append(f"REAL_MARKET_CONFIRMED: {report['real_market_confirmed']}")
    lines.append(f"VALID_BLOCKCHAIN_SOURCES: {report['valid_blockchain_sources']}")
    lines.append(f"TOTAL_BLOCKCHAIN_SOURCES: {report['total_blockchain_sources']}")
    lines.append(f"LIQUIDITY_USD_ESTIMATED_TOTAL: {report['liquidity_usd_estimated_total']}")
    lines.append("")
    lines.append("## Sources")
    lines.append("")
    for s in report["checked_sources"]:
        lines.append(f"- file: `{s.get('_file')}`")
        lines.append(f"  name: {s.get('name')}")
        lines.append(f"  pool: {s.get('pool_address')}")
        lines.append(f"  base_vault_amount: {s.get('base_amount')}")
        lines.append(f"  quote_vault_amount: {s.get('quote_amount')}")
        lines.append(f"  price_usd_per_kibra: {s.get('price_usd_per_kibra')}")
        lines.append(f"  liquidity_usd_estimated: {s.get('liquidity_usd_estimated')}")
        lines.append(f"  valid: {s.get('_valid')}")
        lines.append(f"  problems: {', '.join(s.get('_problems', [])) if s.get('_problems') else 'none'}")
        lines.append("")
    lines.append("## Safety")
    lines.append("")
    for k,v in report["safety"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Double SHA")
    lines.append(report["double_sha"])

    POST.write_text("\n".join(lines), encoding="utf-8")

    with PROOF.open("w", encoding="utf-8") as f:
        for p in [FEED, REPORT_DIR / "latest_report.json", POST]:
            f.write(f"{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.relative_to(ROOT)}\n")

def prepare_anchor(report):
    anchor = {
        "type": "KIBRA_BLOCKCHAIN_ANCHOR_PAYLOAD",
        "timestamp": now(),
        "report_file": "feeds/kibra_blockchain_market_proof.json",
        "report_double_sha": report["double_sha"],
        "price_usd_per_kibra": report["price_usd_per_kibra"],
        "real_market_confirmed": report["real_market_confirmed"],
        "valid_blockchain_sources": report["valid_blockchain_sources"],
        "note": "This anchor proves timestamp/hash on-chain. It does not create market value by itself."
    }
    anchor["double_sha"] = dsha(anchor)
    write_json(ROOT / "data/kibra_blockchain_market_proof/anchor_payload.json", anchor)

    memo = "KIBRA_MARKET_PROOF:" + anchor["double_sha"]
    (ROOT / "data/kibra_blockchain_market_proof/anchor_memo.txt").write_text(memo, encoding="utf-8")
    print("✅ anchor memo prepared:")
    print(memo)
    print("FILE: data/kibra_blockchain_market_proof/anchor_payload.json")

def print_status(report):
    print("=== KIBRA BLOCKCHAIN MARKET PROOF ===")
    print("PRICE_USD_PER_KIBRA:", report["price_usd_per_kibra"])
    print("REAL_MARKET_CONFIRMED:", report["real_market_confirmed"])
    print("VALID_BLOCKCHAIN_SOURCES:", report["valid_blockchain_sources"])
    print("TOTAL_BLOCKCHAIN_SOURCES:", report["total_blockchain_sources"])
    print("LIQUIDITY_USD_ESTIMATED_TOTAL:", report["liquidity_usd_estimated_total"])
    print("DOUBLE_SHA:", report["double_sha"])
    print("REPORT: posts/kibra_blockchain_market_proof.md")

def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd")

    sub.add_parser("init")
    sub.add_parser("status")
    sub.add_parser("verify")
    sub.add_parser("prepare-anchor")

    p = sub.add_parser("add-pool")
    p.add_argument("--name", required=True)
    p.add_argument("--cluster", default="mainnet-beta")
    p.add_argument("--base-mint", required=True)
    p.add_argument("--base-vault", required=True)
    p.add_argument("--quote-mint", required=True)
    p.add_argument("--quote-vault", required=True)
    p.add_argument("--quote-symbol", default="USDC")
    p.add_argument("--quote-usd", default="1")
    p.add_argument("--pool-address", required=True)
    p.add_argument("--source-url", required=True)

    args = ap.parse_args()
    cmd = args.cmd or "status"

    if cmd == "init":
        init_template()

    if cmd == "add-pool":
        add_pool(args)

    report = build_report()
    write_report(report)

    if cmd == "prepare-anchor":
        prepare_anchor(report)

    print_status(report)

if __name__ == "__main__":
    main()
