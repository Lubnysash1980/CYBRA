#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA"

echo "=== CYBRA TEST + AUTOFIX + RECOMMENDATIONS ==="

mkdir -p posts feeds proofs logs/test_autofix runtime/redis data/cybra_test_autofix

LOG="logs/test_autofix/cybra_test_autofix_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

OK=0
WARN=0
FAIL=0

ok(){ OK=$((OK+1)); echo "✅ OK: $*"; }
warn(){ WARN=$((WARN+1)); echo "⚠ WARN: $*"; }
fail(){ FAIL=$((FAIL+1)); echo "❌ FAIL: $*"; }

run_opt(){
  name="$1"
  shift
  echo
  echo "=== $name ==="
  "$@"
  code=$?
  if [ "$code" -eq 0 ]; then
    ok "$name"
  else
    warn "$name code=$code"
  fi
}

echo
echo "=== 1. REDIS AUTOFIX ==="

if [ -f cybra_redis_committee.sh ]; then
  bash cybra_redis_committee.sh ensure || true
fi

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes \
    --bind 127.0.0.1 \
    --port 6379 \
    --dir "$HOME/CYBRA/runtime/redis" \
    --save "" \
    --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

if redis-cli ping >/dev/null 2>&1; then
  ok "Redis PONG"
else
  fail "Redis not running"
fi

echo
echo "=== 2. CHMOD AUTOFIX ==="

for f in \
  bin/cybra-recover \
  bin/cybra-autoheal \
  bin/cybra-security-analytics \
  bin/cybra-conformation8 \
  bin/cybra-finance-bin \
  cybra_recovery.sh \
  cybra_autoheal.sh \
  cybra_security_analytics.sh \
  cybra_conformation8.sh \
  cybra_redis_committee.sh \
  cybra_payment_requisites.sh \
  kybra_valid.sh \
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
  bin/cybra-recover \
  bin/cybra-autoheal \
  bin/cybra-security-analytics \
  bin/cybra-conformation8 \
  bin/cybra-finance-bin \
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
echo "=== 4. PRIVACY AUTOFIX BEFORE REPORTS ==="

python3 - <<'PY'
import json
from pathlib import Path

ROOT = Path.home() / "CYBRA"
profile = ROOT / "data/cybra_payment_requisites/payer_profile.json"
tax_id = ""

if profile.exists():
    try:
        tax_id = str(json.loads(profile.read_text(encoding="utf-8")).get("payer_tax_id_or_edrpou", ""))
    except Exception:
        tax_id = ""

if tax_id:
    masked = tax_id[:4] + "******"
    for folder in ["posts", "feeds"]:
        d = ROOT / folder
        if d.exists():
            for p in list(d.glob("*.md")) + list(d.glob("*.json")):
                text = p.read_text(encoding="utf-8", errors="ignore")
                if tax_id in text:
                    p.write_text(text.replace(tax_id, masked), encoding="utf-8")

    private_dir = ROOT / "data/cybra_payment_requisites/private"
    private_dir.mkdir(parents=True, exist_ok=True)
    local = private_dir / "payer_identity.local.json"
    if not local.exists():
        local.write_text(json.dumps({
            "status": "private_identity_local_only",
            "private_local_only": True,
            "do_not_commit": True
        }, ensure_ascii=False, indent=2), encoding="utf-8")
        local.chmod(0o600)
PY

cat >> .gitignore <<'EOF'

# CYBRA private safety
runtime/
logs/
*.log
*.pid
dump.rdb
*.rdb
.env
*.key
*.pem
id_rsa
id_ed25519
*private*
*secret*
*token*
data/cybra_payment_requisites/private/
posts/private/
feeds/private/
proofs/private/
*.local.json
owner_identity*
payer_identity*
EOF

git rm --cached dump.rdb >/dev/null 2>&1 || true
git update-index --skip-worktree data/cybra_payment_requisites/payer_profile.json 2>/dev/null || true

ok "privacy guard applied"

echo
echo "=== 5. RUN SYSTEM TESTS + AUTOFIX CYCLES ==="

[ -f cybra_recovery.sh ] && run_opt "AutoRecovery report" bash cybra_recovery.sh report
[ -f restore_autorecovery_report_only.sh ] && [ ! -f posts/cybra_autorecovery_report.md ] && run_opt "Restore AutoRecovery report only" bash restore_autorecovery_report_only.sh

