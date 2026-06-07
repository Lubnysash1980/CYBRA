#!/usr/bin/env python3
import json, time, hashlib, argparse, uuid, re
from pathlib import Path
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

ROOT = Path.home() / "CYBRA"

GENESIS = ROOT / "blockchain/kibra_chain/mainnet/genesis.json"
BLOCKS = ROOT / "blockchain/kibra_chain/mainnet/blocks"
STATE = ROOT / "blockchain/kibra_chain/mainnet/state/latest_state.json"
MEMPOOL = ROOT / "blockchain/kibra_chain/mainnet/mempool/pending.json"
NODE_STATUS = ROOT / "data/cybra_mainnet/node/node_status.json"
REPORT = ROOT / "data/cybra_mainnet/reports/kibra_real_node_latest.json"
POST = ROOT / "posts/kibra_real_internal_node.md"
FEED = ROOT / "feeds/kibra_real_internal_node.json"
HTML = ROOT / "dashboard/kibra_mainnet/node.html"
PROOF = ROOT / "proofs/kibra_real_internal_node.sha256"

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
    "mainnet_scope": "INTERNAL_NODE_ONLY",
    "manual_OWNER_approval_required_for_external_live": True,
    "cyber_parliament_approval_required_for_external_live": True
}

def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S")

def read_json(path, default=None):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except Exception:
        return default if default is not None else {}

def write_json(path, data):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

def valid_wallet(w):
    return bool(re.fullmatch(r"[1-9A-HJ-NP-Za-km-z]{32,60}", w or ""))

def obj_hash(obj):
    clean = json.loads(json.dumps(obj, ensure_ascii=False))
    if isinstance(clean, dict):
        clean.pop("hash", None)
    raw = json.dumps(clean, ensure_ascii=False, sort_keys=True).encode()
    return hashlib.sha256(raw).hexdigest()

