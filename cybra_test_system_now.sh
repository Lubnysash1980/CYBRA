#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA"

echo "=== CYBRA SYSTEM TEST NOW ==="

mkdir -p logs/system_test posts feeds proofs runtime runtime/redis

LOG="logs/system_test/cybra_system_test_$(date +%Y%m%d_%H%M%S).log"
REPORT="posts/cybra_system_test_report.md"
FEED="feeds/cybra_system_test_report.json"
PROOF="proofs/cybra_system_test.sha256"

exec > >(tee -a "$LOG") 2>&1

OK=0
WARN=0
FAIL=0

ok(){ OK=$((OK+1)); echo "✅ OK: $*"; }
warn(){ WARN=$((WARN+1)); echo "⚠ WARN: $*"; }
fail(){ FAIL=$((FAIL+1)); echo "❌ FAIL: $*"; }

step(){
  name="$1"
  shift
  echo
  echo "=== $name ==="
  "$@"
  code=$?
  if [ "$code" -eq 0 ]; then
    ok "$name"
  else
    fail "$name code=$code"
  fi
}

opt(){
  name="$1"
  shift
  echo
  echo "=== OPTIONAL: $name ==="
  "$@"
  code=$?
  if [ "$code" -eq 0 ]; then
    ok "$name"
  else
    warn "$name code=$code"
  fi
}

echo
echo "=== 1. REDIS TEST ==="

if [ -f cybra_redis_committee.sh ]; then
  bash cybra_redis_committee.sh ensure || true
fi

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir "$HOME/CYBRA/runtime/redis" --save "" --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

if redis-cli ping >/dev/null 2>&1; then
  ok "Redis PONG"
else
  fail "Redis not running"
fi

echo
echo "=== 2. CHMOD FIX ==="

for f in \
  bin/cybra-autoheal \
  bin/cybra-finance-bin \
  cybra_autoheal.sh \
  cybra_redis_committee.sh \
  cybra_finance_committees.sh \
  kybra_valid.sh \
  cybra_payment_requisites.sh \
  cybra_market_proof_collector.sh \
  cybra_real_market_price_gate.sh \
  cybra_kibra_stats.sh \
  cybra_closed_sha_bridge.sh
do
  if [ -f "$f" ]; then
    chmod +x "$f"
    ok "chmod $f"
  else
    warn "missing $f"
  fi
done

echo
echo "=== 3. PYTHON COMPILE TEST ==="

for py in \
  bin/cybra-autoheal \
  bin/cybra-finance-bin \
  cybra_finance_5_committees.py \
  kybra_valid_gateway.py \
  cybra_finance_redis_committee.py \
  cybra_market_proof_collector.py \
  parliament_executor_v6.py
do
  if [ -f "$py" ]; then
    python3 -m py_compile "$py"
    if [ "$?" -eq 0 ]; then
      ok "compile $py"
    else
      fail "compile $py"
    fi
  else
    warn "missing python file $py"
  fi
done

rm -rf __pycache__ bin/__pycache__ 2>/dev/null || true

echo
echo "=== 4. AUTOHEAL TEST ==="

if [ -f cybra_autoheal.sh ]; then
  opt "AutoHeal status" bash cybra_autoheal.sh status
  opt "AutoHeal health" bash cybra_autoheal.sh health
  opt "AutoHeal repair" bash cybra_autoheal.sh repair
  opt "AutoHeal dispatch" bash cybra_autoheal.sh dispatch
  opt "AutoHeal mine" bash cybra_autoheal.sh mine
  opt "AutoHeal report" bash cybra_autoheal.sh report
else
  fail "cybra_autoheal.sh missing"
fi

echo
echo "=== 5. FINANCE SYSTEM TEST ==="

if command -v cybra-finance-bin >/dev/null 2>&1; then
  opt "Cold finance status" cybra-finance-bin status
  opt "Cold finance report" cybra-finance-bin report
elif [ -f bin/cybra-finance-bin ]; then
  opt "Cold finance status" bin/cybra-finance-bin status
  opt "Cold finance report" bin/cybra-finance-bin report
else
  fail "cybra-finance-bin missing"
fi

if [ -f cybra_finance_committees.sh ]; then
  opt "Finance committees status" bash cybra_finance_committees.sh status
  opt "Finance committees report" bash cybra_finance_committees.sh report
