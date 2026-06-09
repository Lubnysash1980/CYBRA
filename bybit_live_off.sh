#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== BYBIT LIVE OFF / SAFE MODE ==="

mkdir -p \
  data/cyberbot/actions \
  data/cyberbot/config \
  data/cybra_bot_supervisor/config \
  data/cybra_finance/it_department/tasks \
  parliament/inbox \
  proofs feeds posts \
  .cybra_local_secret/exchanges

grep -qxF ".cybra_local_secret/" .gitignore 2>/dev/null || echo ".cybra_local_secret/" >> .gitignore

echo
echo "=== STOP LIVE GATES ==="
cyberbot live-block 2>/dev/null || true
cybra-bot-bar live-block 2>/dev/null || true

echo
echo "=== STOP CURRENT SUPERVISOR PROCESS FOR SAFETY ==="
cybra-bot-supervised stop 2>/dev/null || true

python3 <<'PY'
import json, time, hashlib, subprocess, shutil, os
from pathlib import Path

ROOT = Path.home() / "CYBRA"
SECRET = ROOT / ".cybra_local_secret/exchanges/bybit.json"
CYBERBOT_CFG = ROOT / "data/cyberbot/config/cyberbot_config.json"
BAR_CFG = ROOT / "data/cybra_bot_supervisor/config/bot_bar_config.json"
ACTION = ROOT / "data/cyberbot/actions/bybit_live_disabled_latest.json"
TASK_DIR = ROOT / "data/cybra_finance/it_department/tasks"
PARL_DIR = ROOT / "parliament/inbox"

def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S")

def read_json(p, default):
    try:
        return json.loads(Path(p).read_text(encoding="utf-8"))
    except Exception:
        return default

def write_json(p, data, mode=None):
    p = Path(p)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    if mode:
        try:
            os.chmod(p, mode)
        except Exception:
            pass

def sha_file(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()

SAFETY = {
    "real_payment_now": False,
    "real_trading_now": False,
    "live_orders_enabled": False,
    "bybit_live_enabled": False,
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

# 1) Bybit local secret: ключ залишаємо, live блокуємо
bybit = read_json(SECRET, {})
if bybit:
    bybit["timestamp"] = now()
    bybit["exchange"] = "bybit"
    bybit["testnet"] = True
    bybit["paper_trading"] = True
    bybit["real_trading_now"] = False
    bybit["live_orders_enabled"] = False
    bybit["allow_live_orders"] = False
    bybit["bybit_live_enabled"] = False
    bybit["bybit_live_disabled_at"] = now()
    bybit["manual_OWNER_approval_required"] = True
    bybit["safety"] = SAFETY
    write_json(SECRET, bybit, 0o600)

# 2) Cyberbot config
cfg = read_json(CYBERBOT_CFG, {})
cfg.update({
    "timestamp": now(),
    "selected_exchange": "bybit",
    "paper_trading": True,
    "testnet_mode": True,
    "real_trading_now": False,
    "live_orders_enabled": False,
    "allow_live_orders": False,
    "bybit_live_enabled": False,
    "live_order_gate": "BYBIT_LIVE_DISABLED",
    "manual_OWNER_approval_required": True,
    "safety": SAFETY
})
write_json(CYBERBOT_CFG, cfg)

# 3) Bot bar config
bar = read_json(BAR_CFG, {})
bar.update({
    "timestamp": now(),
    "selected_exchange": "bybit",
    "paper_trading": True,
    "testnet_mode": True,
    "real_trading_now": False,
    "live_orders_enabled": False,
    "allow_live_orders": False,
    "bybit_live_enabled": False,
    "live_order_gate": "BYBIT_LIVE_DISABLED",
    "manual_OWNER_approval_required": True,
    "safety": SAFETY
})
write_json(BAR_CFG, bar)

# 4) Task в IT + Parliament
task_id = "BYBIT-LIVE-OFF-" + time.strftime("%Y%m%d_%H%M%S")
task = {
    "task_id": task_id,
    "timestamp": now(),
    "status": "BYBIT_LIVE_DISABLED",
    "title": "Bybit live mode disabled",
    "body": "Bybit live-orders are disabled. Paper/testnet mode remains allowed. API key remains local-only.",
    "routes": {
        "it_department": True,
        "cyber_parliament": True,
        "finance_audit": True,
        "cyberbot": True
    },
    "safety": SAFETY
}
write_json(TASK_DIR / f"{task_id}.json", task)
write_json(PARL_DIR / f"{task_id}.json", task)

# 5) Action report
report = {
    "timestamp": now(),
    "status": "BYBIT_LIVE_OFF_DONE",
    "bybit_secret_exists": SECRET.exists(),
    "bybit_secret_file": ".cybra_local_secret/exchanges/bybit.json",
    "bybit_testnet_now": True if bybit else None,
    "live_orders_enabled": False,
    "real_trading_now": False,
    "paper_trading": True,
    "testnet_mode": True,
    "task_id": task_id,
    "safety": SAFETY
}
write_json(ACTION, report)

# 6) Redis queues
if shutil.which("redis-cli"):
    try:
        subprocess.run("redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir runtime/redis --save '' --appendonly no >/dev/null 2>&1", shell=True, cwd=ROOT)
        raw = json.dumps(report, ensure_ascii=False)
        for q in ["cybra:bot:supervised", "cybra:audit:finance", "parliament_inbox", "it_department", "cyberbot:bybit"]:
            subprocess.run(["redis-cli", "LPUSH", q, raw], cwd=ROOT, text=True, capture_output=True)
    except Exception:
        pass

# 7) Feed/post/proof
write_json(ROOT / "feeds/bybit_live_off.json", report)
post = f"""# Bybit Live OFF

Status: **BYBIT_LIVE_OFF_DONE**

- Bybit live orders enabled: `false`
- Real trading now: `false`
- Paper trading: `true`
- Testnet mode: `true`
- API secret storage: `.cybra_local_secret/exchanges/bybit.json`
- Git safe: `true`
- Task: `{task_id}`

Live mode can only be requested again through audit and OWNER approval.
"""
(ROOT / "posts").mkdir(exist_ok=True)
(ROOT / "posts/bybit_live_off.md").write_text(post, encoding="utf-8")

proof_targets = [
    ACTION,
    ROOT / "feeds/bybit_live_off.json",
    ROOT / "posts/bybit_live_off.md",
    CYBERBOT_CFG,
    BAR_CFG,
]
proof = ""
for p in proof_targets:
    if Path(p).exists():
        proof += f"{sha_file(p)}  {Path(p).relative_to(ROOT)}\n"
(ROOT / "proofs").mkdir(exist_ok=True)
(ROOT / "proofs/bybit_live_off.sha256").write_text(proof, encoding="utf-8")

print(json.dumps(report, ensure_ascii=False, indent=2))
PY

echo
echo "=== STATUS AFTER BYBIT LIVE OFF ==="
cyberbot status 2>/dev/null || true

echo
echo "=== AUDIT ==="
cyberbot audit 2>/dev/null || true

echo
echo "=== PROOF ==="
sha256sum -c proofs/bybit_live_off.sha256 2>/dev/null || true

echo
echo "===================================="
echo "✅ BYBIT LIVE OFF DONE"
echo "===================================="
echo "Bybit:"
echo "  live_orders_enabled=false"
echo "  real_trading_now=false"
echo "  paper_trading=true"
echo "  testnet_mode=true"
echo
echo "Supervisor was stopped for safety."
echo "To run again in PAPER mode:"
echo "  cyberbot start"
echo "===================================="
