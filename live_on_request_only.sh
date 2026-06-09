#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== CYBERBOT LIVE ON REQUEST ONLY ==="
echo "Real live orders will remain BLOCKED."

mkdir -p \
  data/cyberbot/actions \
  data/cyberbot/config \
  data/cybra_bot_supervisor/config \
  data/cybra_finance/it_department/tasks \
  parliament/inbox \
  posts feeds proofs runtime/redis

python3 <<'PY'
import json, time, hashlib, subprocess, shutil
from pathlib import Path

ROOT = Path.home() / "CYBRA"
CYBERBOT_CFG = ROOT / "data/cyberbot/config/cyberbot_config.json"
BAR_CFG = ROOT / "data/cybra_bot_supervisor/config/bot_bar_config.json"
ACTION = ROOT / "data/cyberbot/actions/live_on_request_latest.json"

def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S")

def read_json(p, default):
    try:
        return json.loads(Path(p).read_text(encoding="utf-8"))
    except Exception:
        return default

def write_json(p, data):
    p = Path(p)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

def sha_file(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()

SAFETY = {
    "real_payment_now": False,
    "real_trading_now": False,
    "live_orders_enabled": False,
    "live_order_requested": True,
    "live_order_gate": "OWNER_APPROVAL_PENDING",
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

for cfg_path in [CYBERBOT_CFG, BAR_CFG]:
    cfg = read_json(cfg_path, {})
    cfg.update({
        "timestamp": now(),
        "live_order_requested": True,
        "live_order_gate": "OWNER_APPROVAL_PENDING",
        "live_orders_enabled": False,
        "real_trading_now": False,
        "paper_trading": True,
        "testnet_mode": True,
        "manual_OWNER_approval_required": True,
        "safety": SAFETY
    })
    write_json(cfg_path, cfg)

task_id = "LIVE-ON-REQUEST-" + time.strftime("%Y%m%d_%H%M%S")

task = {
    "task_id": task_id,
    "timestamp": now(),
    "status": "LIVE_ON_REQUEST_CREATED_NOT_ENABLED",
    "title": "Cyberbot live mode request",
    "body": "Request to review possible live mode for Bybit/Binance. Real live orders remain disabled until separate manual OWNER approval and audit.",
    "routes": {
        "it_department": True,
        "cyber_parliament": True,
        "finance_audit": True,
        "risk_audit_committee": True,
        "api_security_committee": True
    },
    "required_checks_before_any_live": [
        "API keys local only",
        "withdrawals disabled on exchange API",
        "IP restrictions checked",
        "paper/testnet logs verified",
        "PIP and risk limits verified",
        "manual OWNER approval created separately",
        "live_orders_enabled remains false until all checks pass"
    ],
    "safety": SAFETY
}

write_json(ROOT / f"data/cybra_finance/it_department/tasks/{task_id}.json", task)
write_json(ROOT / f"parliament/inbox/{task_id}.json", task)

report = {
    "timestamp": now(),
    "status": "LIVE_ON_REQUEST_ONLY_DONE",
    "task_id": task_id,
    "message": "Live ON request created. Real live orders are still blocked.",
    "live_orders_enabled": False,
    "real_trading_now": False,
    "live_order_gate": "OWNER_APPROVAL_PENDING",
    "safety": SAFETY
}
write_json(ACTION, report)
write_json(ROOT / "feeds/live_on_request_only.json", report)

post = f"""# Cyberbot Live ON Request

Status: **LIVE_ON_REQUEST_ONLY_DONE**

Task: `{task_id}`

- live_orders_enabled: `false`
- real_trading_now: `false`
- live_order_gate: `OWNER_APPROVAL_PENDING`
- manual_OWNER_approval_required: `true`

This is only a request for IT + CyberParliament + audit.
"""
write_json(ROOT / "data/cyberbot/actions/live_on_request_post.json", {"markdown": post})
(ROOT / "posts").mkdir(exist_ok=True)
(ROOT / "posts/live_on_request_only.md").write_text(post, encoding="utf-8")

if shutil.which("redis-cli"):
    try:
        subprocess.run("redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir runtime/redis --save '' --appendonly no >/dev/null 2>&1", shell=True, cwd=ROOT)
        raw = json.dumps(task, ensure_ascii=False)
        for q in ["it_department", "parliament_inbox", "cybra:audit:finance", "cybra:bot:supervised", "cyberbot:bybit", "cyberbot:binance"]:
            subprocess.run(["redis-cli", "LPUSH", q, raw], cwd=ROOT, text=True, capture_output=True)
    except Exception:
        pass

proof_targets = [
    ACTION,
    ROOT / "feeds/live_on_request_only.json",
    ROOT / "posts/live_on_request_only.md",
    CYBERBOT_CFG,
    BAR_CFG
]
proof = ""
for p in proof_targets:
    if Path(p).exists():
        proof += f"{sha_file(p)}  {Path(p).relative_to(ROOT)}\n"
(ROOT / "proofs").mkdir(exist_ok=True)
(ROOT / "proofs/live_on_request_only.sha256").write_text(proof, encoding="utf-8")

print(json.dumps(report, ensure_ascii=False, indent=2))
PY

echo
echo "=== CYBERBOT AUDIT ==="
cyberbot audit 2>/dev/null || true

echo
echo "=== CYBERBOT STATUS ==="
cyberbot status 2>/dev/null || true

echo
echo "=== PROOF ==="
sha256sum -c proofs/live_on_request_only.sha256 2>/dev/null || true

echo
echo "===================================="
echo "✅ LIVE ON REQUEST CREATED"
echo "❌ REAL LIVE ORDERS STILL BLOCKED"
echo "===================================="