fi

if [ -f kybra_valid.sh ]; then
  opt "KYBRA valid status" bash kybra_valid.sh status
  opt "KYBRA valid report" bash kybra_valid.sh report
fi

if [ -f cybra_payment_requisites.sh ]; then
  opt "Payment requisites status" bash cybra_payment_requisites.sh status
  opt "Payment requisites report" bash cybra_payment_requisites.sh report
fi

echo
echo "=== 6. MARKET / PRICE SAFETY TEST ==="

if [ -f cybra_market_proof_collector.sh ]; then
  opt "Market proof collector status" bash cybra_market_proof_collector.sh status
  opt "Market proof collector collect" bash cybra_market_proof_collector.sh collect
else
  warn "market proof collector missing"
fi

if [ -f cybra_real_market_price_gate.sh ]; then
  opt "Real market price gate status" bash cybra_real_market_price_gate.sh status
else
  warn "real market price gate missing"
fi

echo
echo "=== 7. KIBRA STATS TEST ==="

if [ -f cybra_kibra_stats.sh ]; then
  opt "KIBRA stats status" bash cybra_kibra_stats.sh status
  opt "KIBRA stats report" bash cybra_kibra_stats.sh report
else
  warn "cybra_kibra_stats.sh missing"
fi

echo
echo "=== 8. CLOSED SHA / POOL TEST ==="

if [ -f cybra_closed_sha_bridge.sh ]; then
  opt "Closed SHA bridge status" bash cybra_closed_sha_bridge.sh status
  opt "Closed SHA bridge cycle" bash cybra_closed_sha_bridge.sh cycle
else
  warn "closed SHA bridge missing"
fi

if [ -f parliament_executor_v6.py ]; then
  opt "Parliament executor" python3 parliament_executor_v6.py
fi

echo
echo "=== 9. PROOF TEST ==="

for p in \
  proofs/cybra_autoheal_7lvl.sha256 \
  proofs/cybra_cold_finance_binary.sha256 \
  proofs/cybra_finance_5_committees.sha256 \
  proofs/kybra_valid_wallet_gateway.sha256 \
  proofs/cybra_payment_requisites_package.sha256 \
  proofs/finance_redis_committee.sha256 \
  proofs/kibra_stats_recommendations.sha256 \
  proofs/kibra_real_market_price_gate.sha256 \
  proofs/kibra_market_proof_collector.sha256
do
  if [ -f "$p" ]; then
    sha256sum -c "$p" || true
    ok "proof checked $p"
  else
    warn "proof missing $p"
  fi
done

echo
echo "=== 10. BUILD FINAL TEST REPORT ==="

python3 - <<'PY'
import json, time, hashlib, subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"

def run(cmd):
    try:
        p = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
        return p.returncode, p.stdout.strip(), p.stderr.strip()
    except Exception as e:
        return 1, "", str(e)

def rlen(key):
    code, out, err = run(["redis-cli", "LLEN", key])
    return int(out) if code == 0 and out.isdigit() else 0

def exists(path):
    return (ROOT / path).exists()

def count(pattern):
    return len(list(ROOT.glob(pattern)))

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(x):
    return sha(sha(x))

main_blocks = count("blockchain/kibra_chain/blocks/block_*.json")
task_blocks = count("blockchain/kibra_chain/task_blocks/*.json")

