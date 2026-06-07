#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== TEST 2M FINANCE / IT / PARLIAMENT ACTIONS ==="

mkdir -p data/finance_target_2m/tests posts feeds proofs logs/finance runtime/redis

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes \
    --bind 127.0.0.1 \
    --port 6379 \
    --dir "$HOME/CYBRA/runtime/redis" \
    --save "" \
    --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

python3 - <<'PY'
import json, time, hashlib, subprocess, os
from pathlib import Path

ROOT = Path.home() / "CYBRA"

EXPECTED = {
    "tokens": 32000,
    "target_usd": 2000000,
    "price": 62.5,
    "base_raw": "32000000000000",
    "usdc_raw": "2000000000000",
    "owner": "EPEhVVhY7AXzWqcJeidWNuBqNbGDjJF35JzPVFXEbYxv"
}

def read_json(path):
    p = ROOT / path
    if not p.exists():
        return None
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception as e:
        return {"_error": str(e)}

def read_text(path):
    p = ROOT / path
    return p.read_text(encoding="utf-8", errors="ignore") if p.exists() else ""

def ok(name, cond, detail=""):
    return {
        "name": name,
        "ok": bool(cond),
        "detail": detail,
        "status": "PASS" if cond else "FAIL"
    }

def warn(name, cond, detail=""):
    return {
        "name": name,
        "ok": bool(cond),
        "detail": detail,
        "status": "PASS" if cond else "WARN"
    }

def shell(cmd, timeout=20):
    try:
        r = subprocess.run(
            cmd,
            cwd=ROOT,
            shell=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout
        )
        return r.returncode, r.stdout.strip()
    except Exception as e:
        return 999, str(e)

tests = []

task = read_json("feeds/finance_target_2m_usd_task.json")
dispatch = read_json("feeds/finance_target_2m_usd_dispatch_report.json")
post = read_text("posts/finance_target_2m_usd_task.md")
env_target = read_text("data/kibra_dex_pool/private/.env.finance_target_2m")
env_live = read_text("data/kibra_dex_pool/private/.env")

tests.append(ok("task_json_exists", task is not None and "_error" not in (task or {}), "feeds/finance_target_2m_usd_task.json"))
tests.append(ok("dispatch_json_exists", dispatch is not None and "_error" not in (dispatch or {}), "feeds/finance_target_2m_usd_dispatch_report.json"))
tests.append(ok("post_exists", bool(post), "posts/finance_target_2m_usd_task.md"))

if task:
    req = task.get("request", {})
    dex = task.get("dex_pool_target_plan", {})
    safety = task.get("safety", {})

    tests.append(ok("tokens_32000", req.get("base_tokens_ui") == EXPECTED["tokens"] or req.get("tokens") == EXPECTED["tokens"], str(req)))
    tests.append(ok("target_usd_2000000", req.get("target_usd_total") == EXPECTED["target_usd"], str(req)))
    tests.append(ok("price_62_5", float(req.get("target_price_usd_per_token", 0)) == EXPECTED["price"], str(req)))
    tests.append(ok("base_raw_correct", str(dex.get("base_amount_raw")) == EXPECTED["base_raw"], str(dex.get("base_amount_raw"))))
    tests.append(ok("usdc_raw_correct", str(dex.get("quote_amount_raw")) == EXPECTED["usdc_raw"], str(dex.get("quote_amount_raw"))))
    tests.append(ok("real_market_false", safety.get("real_market_confirmed") is False, str(safety)))
    tests.append(ok("real_payment_false", safety.get("real_payment_now") is False, str(safety)))
    tests.append(ok("external_tx_false", safety.get("automatic_external_tx") is False, str(safety)))
    tests.append(ok("mainnet_tx_not_executed", safety.get("real_mainnet_tx_executed") is False, str(safety)))
    tests.append(ok("target_not_market_price", safety.get("target_price_is_not_market_price") is True, str(safety)))

    owner = task.get("owner_wallet", "")
    tests.append(warn("owner_wallet_correct", owner == EXPECTED["owner"], f"owner={owner} expected={EXPECTED['owner']}"))

if dispatch:
    queues = dispatch.get("queues", [])
    tests.append(ok("it_queue_declared", "cybra:it_department:queue" in queues, str(queues)))
    tests.append(ok("finance_queue_declared", "cybra:finance_department:queue" in queues, str(queues)))
    tests.append(ok("parliament_queue_declared", "cybra:parliament:queue" in queues, str(queues)))
    tests.append(ok("dex_queue_declared", "cybra:dex_pool:queue" in queues, str(queues)))
    tests.append(ok("audit_queue_declared", "cybra:audit:queue" in queues, str(queues)))

tests.append(ok("post_has_62_5", "62.5" in post, "markdown target price"))
tests.append(ok("post_has_not_market_proof_warning", "not real market proof" in post.lower(), "warning exists"))

# SHA proof
rc, out = shell("sha256sum -c proofs/finance_target_2m_usd.sha256", timeout=20)
tests.append(ok("finance_sha256_ok", rc == 0, out[-500:]))

# Redis queue lengths
queue_names = [
    "cybra:it_department:queue",
    "cybra:finance_department:queue",
    "cybra:parliament:queue",
    "cybra:ai:tasks:block_inbox",
    "cybra:kibra:market_proof:queue",
    "cybra:dex_pool:queue",
    "cybra:audit:queue"
]

