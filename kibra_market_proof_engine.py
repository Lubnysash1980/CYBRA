#!/usr/bin/env python3
import json, time, hashlib, sys, os
from pathlib import Path

ROOT = Path.home() / "CYBRA"

EVIDENCE_DIR = ROOT / "data/kibra_market_proof/evidence"
REPORT_DIR = ROOT / "data/kibra_market_proof/reports"
FEED = ROOT / "feeds/kibra_market_proof.json"
POST = ROOT / "posts/kibra_market_proof.md"
PROOF = ROOT / "proofs/kibra_market_proof.sha256"

MIN_LIQUIDITY_USD = 100.0
MIN_24H_VOLUME_USD = 25.0
MIN_SOURCES = 1

def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(obj):
    raw = json.dumps(obj, ensure_ascii=False, sort_keys=True)
    return sha(sha(raw))

def read_json(p):
    try:
        return json.loads(Path(p).read_text(encoding="utf-8"))
    except Exception:
        return None

def write_json(p, obj):
    Path(p).parent.mkdir(parents=True, exist_ok=True)
    Path(p).write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

def evidence_files():
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    return sorted(EVIDENCE_DIR.glob("*.json"))

def validate_evidence(e):
    problems = []

    provider = e.get("provider_name")
    pair = e.get("pair")
    price = e.get("price_usd_per_kibra")
    liquidity = e.get("liquidity_usd")
    volume = e.get("volume_24h_usd")
    source_url = e.get("source_url")
    timestamp = e.get("timestamp")
    proof_type = e.get("proof_type")

    if not provider:
        problems.append("missing_provider_name")
    if not pair:
        problems.append("missing_pair")
    if not proof_type:
        problems.append("missing_proof_type")
    if not source_url:
        problems.append("missing_source_url")
    if not timestamp:
        problems.append("missing_timestamp")

    try:
        price = float(price)
        if price <= 0:
            problems.append("price_not_positive")
    except Exception:
        problems.append("invalid_price")

    try:
        liquidity = float(liquidity)
        if liquidity < MIN_LIQUIDITY_USD:
            problems.append("liquidity_too_low")
    except Exception:
        problems.append("invalid_liquidity")

    try:
        volume = float(volume)
        if volume < MIN_24H_VOLUME_USD:
            problems.append("volume_too_low")
    except Exception:
        problems.append("invalid_volume")

    if e.get("fake_or_manual_price") is True:
        problems.append("manual_or_fake_price_blocked")

    if e.get("real_orderbook_or_pool") is not True:
        problems.append("real_orderbook_or_pool_not_confirmed")

    if e.get("owner_approval_required") is not True:
        problems.append("owner_approval_flag_missing")

    ok = len(problems) == 0
    return ok, problems