[ -f cybra_security_analytics.sh ] && run_opt "Security Analytics cycle" bash cybra_security_analytics.sh cycle
[ -f cybra_conformation8.sh ] && run_opt "Conformation8 cycle" bash cybra_conformation8.sh cycle
[ -f cybra_autoheal.sh ] && run_opt "AutoHeal cycle" bash cybra_autoheal.sh cycle

[ -f cybra_payment_requisites.sh ] && run_opt "Payment requisites report" bash cybra_payment_requisites.sh report
[ -f kybra_valid.sh ] && run_opt "KYBRA valid report" bash kybra_valid.sh report
[ -f cybra_market_proof_collector.sh ] && run_opt "Market proof collector" bash cybra_market_proof_collector.sh collect
[ -f cybra_real_market_price_gate.sh ] && run_opt "Real market price gate" bash cybra_real_market_price_gate.sh status
[ -f cybra_kibra_stats.sh ] && run_opt "KIBRA stats report" bash cybra_kibra_stats.sh report
[ -f cybra_closed_sha_bridge.sh ] && run_opt "Closed SHA bridge cycle" bash cybra_closed_sha_bridge.sh cycle
[ -f parliament_executor_v6.py ] && run_opt "Parliament executor" python3 parliament_executor_v6.py

echo
echo "=== 6. REMASK PUBLIC FILES AFTER REPORTS ==="

python3 - <<'PY'
import json
from pathlib import Path

ROOT = Path.home() / "CYBRA"
profile = ROOT / "data/cybra_payment_requisites/payer_profile.json"
tax_id = ""

if profile.exists():
    try:
        tax_id = str(json.loads(profile.read_text(encoding="utf-8")).get("payer_tax_id_or_edrpou", ""))
    except Exception:
        tax_id = ""

if tax_id:
    masked = tax_id[:4] + "******"
    for folder in ["posts", "feeds"]:
        d = ROOT / folder
        if d.exists():
            for p in list(d.glob("*.md")) + list(d.glob("*.json")):
                text = p.read_text(encoding="utf-8", errors="ignore")
                if tax_id in text:
                    p.write_text(text.replace(tax_id, masked), encoding="utf-8")
PY

echo
echo "=== 7. BUILD RECOMMENDATIONS REPORT ==="

python3 - <<'PY'
import json
import time
import hashlib
import subprocess
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
    return int(out) if code == 0 and out.strip().isdigit() else 0

def exists(path):
    return (ROOT / path).exists()

def count(pattern):
    return len(list(ROOT.glob(pattern)))

