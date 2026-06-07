#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== MANIFEST KIBRA WALLET BINDING ==="

mkdir -p \
  data/cybra_mainnet/manifests \
  data/cybra_mainnet/reports \
  dashboard/kibra_mainnet \
  posts feeds proofs logs/mainnet

python3 - <<'PY'
import json, time, hashlib, html
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

def sha_file(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

now = time.strftime("%Y-%m-%dT%H:%M:%S")

registry = read_json(ROOT / "data/cybra_mainnet/miners/miner_wallet_registry.json", {})
claims = read_json(ROOT / "data/cybra_mainnet/claims/mainnet_candidate_claim_registry.json", {})
state = read_json(ROOT / "blockchain/kibra_chain/mainnet/state/latest_state.json", {})
report = read_json(ROOT / "data/cybra_mainnet/reports/miner_wallet_binding_latest.json", {})

wallet = registry.get("wallet") or "NOT_BOUND"
bind_id = registry.get("bind_id") or "NO_BIND_ID"

manifest = {
    "timestamp": now,
    "status": "KIBRA_WALLET_BINDING_MANIFESTED",
    "manifest_type": "KIBRA_INTERNAL_MAINNET_WALLET_CLAIM_MANIFEST",
    "wallet": wallet,
    "bind_id": bind_id,
    "network": state.get("network"),
    "chain_id": state.get("chain_id"),
    "latest_height": state.get("latest_height"),
    "latest_block_hash": state.get("latest_block_hash"),
    "pre_mainnet_claim_blocks": registry.get("pre_mainnet_claim_blocks", 0),
    "internal_candidate_credit": registry.get("internal_candidate_credit", 0),
    "real_reward_now": 0,
    "claim_status": "MANIFESTED_PENDING_FINAL_APPROVAL",
    "visible_in": [
        "posts/kibra_wallet_binding_manifest.md",
        "feeds/kibra_wallet_binding_manifest.json",
        "dashboard/kibra_mainnet/index.html",
        "proofs/kibra_wallet_binding_manifest.sha256"
    ],
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

files = {
    "manifest": ROOT / "data/cybra_mainnet/manifests/kibra_wallet_binding_manifest_latest.json",
    "report": ROOT / "data/cybra_mainnet/reports/kibra_wallet_binding_manifest_latest.json",
    "feed": ROOT / "feeds/kibra_wallet_binding_manifest.json",
    "post": ROOT / "posts/kibra_wallet_binding_manifest.md",
    "html": ROOT / "dashboard/kibra_mainnet/index.html"
}

write_json(files["manifest"], manifest)
write_json(files["report"], manifest)
write_json(files["feed"], manifest)

md = f"""# KIBRA Wallet Binding Manifest

Status: **KIBRA_WALLET_BINDING_MANIFESTED**

## Wallet

`{wallet}`

## Binding

- Bind ID: `{bind_id}`
- Network: `{state.get("network")}`
- Chain ID: `{state.get("chain_id")}`
- Latest height: `{state.get("latest_height")}`
- Latest block hash: `{state.get("latest_block_hash")}`

## Claim

- Pre-mainnet claim blocks: `{registry.get("pre_mainnet_claim_blocks", 0)}`
- Internal candidate credit: `{registry.get("internal_candidate_credit", 0)}`
- Real reward now: `0`
- Claim status: `MANIFESTED_PENDING_FINAL_APPROVAL`

## Safety

- wallet binding is not payout: true
- real_payment_now: false
- automatic_external_tx: false
- automatic_withdrawals: false
- automatic_real_rewards: false
- external_live: false
- OWNER approval required for external live: true
- Cyber Parliament approval required for external live: true
"""

files["post"].write_text(md, encoding="utf-8")

page = f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>KIBRA Mainnet Wallet Manifest</title>
<style>
body {{ font-family: system-ui, sans-serif; max-width: 980px; margin: 40px auto; padding: 20px; }}
.card {{ border: 1px solid #ddd; border-radius: 16px; padding: 20px; margin: 16px 0; }}
code {{ word-break: break-all; }}
.ok {{ font-weight: 700; }}
</style>
</head>
<body>
<h1>KIBRA Wallet Binding Manifest</h1>
<div class="card">
<p class="ok">Status: KIBRA_WALLET_BINDING_MANIFESTED</p>
<p>Wallet:</p>
<code>{html.escape(wallet)}</code>
</div>
<div class="card">
<p>Bind ID: <code>{html.escape(bind_id)}</code></p>
<p>Network: <code>{html.escape(str(state.get("network")))}</code></p>
<p>Chain ID: <code>{html.escape(str(state.get("chain_id")))}</code></p>
<p>Latest height: <code>{html.escape(str(state.get("latest_height")))}</code></p>
<p>Latest block hash: <code>{html.escape(str(state.get("latest_block_hash")))}</code></p>
</div>
<div class="card">
<p>Pre-mainnet claim blocks: <code>{registry.get("pre_mainnet_claim_blocks", 0)}</code></p>
<p>Internal candidate credit: <code>{registry.get("internal_candidate_credit", 0)}</code></p>
<p>Real reward now: <code>0</code></p>
</div>
<div class="card">
<p>Safety:</p>
<ul>
<li>No external transaction</li>
<li>No automatic withdrawals</li>
<li>No automatic real rewards</li>
<li>External live requires OWNER + Cyber Parliament approval</li>
</ul>
</div>
</body>
</html>
"""
files["html"].write_text(page, encoding="utf-8")

proof = ROOT / "proofs/kibra_wallet_binding_manifest.sha256"
proof.write_text(
    "".join(
        f"{sha_file(p)}  {p.relative_to(ROOT)}\n"
        for p in [
            files["manifest"],
            files["report"],
            files["feed"],
            files["post"],
            files["html"]
        ]
    ),
    encoding="utf-8"
)

print(json.dumps(manifest, ensure_ascii=False, indent=2))
PY

cat > cybra-kibra-manifest <<'EOF'
#!/usr/bin/env bash
cd "$HOME/CYBRA" || exit 1

case "$1" in
  status)
    cat posts/kibra_wallet_binding_manifest.md
    ;;
  json)
    cat data/cybra_mainnet/manifests/kibra_wallet_binding_manifest_latest.json
    ;;
  dashboard)
    echo "Open:"
    echo "  dashboard/kibra_mainnet/index.html"
    ;;
  serve)
    python3 -m http.server 8790 --bind 127.0.0.1 --directory dashboard/kibra_mainnet
    ;;
  proof)
    sha256sum -c proofs/kibra_wallet_binding_manifest.sha256
    ;;
  *)
    echo "Commands:"
    echo "  cybra-kibra-manifest status"
    echo "  cybra-kibra-manifest json"
    echo "  cybra-kibra-manifest dashboard"
    echo "  cybra-kibra-manifest serve"
    echo "  cybra-kibra-manifest proof"
    ;;
esac
EOF

chmod +x cybra-kibra-manifest
ln -sf "$HOME/CYBRA/cybra-kibra-manifest" "$PREFIX/bin/cybra-kibra-manifest" 2>/dev/null || true

echo
echo "=== CHECK ==="
cybra-kibra-manifest status
echo
cybra-kibra-manifest proof
echo
echo "✅ KIBRA WALLET BINDING MANIFESTED"