def build_report():
    evidences = []
    valid = []

    for f in evidence_files():
        e = read_json(f)
        if not e:
            continue
        ok, problems = validate_evidence(e)
        e["_file"] = str(f.relative_to(ROOT))
        e["_valid"] = ok
        e["_problems"] = problems
        e["_double_sha"] = dsha(e)
        evidences.append(e)
        if ok:
            valid.append(e)

    if len(valid) >= MIN_SOURCES:
        prices = [float(x["price_usd_per_kibra"]) for x in valid]
        liquidity = sum(float(x["liquidity_usd"]) for x in valid)
        volume = sum(float(x["volume_24h_usd"]) for x in valid)
        price = sum(prices) / len(prices)
        real_market_confirmed = True
    else:
        price = 0
        liquidity = 0
        volume = 0
        real_market_confirmed = False

    report = {
        "status": "KIBRA_MARKET_PROOF_REPORT",
        "timestamp": now(),
        "token": "KIBRA",
        "valid_sources": len(valid),
        "total_sources": len(evidences),
        "min_sources_required": MIN_SOURCES,
        "price_usd_per_kibra": price,
        "real_market_confirmed": real_market_confirmed,
        "liquidity_usd_total": liquidity,
        "volume_24h_usd_total": volume,
        "requirements": {
            "min_liquidity_usd": MIN_LIQUIDITY_USD,
            "min_24h_volume_usd": MIN_24H_VOLUME_USD,
            "real_orderbook_or_pool_required": True,
            "manual_price_blocked": True,
            "fake_market_blocked": True,
            "owner_approval_required": True
        },
        "evidence": evidences,
        "valid_evidence": valid,
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

    md = []
    md.append("# KIBRA Market Proof")
    md.append("")
    md.append(f"Status: {report['status']}")
    md.append(f"Timestamp: {report['timestamp']}")
    md.append(f"Token: {report['token']}")
    md.append("")
    md.append("## Market")
    md.append("")
    md.append(f"PRICE_USD_PER_KIBRA: {report['price_usd_per_kibra']}")
    md.append(f"REAL_MARKET_CONFIRMED: {report['real_market_confirmed']}")
    md.append(f"VALID_SOURCES: {report['valid_sources']}")
    md.append(f"TOTAL_SOURCES: {report['total_sources']}")
    md.append(f"LIQUIDITY_USD_TOTAL: {report['liquidity_usd_total']}")
    md.append(f"VOLUME_24H_USD_TOTAL: {report['volume_24h_usd_total']}")
    md.append("")
    md.append("## Evidence")
    md.append("")
    for e in report["evidence"]:
        md.append(f"- file: `{e.get('_file')}`")
        md.append(f"  provider: {e.get('provider_name')}")
        md.append(f"  pair: {e.get('pair')}")
        md.append(f"  price: {e.get('price_usd_per_kibra')}")
        md.append(f"  liquidity: {e.get('liquidity_usd')}")
        md.append(f"  volume_24h: {e.get('volume_24h_usd')}")
        md.append(f"  valid: {e.get('_valid')}")
        md.append(f"  problems: {', '.join(e.get('_problems', [])) if e.get('_problems') else 'none'}")
        md.append("")
    md.append("## Safety")
    md.append("")
    for k, v in report["safety"].items():
        md.append(f"{k}: {v}")
    md.append("")
    md.append("## Double SHA")
    md.append("")
    md.append(report["double_sha"])

    POST.parent.mkdir(parents=True, exist_ok=True)
    POST.write_text("\n".join(md), encoding="utf-8")

    with PROOF.open("w", encoding="utf-8") as f:
        for p in [FEED, REPORT_DIR / "latest_report.json", POST]:
            h = hashlib.sha256(p.read_bytes()).hexdigest()
            f.write(f"{h}  {p.relative_to(ROOT)}\n")

def init_template():
    template = {
        "provider_name": "PUT_REAL_PROVIDER_NAME_HERE",
        "proof_type": "exchange_orderbook_or_dex_pool_or_psp_quote",
        "pair": "KIBRA/USDT",
        "price_usd_per_kibra": 0,
        "liquidity_usd": 0,
        "volume_24h_usd": 0,
        "source_url": "PUT_REAL_SOURCE_URL_HERE",
        "timestamp": now(),
        "real_orderbook_or_pool": False,
        "fake_or_manual_price": False,
        "owner_approval_required": True,
        "notes": "Заповни тільки реальними даними з біржі, DEX-пулу, PSP або провайдера ліквідності."
    }
    p = EVIDENCE_DIR / "market_source_template.json"
    write_json(p, template)
    print("✅ template:", p.relative_to(ROOT))

def add_manual(args):
    if len(args) < 7:
        print("Usage:")
        print("  kibra-market-proof add PROVIDER PAIR PRICE LIQUIDITY_USD VOLUME_24H_USD SOURCE_URL")
        print("")
        print("Example:")
        print("  kibra-market-proof add my_exchange KIBRA/USDT 0.01 500 100 https://example.com/kibra-usdt")
        return 1

    provider, pair, price, liq, vol, url = args[1:7]

    obj = {
        "provider_name": provider,
        "proof_type": "manual_import_real_market_source",
        "pair": pair,
        "price_usd_per_kibra": float(price),
        "liquidity_usd": float(liq),
        "volume_24h_usd": float(vol),
        "source_url": url,
        "timestamp": now(),
        "real_orderbook_or_pool": True,
        "fake_or_manual_price": False,
        "owner_approval_required": True,
        "notes": "Manual import. Must be backed by real external source_url and later audited."
    }
    name = f"{int(time.time())}_{provider}_{pair.replace('/','_')}.json"
    p = EVIDENCE_DIR / name
    write_json(p, obj)
    print("✅ evidence added:", p.relative_to(ROOT))
    return 0

def push_to_redis(report):
    task = {
        "type": "kibra_market_proof_task",
        "status": "MARKET_PROOF_UPDATED",
        "timestamp": now(),
        "price_usd_per_kibra": report["price_usd_per_kibra"],
        "real_market_confirmed": report["real_market_confirmed"],
        "valid_sources": report["valid_sources"],
        "total_sources": report["total_sources"],
        "report_file": "feeds/kibra_market_proof.json",
        "post_file": "posts/kibra_market_proof.md",
        "double_sha": report["double_sha"],
        "safety": report["safety"]
    }
    raw = json.dumps(task, ensure_ascii=False)
    os.system("redis-cli LPUSH cybra:parliament:queue '{}' >/dev/null 2>&1".format(raw.replace("'", "'\"'\"'")))
    os.system("redis-cli LPUSH cybra:it_department:queue '{}' >/dev/null 2>&1".format(raw.replace("'", "'\"'\"'")))
    os.system("redis-cli LPUSH cybra:ai:tasks:block_inbox '{}' >/dev/null 2>&1".format(raw.replace("'", "'\"'\"'")))
    os.system("redis-cli LPUSH cybra:kibra:market_proof:queue '{}' >/dev/null 2>&1".format(raw.replace("'", "'\"'\"'")))

def print_status(report):
    print("=== KIBRA MARKET PROOF ===")
    print("PRICE_USD_PER_KIBRA:", report["price_usd_per_kibra"])
    print("REAL_MARKET_CONFIRMED:", report["real_market_confirmed"])
    print("VALID_SOURCES:", report["valid_sources"])
    print("TOTAL_SOURCES:", report["total_sources"])
    print("LIQUIDITY_USD_TOTAL:", report["liquidity_usd_total"])
    print("VOLUME_24H_USD_TOTAL:", report["volume_24h_usd_total"])
    print("DOUBLE_SHA:", report["double_sha"])
    print("REPORT:", "posts/kibra_market_proof.md")

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "init":
        init_template()
        report = build_report()
        write_report(report)
        print_status(report)
        return

    if cmd == "add":
        rc = add_manual(sys.argv[1:])
        if rc:
            return
        report = build_report()
        write_report(report)
        push_to_redis(report)
        print_status(report)
        return

    if cmd in ("verify", "status", "report", "push"):
        report = build_report()
        write_report(report)
        if cmd == "push":
            push_to_redis(report)
        print_status(report)
        return

    print("Usage:")
    print("  kibra-market-proof init")
    print("  kibra-market-proof status")
    print("  kibra-market-proof verify")
    print("  kibra-market-proof push")
    print("  kibra-market-proof add PROVIDER PAIR PRICE LIQUIDITY_USD VOLUME_24H_USD SOURCE_URL")

if __name__ == "__main__":
    main()