def file_hash(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def block_files():
    return sorted(BLOCKS.glob("block_*.json"))

def load_state():
    return read_json(STATE, {})

def save_state(state):
    state["timestamp"] = now()
    state["safety"] = SAFETY
    write_json(STATE, state)
    write_json(ROOT / "data/cybra_mainnet/live/internal_mainnet_live_state.json", state)

def load_mempool():
    return read_json(MEMPOOL, [])

def save_mempool(items):
    write_json(MEMPOOL, items)

def ensure_genesis(wallet):
    genesis = read_json(GENESIS, {})
    if genesis.get("hash"):
        return genesis

    chain_id = "kibra-mainnet-internal-" + hashlib.sha256((wallet + now()).encode()).hexdigest()[:16]
    genesis = {
        "network": "KIBRA_INTERNAL_MAINNET",
        "chain_id": chain_id,
        "timestamp": now(),
        "height": 0,
        "previous_hash": "0" * 64,
        "status": "INTERNAL_MAINNET_GENESIS_CREATED",
        "mode": "INTERNAL_NODE_ONLY",
        "creator_wallet": wallet,
        "external_live": False,
        "safety": SAFETY
    }
    genesis["hash"] = obj_hash(genesis)
    write_json(GENESIS, genesis)
    return genesis

def init_node(wallet):
    if not valid_wallet(wallet):
        raise SystemExit("Invalid wallet format")

    genesis = ensure_genesis(wallet)
    state = load_state()

    if not state:
        state = {
            "network": genesis.get("network", "KIBRA_INTERNAL_MAINNET"),
            "chain_id": genesis.get("chain_id"),
            "status": "INTERNAL_MAINNET_NODE_READY",
            "latest_height": 0,
            "genesis_hash": genesis.get("hash"),
            "latest_block_hash": genesis.get("hash"),
            "blocks_count": 1,
            "balances": {},
            "external_live": False,
            "safety": SAFETY
        }

    balances = state.setdefault("balances", {})
    if "unknown_miner" in balances and wallet not in balances:
        balances[wallet] = balances.pop("unknown_miner")

    balances.setdefault(wallet, {
        "wallet": wallet,
        "pre_mainnet_claim_blocks": 60,
        "internal_candidate_credit": 60,
        "real_reward_now": 0,
        "claim_status": "WALLET_BOUND_INTERNAL_MAINNET_NODE"
    })

    state["status"] = "INTERNAL_MAINNET_NODE_READY"
    state["node_wallet"] = wallet
    state["external_live"] = False
    save_state(state)

    status = {
        "timestamp": now(),
        "status": "KIBRA_REAL_INTERNAL_NODE_READY",
        "wallet": wallet,
        "network": state.get("network"),
        "chain_id": state.get("chain_id"),
        "latest_height": state.get("latest_height"),
        "latest_block_hash": state.get("latest_block_hash"),
        "mempool_size": len(load_mempool()),
        "safety": SAFETY
    }
    write_json(NODE_STATUS, status)
    return status

def submit_tx(from_wallet, to_wallet, amount, note):
    if not valid_wallet(from_wallet) or not valid_wallet(to_wallet):
        raise SystemExit("Invalid wallet")

    amount = int(amount)
    if amount < 0:
        raise SystemExit("Amount must be >= 0")

    tx = {
        "tx_id": "KIBRA-TX-" + uuid.uuid4().hex[:16],
        "timestamp": now(),
        "type": "INTERNAL_CREDIT_TX",
        "from": from_wallet,
        "to": to_wallet,
        "amount": amount,
        "external": False,
        "real_value": False,
        "note": note or "internal mainnet tx only"
    }
    tx["hash"] = obj_hash(tx)

    mem = load_mempool()
    mem.append(tx)
    save_mempool(mem)
    return {"status": "TX_ADDED_TO_INTERNAL_MEMPOOL", "tx": tx, "mempool_size": len(mem)}

def mine_block(miner_wallet):
    if not valid_wallet(miner_wallet):
        raise SystemExit("Invalid miner wallet")

    genesis = ensure_genesis(miner_wallet)
    state = load_state()
    if not state:
        init_node(miner_wallet)
        state = load_state()

    mem = load_mempool()

    if not mem:
        mem = [{
            "tx_id": "KIBRA-HEARTBEAT-" + uuid.uuid4().hex[:12],
            "timestamp": now(),
            "type": "INTERNAL_HEARTBEAT_TX",
            "from": miner_wallet,
            "to": miner_wallet,
            "amount": 0,
            "external": False,
            "real_value": False,
            "note": "heartbeat block, no value transfer"
        }]
        mem[0]["hash"] = obj_hash(mem[0])

    balances = state.setdefault("balances", {})
    balances.setdefault(miner_wallet, {
        "wallet": miner_wallet,
        "pre_mainnet_claim_blocks": 0,
        "internal_candidate_credit": 0,
        "real_reward_now": 0,
        "claim_status": "NODE_MINER"
    })

    applied = []
    rejected = []

    for tx in mem:
        if tx.get("external") is True or tx.get("real_value") is True:
            rejected.append({"tx": tx, "reason": "external_or_real_value_tx_rejected"})
            continue

        src = tx.get("from")
        dst = tx.get("to")
        amount = int(tx.get("amount", 0) or 0)

        balances.setdefault(src, {
            "wallet": src,
            "internal_candidate_credit": 0,
            "real_reward_now": 0,
            "claim_status": "INTERNAL_WALLET"
        })
        balances.setdefault(dst, {
            "wallet": dst,
            "internal_candidate_credit": 0,
            "real_reward_now": 0,
            "claim_status": "INTERNAL_WALLET"
        })

        if amount > 0:
            src_credit = int(balances[src].get("internal_candidate_credit", 0) or 0)
            if src_credit < amount:
                rejected.append({"tx": tx, "reason": "insufficient_internal_candidate_credit"})
                continue
            balances[src]["internal_candidate_credit"] = src_credit - amount
            balances[dst]["internal_candidate_credit"] = int(balances[dst].get("internal_candidate_credit", 0) or 0) + amount

        balances[src]["real_reward_now"] = 0
        balances[dst]["real_reward_now"] = 0
        applied.append(tx)

    height = int(state.get("latest_height", 0) or 0) + 1
    previous_hash = state.get("latest_block_hash") or genesis.get("hash")

    block = {
        "network": state.get("network", genesis.get("network")),
        "chain_id": state.get("chain_id", genesis.get("chain_id")),
        "timestamp": now(),
        "height": height,
        "previous_hash": previous_hash,
        "status": "INTERNAL_MAINNET_BLOCK_MINED",
        "miner": miner_wallet,
        "transactions": applied,
        "rejected_transactions": rejected,
        "external_tx": False,
        "reward": {
            "internal_reward": 0,
            "real_reward": 0,
            "claim_only": True
        },
        "safety": SAFETY
    }
    block["hash"] = obj_hash(block)

    block_path = BLOCKS / f"block_{height:06d}.json"
    write_json(block_path, block)

    state["status"] = "INTERNAL_MAINNET_RUNNING"
    state["latest_height"] = height
    state["latest_block_hash"] = block["hash"]
    state["blocks_count"] = height + 1
    state["balances"] = balances
    state["external_live"] = False
    save_state(state)

    save_mempool([])

    return {
        "status": "BLOCK_MINED",
        "height": height,
        "hash": block["hash"],
        "applied_tx": len(applied),
        "rejected_tx": len(rejected),
        "block_file": str(block_path.relative_to(ROOT))
    }

def validate_chain():
    genesis = read_json(GENESIS, {})
    state = load_state()
    files = block_files()

    checks = {}
    checks["genesis_exists"] = bool(genesis.get("hash"))
    checks["genesis_hash_ok"] = genesis.get("hash") == obj_hash(genesis) if genesis else False

    prev = genesis.get("hash")
    chain_links_ok = True
    block_hashes_ok = True
    no_external_tx = True
    no_real_rewards = True

    for bf in files:
        b = read_json(bf, {})
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

    checks["blocks_exist"] = len(files) >= 1
    checks["chain_links_ok"] = chain_links_ok
    checks["block_hashes_ok"] = block_hashes_ok
    checks["state_latest_hash_ok"] = state.get("latest_block_hash") == prev if files else state.get("latest_block_hash") == genesis.get("hash")
    checks["no_external_tx"] = no_external_tx
    checks["no_real_rewards"] = no_real_rewards
    checks["withdrawals_disabled"] = state.get("safety", {}).get("automatic_withdrawals") is False
    checks["swift_disabled"] = state.get("safety", {}).get("automatic_SWIFT") is False

    total = len(checks)
    passed = sum(1 for v in checks.values() if v is True)
    score = round(passed / total * 100, 2)

    report = {
        "timestamp": now(),
        "status": "KIBRA_REAL_NODE_VALIDATE_PASS" if score == 100 else "KIBRA_REAL_NODE_VALIDATE_PARTIAL",
        "score_percent": score,
        "latest_height": state.get("latest_height"),
        "latest_block_hash": state.get("latest_block_hash"),
        "blocks_count": len(files) + 1,
        "checks": checks,
        "external_live": False,
        "safety": SAFETY
    }
    write_json(REPORT, report)
    write_json(FEED, report)
    write_post(report)
    write_dashboard(report)
    write_proof()
    return report

def write_post(report):
    state = load_state()
    wallet = state.get("node_wallet") or next(iter(state.get("balances", {}) or {}), "NO_WALLET")
    md = f"""# KIBRA Real Internal Mainnet Node

Status: **{report.get("status")}**

Score: **{report.get("score_percent")}%**

## Wallet

`{wallet}`

## Chain

- Network: `{state.get("network")}`
- Chain ID: `{state.get("chain_id")}`
- Latest height: `{state.get("latest_height")}`
- Latest block hash: `{state.get("latest_block_hash")}`

## What is working

- Internal node: yes
- Internal mempool: yes
- Mine block: yes
- Validate chain: yes
- Wallet state: yes
- Dashboard/API: yes
- Proof: yes

## Safety

- real_payment_now: false
- automatic_external_tx: false
- automatic_withdrawals: false
- automatic_SWIFT: false
- automatic_real_rewards: false
- external_bridge_enabled: false
"""
    POST.write_text(md, encoding="utf-8")

def write_dashboard(report):
    state = load_state()
    wallet = state.get("node_wallet") or next(iter(state.get("balances", {}) or {}), "NO_WALLET")
    page = f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>KIBRA Real Internal Node</title>
<style>
body {{ font-family: system-ui, sans-serif; max-width: 980px; margin: 40px auto; padding: 20px; }}
.card {{ border: 1px solid #ddd; border-radius: 16px; padding: 20px; margin: 16px 0; }}
code {{ word-break: break-all; }}
</style>
</head>
<body>
<h1>KIBRA Real Internal Mainnet Node</h1>
<div class="card">
<p>Status: <b>{report.get("status")}</b></p>
<p>Score: <code>{report.get("score_percent")}%</code></p>
</div>
<div class="card">
<p>Wallet:</p>
<code>{wallet}</code>
</div>
<div class="card">
<p>Network: <code>{state.get("network")}</code></p>
<p>Chain ID: <code>{state.get("chain_id")}</code></p>
<p>Latest height: <code>{state.get("latest_height")}</code></p>
<p>Latest block hash: <code>{state.get("latest_block_hash")}</code></p>
</div>
<div class="card">
<p>API:</p>
<ul>
<li><code>/health</code></li>
<li><code>/state</code></li>
<li><code>/blocks</code></li>
<li><code>/mempool</code></li>
<li><code>/wallet?addr={wallet}</code></li>
</ul>
</div>
<div class="card">
<p>External live: <code>false</code></p>
<p>No withdrawals. No SWIFT. No external automatic transactions.</p>
</div>
</body>
</html>
"""
    HTML.write_text(page, encoding="utf-8")

def write_proof():
    targets = [
        GENESIS,
        STATE,
        MEMPOOL,
        NODE_STATUS,
        REPORT,
        FEED,
        POST,
        HTML,
        ROOT / "scripts/kibra/cybra_kibra_real_node.py"
    ]
    targets += block_files()
    lines = []
    for p in targets:
        if p.exists():
            lines.append(f"{file_hash(p)}  {p.relative_to(ROOT)}\n")
    PROOF.write_text("".join(lines), encoding="utf-8")

def api_server(host, port):
    class Handler(BaseHTTPRequestHandler):
        def send_json(self, data):
            raw = json.dumps(data, ensure_ascii=False, indent=2).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)

        def do_GET(self):
            u = urlparse(self.path)
            q = parse_qs(u.query)

            if u.path == "/":
                if HTML.exists():
                    raw = HTML.read_bytes()
                    self.send_response(200)
                    self.send_header("Content-Type", "text/html; charset=utf-8")
                    self.send_header("Content-Length", str(len(raw)))
                    self.end_headers()
                    self.wfile.write(raw)
                else:
                    self.send_json({"status": "NO_DASHBOARD_YET"})
            elif u.path == "/health":
                self.send_json({"status": "ok", "node": "KIBRA_REAL_INTERNAL_NODE", "external_live": False})
            elif u.path == "/state":
                self.send_json(load_state())
            elif u.path == "/mempool":
                self.send_json({"pending": load_mempool()})
            elif u.path == "/blocks":
                self.send_json({"genesis": read_json(GENESIS, {}), "blocks": [read_json(p, {}) for p in block_files()]})
            elif u.path == "/wallet":
                addr = (q.get("addr") or [""])[0]
                st = load_state()
                self.send_json({"wallet": addr, "balance": st.get("balances", {}).get(addr, {})})
            else:
                self.send_json({"error": "not_found"})

        def log_message(self, fmt, *args):
            return

    print(f"KIBRA API: http://{host}:{port}/")
    HTTPServer((host, port), Handler).serve_forever()

def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd")

    p = sub.add_parser("init")
    p.add_argument("--wallet", required=True)

    p = sub.add_parser("submit")
    p.add_argument("--from-wallet", required=True)
    p.add_argument("--to-wallet", required=True)
    p.add_argument("--amount", default="0")
    p.add_argument("--note", default="")

    p = sub.add_parser("mine")
    p.add_argument("--miner", required=True)

    sub.add_parser("validate")
    sub.add_parser("status")
    sub.add_parser("proof")

    p = sub.add_parser("api")
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", default="8792", type=int)

    args = ap.parse_args()

    if args.cmd == "init":
        print(json.dumps(init_node(args.wallet), ensure_ascii=False, indent=2))
    elif args.cmd == "submit":
        print(json.dumps(submit_tx(args.from_wallet, args.to_wallet, args.amount, args.note), ensure_ascii=False, indent=2))
    elif args.cmd == "mine":
        print(json.dumps(mine_block(args.miner), ensure_ascii=False, indent=2))
    elif args.cmd == "validate":
        print(json.dumps(validate_chain(), ensure_ascii=False, indent=2))
    elif args.cmd == "status":
        print(POST.read_text(encoding="utf-8") if POST.exists() else json.dumps(load_state(), ensure_ascii=False, indent=2))
    elif args.cmd == "proof":
        write_proof()
        import subprocess
        subprocess.call("sha256sum -c proofs/kibra_real_internal_node.sha256", shell=True, cwd=ROOT)
    elif args.cmd == "api":
        validate_chain()
        api_server(args.host, args.port)
    else:
        ap.print_help()

if __name__ == "__main__":
    main()
