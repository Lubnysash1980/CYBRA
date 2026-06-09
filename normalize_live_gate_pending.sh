#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== NORMALIZE LIVE GATE / OWNER APPROVAL PENDING ==="

mkdir -p data/cyberbot/actions data/cyberbot/config data/cybra_bot_supervisor/config posts feeds proofs

python3 <<'PY'
import json, time, hashlib
from pathlib import Path

ROOT = Path.home() / "CYBRA"

FILES = [
    ROOT / "data/cyberbot/config/cyberbot_config.json",
    ROOT / "data/cybra_bot_supervisor/config/bot_bar_config.json",
    ROOT / "data/cyberbot/actions/live_on_request_latest.json",
]

def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S")

def read_json(p):
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return {}

def write_json(p, data):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

SAFETY = {
    "real_payment_now": False,
    "real_trading_now": False,
    "live_orders_enabled": False,
    "allow_live_orders": False,
    "live_order_requested": True,
    "live_order_gate": "REQUESTED_AUDIT_AND_OWNER_APPROVAL_REQUIRED",
    "paper_trading": True,
    "testnet_mode": True,
    "automatic_external_tx": False,
    "automatic_withdrawals": False,
    "automatic_SWIFT": False,
    "automatic_real_rewards": False,
    "manual_OWNER_approval_required": True,
    "it_supervision_required": True,
    "cyber_parliament_supervision_required": True,
    "api_keys_stored_local_only": True,
    "do_not_store_secrets_in_git": True
}

for p in FILES:
    data = read_json(p)
    data.update({
        "timestamp": now(),
        "live_order_requested": True,
        "live_order_gate": "REQUESTED_AUDIT_AND_OWNER_APPROVAL_REQUIRED",
        "live_orders_enabled": False,
        "allow_live_orders": False,
        "real_trading_now": False,
        "paper_trading": True,
        "testnet_mode": True,
        "manual_OWNER_approval_required": True,
        "safety": SAFETY
    })
    write_json(p, data)

policy = {
    "timestamp": now(),
    "status": "LIVE_GATE_POLICY_NORMALIZED",
    "who_can_enable_live_orders": "OWNER_ONLY_AFTER_IT_PARLIAMENT_FINANCE_AUDIT",
    "current_state": {
        "live_order_requested": True,
        "live_order_gate": "REQUESTED_AUDIT_AND_OWNER_APPROVAL_REQUIRED",
        "live_orders_enabled": False,
        "allow_live_orders": False,
        "real_trading_now": False
    },
    "required_before_live": [
        "IT audit",
        "CyberParliament review",
        "Finance/Risk audit",
        "API trade permissions check",
        "Withdrawals disabled on exchange API",
        "Paper/testnet logs checked",
        "Separate manual OWNER approval"
    ],
    "safety": SAFETY
}

out = ROOT / "data/cyberbot/actions/live_gate_policy_latest.json"
write_json(out, policy)
write_json(ROOT / "feeds/live_gate_policy.json", policy)

post = """# Live Gate Policy

Status: **LIVE_GATE_POLICY_NORMALIZED**

Live orders are **not enabled**.

- live_order_gate: `REQUESTED_AUDIT_AND_OWNER_APPROVAL_REQUIRED`
- live_orders_enabled: `false`
- allow_live_orders: `false`
- real_trading_now: `false`
- who can enable: `OWNER_ONLY_AFTER_IT_PARLIAMENT_FINANCE_AUDIT`

This is a request/checkpoint only, not live trading.
"""
(ROOT / "posts").mkdir(exist_ok=True)
(ROOT / "posts/live_gate_policy.md").write_text(post, encoding="utf-8")

proof_targets = FILES + [
    out,
    ROOT / "feeds/live_gate_policy.json",
    ROOT / "posts/live_gate_policy.md",
]
proof = ""
for p in proof_targets:
    if p.exists():
        proof += f"{sha(p)}  {p.relative_to(ROOT)}\n"

(ROOT / "proofs").mkdir(exist_ok=True)
(ROOT / "proofs/live_gate_policy.sha256").write_text(proof, encoding="utf-8")

print(json.dumps(policy, ensure_ascii=False, indent=2))
PY

echo
echo "=== CHECK ==="
cyberbot status | grep -E "live_order_gate|live_orders_enabled|real_trading_now|allow_live_orders|manual_OWNER_approval_required"

echo
echo "=== PROOF ==="
sha256sum -c proofs/live_gate_policy.sha256 2>/dev/null || true

echo
echo "✅ LIVE GATE NORMALIZED"
echo "❌ LIVE ORDERS STILL OFF"