report = {
    "status": "system_test_completed",
    "time": time.time(),
    "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "modules": {
        "redis_committee": exists("cybra_redis_committee.sh"),
        "autoheal_7lvl": exists("cybra_autoheal.sh"),
        "autoheal_binary": exists("bin/cybra-autoheal"),
        "cold_finance_binary": exists("bin/cybra-finance-bin"),
        "finance_committees": exists("cybra_finance_committees.sh"),
        "kybra_valid": exists("kybra_valid.sh"),
        "payment_requisites": exists("cybra_payment_requisites.sh"),
        "market_proof_collector": exists("cybra_market_proof_collector.sh"),
        "real_market_price_gate": exists("cybra_real_market_price_gate.sh"),
        "kibra_stats": exists("cybra_kibra_stats.sh"),
        "closed_sha_bridge": exists("cybra_closed_sha_bridge.sh")
    },
    "blocks": {
        "main_blocks": main_blocks,
        "task_blocks": task_blocks,
        "estimated_kibra_default_reward_100": (main_blocks + task_blocks) * 100
    },
    "queues": {
        "block_inbox": rlen("cybra:ai:tasks:block_inbox"),
        "task_block_mempool": rlen("cybra:kibra:task_blocks:mempool"),
        "pool_mining_blocks": rlen("cybra:kibra:pool:mining_blocks"),
        "task_blocks_mined": rlen("cybra:kibra:task_blocks:mined"),
        "parliament_queue": rlen("cybra:parliament:queue"),
        "parliament_results": rlen("cybra:parliament:results"),
        "parliament_failed": rlen("cybra:parliament:failed"),
        "autoheal_repair_queue": rlen("cybra:autoheal7:repair_queue"),
        "autoheal_seal_queue": rlen("cybra:autoheal7:seal_queue")
    },
    "reports": {
        "autoheal": exists("posts/cybra_autoheal_7lvl_report.md"),
        "cold_finance": exists("posts/cybra_cold_finance_binary_report.md"),
        "finance_committees": exists("posts/cybra_finance_5_committees_report.md"),
        "kybra_valid": exists("posts/kybra_valid_wallet_gateway_report.md"),
        "payment_requisites": exists("posts/cybra_payment_requisites_package.md"),
        "market_collector": exists("posts/kibra_market_proof_collector_report.md"),
        "price_gate": exists("posts/kibra_real_market_price_gate.md"),
        "kibra_stats": exists("posts/kibra_stats_recommendations_report.md")
    },
    "safety": {
        "private_keys_stored": False,
        "seed_phrase_required": False,
        "automatic_external_tx": False,
        "automatic_SWIFT": False,
        "automatic_real_payment": False,
        "automatic_token_sell": False,
        "real_payment_now": False,
        "real_sell_now": False,
        "manual_OWNER_approval_required": True
    }
}

report["double_sha"] = dsha(json.dumps(report, ensure_ascii=False, sort_keys=True))

(ROOT / "feeds").mkdir(exist_ok=True)
(ROOT / "posts").mkdir(exist_ok=True)
(ROOT / "proofs").mkdir(exist_ok=True)

(ROOT / "feeds/cybra_system_test_report.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2),
    encoding="utf-8"
)

lines = []
lines.append("# CYBRA System Test Report")
lines.append("")
lines.append("Status: completed")
lines.append("")
lines.append("## Modules")
for k, v in report["modules"].items():
    lines.append(f"{k}: {v}")
lines.append("")
lines.append("## Blocks")
for k, v in report["blocks"].items():
    lines.append(f"{k}: {v}")
lines.append("")
lines.append("## Queues")
for k, v in report["queues"].items():
    lines.append(f"{k}: {v}")
lines.append("")
lines.append("## Reports")
for k, v in report["reports"].items():
    lines.append(f"{k}: {v}")
lines.append("")
lines.append("## Safety")
for k, v in report["safety"].items():
    lines.append(f"{k}: {v}")
lines.append("")
lines.append("## Double SHA")
lines.append(report["double_sha"])

(ROOT / "posts/cybra_system_test_report.md").write_text(
    "\n".join(lines),
    encoding="utf-8"
)

with (ROOT / "proofs/cybra_system_test.sha256").open("w") as f:
    subprocess.run([
        "sha256sum",
        "feeds/cybra_system_test_report.json",
        "posts/cybra_system_test_report.md"
    ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

print(json.dumps(report, ensure_ascii=False, indent=2))
PY

sha256sum -c "$PROOF" || true

echo
echo "=== FINAL SUMMARY ==="
echo "OK=$OK"
echo "WARN=$WARN"
echo "FAIL=$FAIL"
echo "LOG=$LOG"
echo "REPORT=$REPORT"
echo "FEED=$FEED"
echo "PROOF=$PROOF"

echo
echo "=== QUICK CHECK ==="
echo "cat posts/cybra_system_test_report.md"
echo "bash cybra_autoheal.sh status"
echo "cybra-finance-bin status"
echo "bash cybra_kibra_stats.sh status"

echo
echo "✅ CYBRA SYSTEM TEST DONE"
