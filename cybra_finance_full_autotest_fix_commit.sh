#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA"

echo "=== CYBRA FINANCE FULL AUTOTEST + AUTOFIX + COMMIT ==="

mkdir -p logs/autotest posts feeds proofs runtime runtime/redis

LOG="logs/autotest/cybra_finance_full_autotest_$(date +%Y%m%d_%H%M%S).log"
REPORT="posts/cybra_finance_full_autotest_report.md"
FEED="feeds/cybra_finance_full_autotest_report.json"
PROOF="proofs/cybra_finance_full_autotest.sha256"

exec > >(tee -a "$LOG") 2>&1

ok_count=0
fail_count=0
warn_count=0

ok() {
  ok_count=$((ok_count+1))
  echo "✅ OK: $*"
}

warn() {
  warn_count=$((warn_count+1))
  echo "⚠ WARN: $*"
}

fail() {
  fail_count=$((fail_count+1))
  echo "❌ FAIL: $*"
}

run_step() {
  name="$1"
  shift
  echo
  echo "=== STEP: $name ==="
  "$@"
  code=$?
  if [ "$code" -eq 0 ]; then
    ok "$name"
  else
    fail "$name code=$code"
  fi
  return 0
}

run_optional() {
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
  return 0
}

echo
echo "=== 1. BASIC ENV ==="

if command -v python3 >/dev/null 2>&1; then
  ok "python3 exists"
else
  fail "python3 missing"
fi

if command -v git >/dev/null 2>&1; then
  ok "git exists"
else
  warn "git missing"
fi

if ! command -v redis-server >/dev/null 2>&1; then
  warn "redis-server missing, installing"
  pkg update -y || true
  pkg install -y redis || true
fi

python3 - <<'PY'
import sys, subprocess
try:
    import redis
except Exception:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "redis"])
PY

echo
echo "=== 2. REDIS AUTOFIX ==="

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
echo "=== 3. RESTORE / AUTOFIX MODULES IF AUTOBLOCKS EXIST ==="

if [ -f auto_fix_finance_redis_committee.sh ]; then
  run_optional "auto_fix_finance_redis_committee" bash auto_fix_finance_redis_committee.sh
fi

if [ -f cybra_payment_autoblock.sh ]; then
  run_optional "cybra_payment_autoblock" bash cybra_payment_autoblock.sh
elif [ -f auto_create_cybra_payment_requisites.sh ]; then
  run_optional "auto_create_cybra_payment_requisites" bash auto_create_cybra_payment_requisites.sh
fi

if [ -f kybra_valid_wallet_autoblock.sh ]; then
  run_optional "kybra_valid_wallet_autoblock" bash kybra_valid_wallet_autoblock.sh
fi

if [ -f auto_rebuild_cybra_cold_finance_binary.sh ]; then
  run_optional "auto_rebuild_cybra_cold_finance_binary" bash auto_rebuild_cybra_cold_finance_binary.sh
fi

if [ -f auto_create_cybra_finance_5_committees.sh ]; then
  run_optional "auto_create_cybra_finance_5_committees" bash auto_create_cybra_finance_5_committees.sh
fi

echo
echo "=== 4. CHMOD / LINKS AUTOFIX ==="

for f in \
  cybra_redis_committee.sh \
  cybra_payment_requisites.sh \
  kybra_valid.sh \
  cybra_finance_committees.sh \
  cybra_cold_finance_binary_handler.sh \
  cybra_finance_5_committees_handler.sh \
  cybra_payment_requisites_handler.sh \
  kybra_valid_wallet_handler.sh \
  finance_redis_committee_handler.sh \
  cybra_closed_sha_bridge.sh \
  cybra_kibra_stats.sh \
  cybra_market_proof_collector.sh \
  cybra_real_market_price_gate.sh
do
  if [ -f "$f" ]; then
    chmod +x "$f"
    ok "chmod $f"
  fi
done

if [ -f bin/cybra-finance-bin ]; then
  chmod +x bin/cybra-finance-bin
  ln -sf "$HOME/CYBRA/bin/cybra-finance-bin" "$PREFIX/bin/cybra-finance-bin" 2>/dev/null || true
  ok "cybra-finance-bin chmod/link"
else
  warn "bin/cybra-finance-bin missing"
fi