def load_json(path, default=None):
    p = ROOT / path
    if not p.exists():
        return default if default is not None else {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return default if default is not None else {}

def read_text(path):
    p = ROOT / path
    if not p.exists():
        return ""
    return p.read_text(encoding="utf-8", errors="ignore")

def dsha(obj):
    text = json.dumps(obj, ensure_ascii=False, sort_keys=True)
    h1 = hashlib.sha256(text.encode("utf-8")).hexdigest()
    return hashlib.sha256(h1.encode("utf-8")).hexdigest()

def extract_section(text, start_header):
    lines = text.splitlines()
    out = []
    active = False
    for line in lines:
        if line.strip().startswith(start_header):
            active = True
            continue
        if active and line.startswith("## "):
            break
        if active:
            if line.strip():
                out.append(line.strip())
    return out

def scan_logs():
    log_dir = ROOT / "logs"
    hits = []
    if not log_dir.exists():
        return {"errors": 0, "warnings": 0, "hits": []}

    for p in sorted(log_dir.rglob("*.log"))[-30:]:
        try:
            tail = p.read_text(encoding="utf-8", errors="ignore").splitlines()[-120:]
        except Exception:
            continue
        for line in tail:
            low = line.lower()
            if any(x in low for x in ["error", "failed", "fail", "traceback", "permission denied", "connection refused"]):
                hits.append({"file": str(p.relative_to(ROOT)), "level": "error", "line": line[-300:]})
            elif any(x in low for x in ["warn", "warning", "missing"]):
                hits.append({"file": str(p.relative_to(ROOT)), "level": "warning", "line": line[-300:]})
    return {
        "errors": len([x for x in hits if x["level"] == "error"]),
        "warnings": len([x for x in hits if x["level"] == "warning"]),
        "hits": hits[-50:]
    }

stats_md = read_text("posts/kibra_stats_recommendations_report.md")
sec_md = read_text("posts/cybra_security_analytics_report.md")
conf_md = read_text("posts/cybra_conformation8_report.md")
autoheal_md = read_text("posts/cybra_autoheal_7lvl_report.md")
recovery_md = read_text("posts/cybra_autorecovery_report.md")

payment = load_json("feeds/cybra_payment_requisites_package.json", {})
market = load_json("feeds/kibra_real_market_price_gate.json", {})
security = load_json("feeds/cybra_security_analytics_report.json", {})
conformation = load_json("feeds/cybra_conformation8_report.json", {})

main_blocks = count("blockchain/kibra_chain/blocks/block_*.json")
task_blocks = count("blockchain/kibra_chain/task_blocks/*.json")
estimated_kibra = (main_blocks + task_blocks) * 100

parliament_recs = extract_section(stats_md, "## Parliament recommendations")
security_missing = extract_section(sec_md, "## Missing")
security_warnings = extract_section(sec_md, "## Warnings")
security_critical = extract_section(sec_md, "## Critical")
conformation_issues = extract_section(conf_md, "## Missing / Issues")

logs = scan_logs()

audit_recs = []
if not payment.get("validation", {}).get("ready", False):
    audit_recs.append("Заповнити реальний канал оплати: bank IBAN або PSP provider.")
if not market.get("real_market_confirmed", False):
    audit_recs.append("Не підтверджувати ціну KIBRA без real pool/orderbook/provider/reserve proof.")
if not exists("posts/cybra_autorecovery_report.md"):
    audit_recs.append("Відновити AutoRecovery report.")
if rlen("cybra:parliament:failed") > 0:
    audit_recs.append("Очистити parliament failed через executor + Conformation8 fixer.")
if rlen("cybra:ai:tasks:block_inbox") > 0:
    audit_recs.append("Прогнати AI block inbox через closed SHA bridge.")
if logs["errors"] > 0:
    audit_recs.append("Переглянути logs/test_autofix і виправити error/fail рядки.")
if not audit_recs:
    audit_recs.append("Критичних блокерів не знайдено. Продовжувати цикл AutoHeal/Security/Conformation.")

log_recs = []
if logs["errors"] > 0:
    log_recs.append("Є error/fail у логах: перевірити останні hits у звіті.")
if logs["warnings"] > 0:
    log_recs.append("Є warnings/missing у логах: перевірити, чи це не відсутні опційні модулі.")
if logs["errors"] == 0 and logs["warnings"] == 0:
    log_recs.append("Лог-система не бачить критичних помилок в останніх логах.")

report = {
    "status": "test_autofix_recommendations_generated",
    "time": time.time(),
    "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "state": {
        "main_blocks": main_blocks,
        "task_blocks": task_blocks,
        "estimated_kibra_default_reward_100": estimated_kibra,
        "parliament_queue": rlen("cybra:parliament:queue"),
        "parliament_results": rlen("cybra:parliament:results"),
        "parliament_failed": rlen("cybra:parliament:failed"),
        "ai_block_inbox": rlen("cybra:ai:tasks:block_inbox"),
        "task_block_mempool": rlen("cybra:kibra:task_blocks:mempool"),
        "pool_mining_blocks": rlen("cybra:kibra:pool:mining_blocks"),
        "payment_ready": payment.get("validation", {}).get("ready", False),
        "bank_ready": payment.get("validation", {}).get("bank_ready", False),
        "psp_ready": payment.get("validation", {}).get("psp_ready", False),
        "real_market_confirmed": market.get("real_market_confirmed", False),
        "price_usd_per_kibra": market.get("price_usd_per_kibra", 0),
        "autorecovery_report_exists": exists("posts/cybra_autorecovery_report.md")
    },
    "parliament_recommendations": parliament_recs,
    "audit_recommendations": audit_recs,
    "security_missing": security_missing,
    "security_warnings": security_warnings,
    "security_critical": security_critical,
    "conformation_issues": conformation_issues,
    "log_system": logs,
    "log_recommendations": log_recs,
    "safety": {
        "private_keys_collected": False,
        "seed_phrase_collected": False,
        "automatic_real_payment": False,
        "automatic_SWIFT": False,
        "automatic_external_tx": False,
        "real_sell_now": False,
        "manual_OWNER_approval_required": True
    }
}
report["double_sha"] = dsha(report)

(ROOT / "feeds").mkdir(exist_ok=True)
(ROOT / "posts").mkdir(exist_ok=True)
(ROOT / "proofs").mkdir(exist_ok=True)
(ROOT / "data/cybra_test_autofix").mkdir(parents=True, exist_ok=True)