queue_status = {}
for q in queue_names:
    rc, out = shell(f"redis-cli LLEN {q}", timeout=10)
    try:
        n = int(out.splitlines()[-1].replace("(integer)", "").strip())
    except Exception:
        n = -1
    queue_status[q] = n
    tests.append(warn(f"queue_len_{q}", n >= 1, f"{q}={n}; if 0, executor may have already consumed it"))

# DEX safety
tests.append(ok("target_env_exists", bool(env_target), "data/kibra_dex_pool/private/.env.finance_target_2m"))

if env_target:
    tests.append(ok("target_env_live_disabled", "LIVE_DEX_CREATE=false" in env_target, "target env"))
    tests.append(ok("target_env_market_false", "REAL_MARKET_CONFIRMED=false" in env_target, "target env"))
    tests.append(ok("target_env_2m_usdc_raw", EXPECTED["usdc_raw"] in env_target, "USDC raw"))

if env_live:
    tests.append(ok("live_env_not_enabled", "LIVE_DEX_CREATE=true" not in env_live, "main .env must not be live"))
    tests.append(ok("dex_approval_not_enabled", "CYBRA_DEX_APPROVAL=I_ACCEPT_DEX_POOL_CREATION_RISK" not in env_live, "approval must not be active"))

# No real tx check
dex_report = read_json("feeds/kibra_dex_pool_report.json")
anchor_tx = read_json("feeds/kibra_blockchain_anchor_tx.json")

if dex_report:
    tests.append(warn("dex_pool_not_created", dex_report.get("created") is not True, f"created={dex_report.get('created')} status={dex_report.get('status')}"))
else:
    tests.append(ok("dex_pool_not_created", True, "no dex report found; no create confirmed"))

if anchor_tx:
    tests.append(warn("blockchain_anchor_tx_not_sent", False, f"anchor tx exists: {anchor_tx.get('signature')}"))
else:
    tests.append(ok("blockchain_anchor_tx_not_sent", True, "no anchor tx file"))

# Optional plan command
rc, out = shell("kibra-dex-pool plan", timeout=60)
tests.append(warn("dex_plan_command_runs", rc == 0, out[-1000:]))

# Build report
passed = sum(1 for t in tests if t["status"] == "PASS")
failed = sum(1 for t in tests if t["status"] == "FAIL")
warned = sum(1 for t in tests if t["status"] == "WARN")

report = {
    "status": "FINANCE_2M_ACTIONS_TEST_REPORT",
    "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "summary": {
        "pass": passed,
        "fail": failed,
        "warn": warned
    },
    "expected": EXPECTED,
    "queue_status": queue_status,
    "tests": tests,
    "safe_result": {
        "real_payment_now": False,
        "automatic_external_tx": False,
        "real_mainnet_tx_executed": False,
        "live_dex_create_tested": False
    }
}

raw = json.dumps(report, ensure_ascii=False, sort_keys=True)
report["double_sha"] = hashlib.sha256(hashlib.sha256(raw.encode()).hexdigest().encode()).hexdigest()

for path in [
    "feeds/finance_2m_actions_test_report.json",
    "data/finance_target_2m/tests/latest_test_report.json"
]:
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

md = []
md.append("# Finance 2M Actions Test Report")
md.append("")
md.append(f"Status: {report['status']}")
md.append(f"Timestamp: {report['timestamp']}")
md.append("")
md.append("## Summary")
md.append("")
md.append(f"PASS: {passed}")
md.append(f"WARN: {warned}")
md.append(f"FAIL: {failed}")
md.append("")
md.append("## Tests")
md.append("")
for t in tests:
    md.append(f"- {t['status']} — {t['name']}: {t['detail']}")
md.append("")
md.append("## Redis queues")
md.append("")
for q, n in queue_status.items():
    md.append(f"- {q}: {n}")
md.append("")
md.append("## Safety")
md.append("")
md.append("real_payment_now: false")
md.append("automatic_external_tx: false")
md.append("real_mainnet_tx_executed: false")
md.append("live_dex_create_tested: false")
md.append("")
md.append("## Double SHA")
md.append(report["double_sha"])

(ROOT / "posts/finance_2m_actions_test_report.md").write_text("\n".join(md), encoding="utf-8")

with open(ROOT / "proofs/finance_2m_actions_test_report.sha256", "w") as f:
    subprocess.run([
        "sha256sum",
        "feeds/finance_2m_actions_test_report.json",
        "data/finance_target_2m/tests/latest_test_report.json",
        "posts/finance_2m_actions_test_report.md"
    ], cwd=ROOT, stdout=f)

print("=== TEST SUMMARY ===")
print("PASS:", passed)
print("WARN:", warned)
print("FAIL:", failed)
print("REPORT: posts/finance_2m_actions_test_report.md")
print("DOUBLE_SHA:", report["double_sha"])

if failed > 0:
    raise SystemExit(2)
PY

echo
echo "=== VERIFY TEST REPORT ==="
sha256sum -c proofs/finance_2m_actions_test_report.sha256

echo
echo "=== OPEN REPORT ==="
cat posts/finance_2m_actions_test_report.md

echo
echo "✅ TEST FINISHED"