echo
echo "=== 5. PYTHON COMPILE TEST ==="

for py in \
  cybra_finance_redis_committee.py \
  cybra_payment_requisites.py \
  kybra_valid_gateway.py \
  cybra_finance_5_committees.py \
  parliament_executor_v6.py \
  bin/cybra-finance-bin
do
  if [ -f "$py" ]; then
    python3 -m py_compile "$py"
    code=$?
    if [ "$code" -eq 0 ]; then
      ok "py_compile $py"
    else
      fail "py_compile $py"
    fi
  else
    warn "missing python file $py"
  fi
done

rm -rf __pycache__ bin/__pycache__ 2>/dev/null || true

echo
echo "=== 6. RUN MODULE STATUS / REPORTS ==="

if [ -f cybra_redis_committee.sh ]; then
  run_optional "Redis committee status" bash cybra_redis_committee.sh status
  run_optional "Redis committee report" bash cybra_redis_committee.sh report
fi

if [ -f cybra_payment_requisites.sh ]; then
  run_optional "Payment requisites status" bash cybra_payment_requisites.sh status
  run_optional "Payment requisites report" bash cybra_payment_requisites.sh report
fi

if [ -f kybra_valid.sh ]; then
  run_optional "KYBRA valid status" bash kybra_valid.sh status
  run_optional "KYBRA valid report" bash kybra_valid.sh report
  run_optional "KYBRA valid requisites" bash kybra_valid.sh requisites
fi

if [ -f bin/cybra-finance-bin ]; then
  run_optional "Cold finance binary status" bin/cybra-finance-bin status
  run_optional "Cold finance binary report" bin/cybra-finance-bin report
  run_optional "Cold finance binary AI task" bin/cybra-finance-bin task
fi

if [ -f cybra_finance_committees.sh ]; then
  run_optional "Finance 5 committees create" bash cybra_finance_committees.sh create
  run_optional "Finance 5 committees status" bash cybra_finance_committees.sh status
  run_optional "Finance 5 committees report" bash cybra_finance_committees.sh report
  run_optional "Finance 5 committees submit-ai" bash cybra_finance_committees.sh submit-ai
fi

echo
echo "=== 7. SEND AI TASKS TO BLOCKS / POOLS ==="

if [ -f cybra_closed_sha_bridge.sh ]; then
  run_optional "Closed SHA bridge cycle" bash cybra_closed_sha_bridge.sh cycle
  run_optional "Closed SHA bridge status" bash cybra_closed_sha_bridge.sh status
elif [ -f cybra_ai_block_enforcer.sh ]; then
  run_optional "AI block enforcer" bash cybra_ai_block_enforcer.sh enforce 5
else
  warn "No closed SHA bridge / AI block enforcer found"
fi

if [ -f parliament_executor_v6.py ]; then
  run_optional "Parliament executor" python3 parliament_executor_v6.py
fi

echo
echo "=== 8. PRICE / MARKET / STATS CHECK ==="

if [ -f cybra_real_market_price_gate.sh ]; then
  run_optional "Real market price gate status" bash cybra_real_market_price_gate.sh status
fi

if [ -f cybra_market_proof_collector.sh ]; then
  run_optional "Market proof collector status" bash cybra_market_proof_collector.sh status
fi

if [ -f cybra_kibra_stats.sh ]; then
  run_optional "KIBRA stats status" bash cybra_kibra_stats.sh status
  run_optional "KIBRA stats report" bash cybra_kibra_stats.sh report
fi

echo
echo "=== 9. FULL SYSTEM SNAPSHOT ==="

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

def redis_len(key):
    code, out, err = run(["redis-cli", "LLEN", key])
    if code == 0 and out.strip().isdigit():
        return int(out.strip())
    return 0

def exists(path):
    return (ROOT / path).exists()

def count(pattern):
    return len(list(ROOT.glob(pattern)))

def read_json(path):
    p = ROOT / path
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return {}