(ROOT / "feeds/cybra_test_autofix_recommendations_report.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2),
    encoding="utf-8"
)
(ROOT / "data/cybra_test_autofix/latest_report.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2),
    encoding="utf-8"
)

lines = []
lines.append("# CYBRA Test + Autofix + Recommendations Report")
lines.append("")
lines.append("Status: generated")
lines.append("")
lines.append("## Current state")
for k, v in report["state"].items():
    lines.append(f"{k}: {v}")

lines.append("")
lines.append("## Parliament recommendations")
if parliament_recs:
    lines += parliament_recs
else:
    lines.append("No parliament recommendations found in report file.")

lines.append("")
lines.append("## Audit-system recommendations")
for x in audit_recs:
    lines.append(f"- {x}")

lines.append("")
lines.append("## Security Analytics")
lines.append("### Missing")
lines += security_missing if security_missing else ["None"]
lines.append("")
lines.append("### Warnings")
lines += security_warnings if security_warnings else ["None"]
lines.append("")
lines.append("### Critical")
lines += security_critical if security_critical else ["None"]

lines.append("")
lines.append("## Conformation8 issues")
lines += conformation_issues if conformation_issues else ["None"]

lines.append("")
lines.append("## Log-system")
lines.append(f"errors: {logs['errors']}")
lines.append(f"warnings: {logs['warnings']}")
lines.append("")
lines.append("### Log recommendations")
for x in log_recs:
    lines.append(f"- {x}")

if logs["hits"]:
    lines.append("")
    lines.append("### Last log hits")
    for h in logs["hits"][-20:]:
        lines.append(f"- {h['level']} / {h['file']}: {h['line']}")

lines.append("")
lines.append("## Safety")
for k, v in report["safety"].items():
    lines.append(f"{k}: {v}")

lines.append("")
lines.append("## Double SHA")
lines.append(report["double_sha"])

(ROOT / "posts/cybra_test_autofix_recommendations_report.md").write_text(
    "\n".join(lines),
    encoding="utf-8"
)

with (ROOT / "proofs/cybra_test_autofix_recommendations.sha256").open("w") as f:
    subprocess.run([
        "sha256sum",
        "feeds/cybra_test_autofix_recommendations_report.json",
        "posts/cybra_test_autofix_recommendations_report.md",
        "data/cybra_test_autofix/latest_report.json"
    ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

task = {
    "topic": "CYBRA test autofix recommendations",
    "type": "cybra_test_autofix_recommendations_task",
    "priority": "critical" if logs["errors"] > 0 or report["state"]["parliament_failed"] > 0 else "normal",
    "payload": {
        "source": "cybra_test_autofix_recommendations",
        "state": report["state"],
        "audit_recommendations": audit_recs,
        "log_recommendations": log_recs,
        "convert_to_mining_block_first": True,
        "send_to_pool_mining": True,
        "real_payment_now": False,
        "automatic_EXTERNAL_TX": False,
        "manual_OWNER_approval_required": True
    }
}
task["double_sha"] = dsha(task)

run(["redis-cli", "LPUSH", "cybra:ai:tasks:block_inbox", json.dumps(task, ensure_ascii=False)])
run(["redis-cli", "LPUSH", "cybra:test_autofix:audit", json.dumps({
    "status": "test_autofix_recommendations_generated",
    "double_sha": report["double_sha"],
    "time": report["time"]
}, ensure_ascii=False)])

print("✅ recommendations report generated")
print("REPORT: posts/cybra_test_autofix_recommendations_report.md")
print("FEED: feeds/cybra_test_autofix_recommendations_report.json")
print("PROOF: proofs/cybra_test_autofix_recommendations.sha256")
print("DOUBLE_SHA:", report["double_sha"])
PY

echo
echo "=== 8. SEND REPORT TASK TO MINING BLOCKS ==="

[ -f cybra_closed_sha_bridge.sh ] && bash cybra_closed_sha_bridge.sh cycle || true

echo
echo "=== 9. PROOF CHECK ==="

sha256sum -c proofs/cybra_test_autofix_recommendations.sha256 || true

echo
echo "=== 10. FINAL STATUS ==="

echo "OK=$OK"
echo "WARN=$WARN"
echo "FAIL=$FAIL"
echo "LOG=$LOG"

cat posts/cybra_test_autofix_recommendations_report.md

echo
echo "✅ CYBRA TEST + AUTOFIX + RECOMMENDATIONS DONE"