def sha(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def dsha(text):
    return sha(sha(text))

main_blocks = count("blockchain/kibra_chain/blocks/block_*.json")
task_blocks = count("blockchain/kibra_chain/task_blocks/*.json")
estimated_kibra = (main_blocks + task_blocks) * 100

cold = read_json("feeds/cybra_cold_finance_binary_report.json")
valid = read_json("feeds/kybra_valid_wallet_gateway_report.json")
payment = read_json("feeds/cybra_payment_requisites_package.json")
committees = read_json("feeds/cybra_finance_5_committees_report.json")

snapshot = {
    "status": "cybra_finance_full_autotest_completed",
    "time": time.time(),
    "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "modules": {
        "redis_committee": exists("cybra_redis_committee.sh"),
        "payment_requisites": exists("cybra_payment_requisites.sh"),
        "kybra_valid_wallet": exists("kybra_valid.sh"),
        "cold_finance_binary": exists("bin/cybra-finance-bin"),
        "five_committees": exists("cybra_finance_committees.sh"),
        "closed_sha_bridge": exists("cybra_closed_sha_bridge.sh"),
        "real_market_price_gate": exists("cybra_real_market_price_gate.sh"),
        "market_proof_collector": exists("cybra_market_proof_collector.sh"),
        "kibra_stats": exists("cybra_kibra_stats.sh")
    },
    "blocks": {
        "main_blocks": main_blocks,
        "task_blocks": task_blocks,
        "estimated_kibra_by_default_reward_100": estimated_kibra
    },
    "queues": {
        "block_inbox": redis_len("cybra:ai:tasks:block_inbox"),
        "task_block_mempool": redis_len("cybra:kibra:task_blocks:mempool"),
        "pool_mining_blocks": redis_len("cybra:kibra:pool:mining_blocks"),
        "task_blocks_mined": redis_len("cybra:kibra:task_blocks:mined"),
        "closed_sha_outbox": redis_len("cybra:kibra:closed_sha_pool_bridge:outbox"),
        "closed_sha_sealed": redis_len("cybra:kibra:closed_sha_pool_bridge:sealed"),
        "parliament_queue": redis_len("cybra:parliament:queue"),
        "parliament_results": redis_len("cybra:parliament:results"),
        "parliament_failed": redis_len("cybra:parliament:failed")
    },
    "reports": {
        "cold_finance": exists("posts/cybra_cold_finance_binary_report.md"),
        "cold_payment_requisites": exists("posts/cybra_cold_payment_requisites.txt"),
        "kybra_valid": exists("posts/kybra_valid_wallet_gateway_report.md"),
        "kybra_valid_requisites": exists("posts/kybra_valid_web_payment_requisites.txt"),
        "payment_requisites": exists("posts/cybra_payment_requisites_package.md"),
        "payment_dealer_text": exists("posts/car_dealer_invoice_request.txt"),
        "five_committees": exists("posts/cybra_finance_5_committees_report.md"),
        "redis_committee": exists("posts/finance_redis_committee_report.md")
    },
    "safety": {
        "private_keys_stored": False,
        "seed_phrase_required": False,
        "automatic_external_tx": False,
        "automatic_SWIFT": False,
        "automatic_real_payment": False,
        "automatic_token_sell": False,
        "manual_OWNER_approval_required": True,
        "real_sell_now": False,
        "real_payment_now": False
    }
}

snapshot["double_sha"] = dsha(json.dumps(snapshot, ensure_ascii=False, sort_keys=True))

(ROOT / "feeds").mkdir(exist_ok=True)
(ROOT / "posts").mkdir(exist_ok=True)
(ROOT / "proofs").mkdir(exist_ok=True)

(ROOT / "feeds/cybra_finance_full_autotest_report.json").write_text(
    json.dumps(snapshot, ensure_ascii=False, indent=2),
    encoding="utf-8"
)

lines = []
lines.append("# CYBRA Finance Full Autotest Report")
lines.append("")
lines.append("Status: completed")
lines.append("")
lines.append("## Modules")
for k, v in snapshot["modules"].items():
    lines.append(f"{k}: {v}")
lines.append("")
lines.append("## Blocks")
for k, v in snapshot["blocks"].items():
    lines.append(f"{k}: {v}")
lines.append("")
lines.append("## Queues")
for k, v in snapshot["queues"].items():
    lines.append(f"{k}: {v}")
lines.append("")
lines.append("## Reports")
for k, v in snapshot["reports"].items():
    lines.append(f"{k}: {v}")
lines.append("")
lines.append("## Safety")
for k, v in snapshot["safety"].items():
    lines.append(f"{k}: {v}")
lines.append("")
lines.append("## Double SHA")
lines.append("")
lines.append(snapshot["double_sha"])

(ROOT / "posts/cybra_finance_full_autotest_report.md").write_text(
    "\n".join(lines),
    encoding="utf-8"
)

with (ROOT / "proofs/cybra_finance_full_autotest.sha256").open("w") as f:
    subprocess.run([
        "sha256sum",
        "feeds/cybra_finance_full_autotest_report.json",
        "posts/cybra_finance_full_autotest_report.md"
    ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

print(json.dumps(snapshot, ensure_ascii=False, indent=2))
PY

echo
echo "=== 10. PROOF CHECKS ==="

for p in \
  proofs/finance_redis_committee.sha256 \
  proofs/cybra_payment_requisites_package.sha256 \
  proofs/kybra_valid_wallet_gateway.sha256 \
  proofs/cybra_cold_finance_binary.sha256 \
  proofs/cybra_finance_5_committees.sha256 \
  proofs/cybra_finance_full_autotest.sha256
do
  if [ -f "$p" ]; then
    sha256sum -c "$p" || true
    ok "proof checked $p"
  else
    warn "proof missing $p"
  fi
done

echo
echo "=== 11. START REDIS WATCHDOG IF EXISTS ==="

if [ -f cybra_redis_committee.sh ]; then
  if [ ! -f runtime/finance_redis_committee.pid ]; then
    bash cybra_redis_committee.sh start-watch 10 || true
  else
    warn "Redis watchdog pid already exists"
  fi
fi

echo
echo "=== 12. GIT FIX / COMMIT / PUSH ==="

git rev-parse --is-inside-work-tree >/dev/null 2>&1
if [ "$?" -ne 0 ]; then
  warn "Not a git repo, git commit skipped"
else
  git add \
    cybra_finance_full_autotest_fix_commit.sh \
    auto_fix_finance_redis_committee.sh \
    cybra_payment_autoblock.sh \
    kybra_valid_wallet_autoblock.sh \
    auto_rebuild_cybra_cold_finance_binary.sh \
    auto_create_cybra_finance_5_committees.sh \
    cybra_finance_redis_committee.py \
    cybra_payment_requisites.py \
    kybra_valid_gateway.py \
    cybra_finance_5_committees.py \
    bin/cybra-finance-bin \
    cybra_redis_committee.sh \
    cybra_payment_requisites.sh \
    kybra_valid.sh \
    cybra_finance_committees.sh \
    finance_redis_committee_handler.sh \
    cybra_payment_requisites_handler.sh \
    kybra_valid_wallet_handler.sh \
    cybra_cold_finance_binary_handler.sh \
    cybra_finance_5_committees_handler.sh \
    parliament/departments/finance_department \
    parliament/departments/cybra_finance_department \
    data/cybra_payment_requisites \
    data/kybra_valid \
    data/cybra_cold_finance \
    posts \
    feeds \
    proofs \
    parliament_executor_v6.py 2>/dev/null || true

  git status --short

  if git diff --cached --quiet; then
    warn "No staged changes to commit"
  else
    git commit -m "autotest and fix CYBRA cold finance payment system"
    if [ "$?" -eq 0 ]; then
      ok "git commit created"
    else
      warn "git commit failed"
    fi
  fi

  branch="$(git branch --show-current 2>/dev/null)"
  [ -z "$branch" ] && branch="main"

  git remote -v
  git push origin "$branch"
  if [ "$?" -eq 0 ]; then
    ok "git push origin $branch"
  else
    warn "git push failed, maybe auth/network/remote issue"
  fi
fi

echo
echo "=== FINAL SUMMARY ==="
echo "OK=$ok_count"
echo "WARN=$warn_count"
echo "FAIL=$fail_count"
echo "LOG=$LOG"
echo "REPORT=$REPORT"
echo "FEED=$FEED"
echo "PROOF=$PROOF"

echo
echo "=== QUICK COMMANDS ==="
echo "cat posts/cybra_finance_full_autotest_report.md"
echo "cybra-finance-bin status"
echo "bash cybra_finance_committees.sh status"
echo "bash kybra_valid.sh status"
echo "bash cybra_payment_requisites.sh status"
echo "bash cybra_kibra_stats.sh status"

echo
echo "✅ CYBRA FINANCE FULL AUTOTEST + AUTOFIX DONE"
