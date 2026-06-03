#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

echo "=== CREATE CYBRA SECURITY ANALYTICS MODULE ==="

mkdir -p \
  bin \
  parliament/departments/finance_department/cybra_security_analytics_department \
  parliament/departments/cybra_finance_department/cybra_security_analytics_department \
  data/cybra_security_analytics/{scans,alerts,reports,tasks} \
  posts feeds proofs logs/cybra_security_analytics runtime/redis runtime

if [ -f cybra_redis_committee.sh ]; then
  bash cybra_redis_committee.sh ensure >/dev/null 2>&1 || true
fi

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir "$HOME/CYBRA/runtime/redis" --save "" --appendonly no >/dev/null 2>&1 || true
fi

sleep 1

cat > parliament/departments/finance_department/cybra_security_analytics_department/department.json <<'JSON'
{
  "department_id": "cybra_security_analytics_department",
  "name": "CYBRA Security Analytics Department",
  "parent_department": "finance_department",
  "status": "active",
  "mission": "Сканувати фінансову систему CYBRA/KYBRA, парламент, AutoHeal, платіжні реквізити, market proof, Git/security risks і створювати AI-завдання на виправлення.",
  "checks": [
    "redis_health",
    "parliament_queue_failed_results",
    "autoheal_7lvl_health",
    "cold_finance_binary_health",
    "payment_requisites_readiness",
    "kybra_valid_wallet_health",
    "market_price_proof_readiness",
    "real_payment_safety_flags",
    "github_remote_token_exposure",
    "private_key_seed_file_scan",
    "proof_integrity",
    "task_block_mining_flow"
  ],
  "blocked": [
    "private_key_collection",
    "seed_phrase_collection",
    "automatic_real_payment",
    "automatic_SWIFT",
    "automatic_external_crypto_tx",
    "fake_price",
    "fake_volume"
  ],
  "rule": "Модуль тільки аналізує, ремонтує локальні конфігурації, створює звіти й AI-завдання. Реальні платежі, SWIFT і зовнішні tx не запускає.",
  "manual_OWNER_approval_required": true
}
JSON

cp parliament/departments/finance_department/cybra_security_analytics_department/department.json \
   parliament/departments/cybra_finance_department/cybra_security_analytics_department/department.json 2>/dev/null || true

cat > bin/cybra-security-analytics <<'PY'
#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
import sys
from pathlib import Path

ROOT = Path.home() / "CYBRA"

AUDIT = "cybra:security_analytics:audit"
ALERTS = "cybra:security_analytics:alerts"
AI_BLOCK_INBOX = "cybra:ai:tasks:block_inbox"

def sha(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def dsha(text):
    return sha(sha(text))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def run(cmd, timeout=30):
    try:
        p = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True, timeout=timeout)
        return p.returncode, p.stdout.strip(), p.stderr.strip()
    except Exception as e:
        return 1, "", str(e)

def redis_len(key):
    code, out, err = run(["redis-cli", "LLEN", key])
    if code == 0 and out.strip().isdigit():
        return int(out.strip())
    return 0

def redis_lpush(key, obj):
    run(["redis-cli", "LPUSH", key, json.dumps(obj, ensure_ascii=False)])

def redis_hset(key, field, value):
    run(["redis-cli", "HSET", key, field, value])

def exists(path):
    return (ROOT / path).exists()

def load_json(path, default=None):
    p = ROOT / path
    if not p.exists():
        return default if default is not None else {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return default if default is not None else {}

def save_json(path, obj):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

def count(pattern):
    return len(list(ROOT.glob(pattern)))

def file_sha(path):
    p = ROOT / path
    if not p.exists() or not p.is_file():
        return None
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(1024 * 1024), b""):
            h.update(c)
    return h.hexdigest()

def redis_ping():
    code, out, err = run(["redis-cli", "ping"])
    return code == 0 and out == "PONG"

def git_remote_safe():
    code, out, err = run(["git", "remote", "get-url", "origin"])
    if code != 0:
        return {
            "git_repo": False,
            "remote_exists": False,
            "token_exposed": False,
            "remote_sanitized": ""
        }

    token_exposed = ("ghp_" in out) or ("github_pat_" in out) or ("@" in out and "https://" in out)

    sanitized = out
    if "ghp_" in sanitized or "github_pat_" in sanitized:
        sanitized = "TOKEN_HIDDEN_REMOTE_URL"

    return {
        "git_repo": True,
        "remote_exists": True,
        "token_exposed": token_exposed,
        "remote_sanitized": sanitized
    }

def scan_sensitive_files():
    risky_names = [
        ".env",
        "id_rsa",
        "id_ed25519",
        "private.key",
        "secret.key",
        "seed.txt",
        "token.txt"
    ]

    found = []
    for name in risky_names:
        for p in ROOT.rglob(name):
            rel = str(p.relative_to(ROOT))
            if ".git/" not in rel and "node_modules/" not in rel:
                found.append(rel)

    return found[:50]

def payment_requisites_state():
    profile = load_json("data/cybra_payment_requisites/payer_profile.json", {})
    if not profile:
        return {
            "exists": False,
            "ready": False,
            "missing": ["payer_profile.json missing"]
        }

    missing = []
    if not (profile.get("payer_full_legal_name") or profile.get("payer_display_name")):
        missing.append("payer legal/display name")
    if not profile.get("payer_tax_id_or_edrpou"):
        missing.append("tax_id_or_edrpou")

    bank = profile.get("bank", {})
    psp = profile.get("psp", {})

    bank_ready = bool(bank.get("bank_name") and bank.get("iban"))
    psp_ready = bool(psp.get("provider_name") and (psp.get("merchant_id") or psp.get("account_id")))

    if not bank_ready and not psp_ready:
        missing.append("real bank IBAN or PSP provider")

    return {
        "exists": True,
        "ready": len(missing) == 0,
        "bank_ready": bank_ready,
        "psp_ready": psp_ready,
        "missing": missing
    }

def market_state():
    gate = load_json("feeds/kibra_real_market_price_gate.json", {})
    collector = load_json("feeds/kibra_market_proof_collector_report.json", {})

    return {
        "gate_exists": bool(gate),
        "collector_exists": bool(collector),
        "real_market_confirmed": bool(gate.get("real_market_confirmed", False)),
        "price_usd_per_kibra": gate.get("price_usd_per_kibra", 0),
        "collector_status": collector.get("status", "missing"),
        "collector_valid": collector.get("validation", {}).get("valid", False),
        "missing": [] if gate.get("real_market_confirmed") else [
            "real pool/orderbook/provider proof",
            "provider_name",
            "proof_source/proof_reference",
            "provider_review_passed=true",
            "owner_approval=true"
        ]
    }

def parliament_state():
    return {
        "queue": redis_len("cybra:parliament:queue"),
        "results": redis_len("cybra:parliament:results"),
        "failed": redis_len("cybra:parliament:failed"),
        "ai_block_inbox": redis_len("cybra:ai:tasks:block_inbox"),
        "task_block_mempool": redis_len("cybra:kibra:task_blocks:mempool"),
        "pool_mining_blocks": redis_len("cybra:kibra:pool:mining_blocks"),
        "task_blocks_mined": redis_len("cybra:kibra:task_blocks:mined")
    }

def module_state():
    return {
        "redis_committee": exists("cybra_redis_committee.sh"),
        "autoheal_7lvl": exists("cybra_autoheal.sh"),
        "cold_finance_binary": exists("bin/cybra-finance-bin"),
        "finance_committees": exists("cybra_finance_committees.sh"),
        "kybra_valid": exists("kybra_valid.sh"),
        "payment_requisites": exists("cybra_payment_requisites.sh"),
        "market_proof_collector": exists("cybra_market_proof_collector.sh"),
        "real_market_price_gate": exists("cybra_real_market_price_gate.sh"),
        "kibra_stats": exists("cybra_kibra_stats.sh"),
        "closed_sha_bridge": exists("cybra_closed_sha_bridge.sh")
    }

def autoheal_state():
    h = load_json("data/cybra_autoheal_7lvl/reports/health.json", {})
    return {
        "exists": exists("cybra_autoheal.sh"),
        "health_ok": h.get("ok", None),
        "levels": h.get("levels", [])
    }

def balance_state():
    cold = load_json("feeds/cybra_cold_finance_binary_report.json", {})
    valid = load_json("feeds/kybra_valid_wallet_gateway_report.json", {})

    balance = cold.get("balance") or valid.get("balance") or {}

    main_blocks = count("blockchain/kibra_chain/blocks/block_*.json")
    task_blocks = count("blockchain/kibra_chain/task_blocks/*.json")

    return {
        "main_blocks": main_blocks,
        "task_blocks": task_blocks,
        "estimated_kibra_default_reward_100": (main_blocks + task_blocks) * 100,
        "reported_total_mined_kibra": balance.get("total_mined_kibra"),
        "reported_available_kibra": balance.get("available_kibra")
    }

def scan():
    modules = module_state()
    parliament = parliament_state()
    payment = payment_requisites_state()
    market = market_state()
    git = git_remote_safe()
    sensitive = scan_sensitive_files()
    autoheal = autoheal_state()
    balance = balance_state()

    missing = []
    warnings = []
    critical = []

    for k, v in modules.items():
        if not v:
            missing.append("module missing: " + k)

    if parliament["failed"] > 0:
        critical.append("parliament_failed > 0")

    if not payment["ready"]:
        missing += ["payment requisites: " + x for x in payment["missing"]]

    if not market["real_market_confirmed"]:
        missing += ["market proof: " + x for x in market["missing"]]

    if git["token_exposed"]:
        critical.append("Git remote may expose token. Sanitize remote and revoke token.")

    if sensitive:
        warnings.append("Sensitive-looking files exist: " + ", ".join(sensitive[:10]))

    if autoheal["health_ok"] is False:
        critical.append("AutoHeal health not OK")

    risk_score = 0
    risk_score += len(missing) * 3
    risk_score += len(warnings) * 5
    risk_score += len(critical) * 10
    if risk_score > 100:
        risk_score = 100

    risk_level = "LOW"
    if risk_score >= 60:
        risk_level = "HIGH"
    elif risk_score >= 25:
        risk_level = "MEDIUM"

    report = {
        "status": "security_scan_completed",
        "time": time.time(),
        "time_iso": now_iso(),
        "risk_score": risk_score,
        "risk_level": risk_level,
        "modules": modules,
        "parliament": parliament,
        "payment_requisites": payment,
        "market": market,
        "git": git,
        "sensitive_file_scan": {
            "found_count": len(sensitive),
            "found": sensitive
        },
        "autoheal": autoheal,
        "balance": balance,
        "missing": missing,
        "warnings": warnings,
        "critical": critical,
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

    report["double_sha"] = dsha(json.dumps(report, ensure_ascii=False, sort_keys=True))

    save_json("feeds/cybra_security_analytics_report.json", report)
    save_json("data/cybra_security_analytics/reports/latest_report.json", report)
    save_json("data/cybra_security_analytics/scans/latest_scan.json", report)

    redis_lpush(AUDIT, {
        "status": "security_scan_completed",
        "risk_score": risk_score,
        "risk_level": risk_level,
        "missing_count": len(missing),
        "critical_count": len(critical),
        "double_sha": report["double_sha"],
        "time": report["time"]
    })

    for c in critical:
        redis_lpush(ALERTS, {
            "type": "critical",
            "message": c,
            "time": report["time"],
            "time_iso": report["time_iso"]
        })

    return report

def write_report(report):
    lines = []
    lines.append("# CYBRA Security Analytics Report")
    lines.append("")
    lines.append("Status: " + report["status"])
    lines.append("Risk level: " + report["risk_level"])
    lines.append("Risk score: " + str(report["risk_score"]))
    lines.append("")
    lines.append("## Parliament")
    for k, v in report["parliament"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Balance")
    for k, v in report["balance"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Missing")
    if report["missing"]:
        for x in report["missing"]:
            lines.append("- " + x)
    else:
        lines.append("None")
    lines.append("")
    lines.append("## Warnings")
    if report["warnings"]:
        for x in report["warnings"]:
            lines.append("- " + x)
    else:
        lines.append("None")
    lines.append("")
    lines.append("## Critical")
    if report["critical"]:
        for x in report["critical"]:
            lines.append("- " + x)
    else:
        lines.append("None")
    lines.append("")
    lines.append("## Market")
    for k, v in report["market"].items():
        if k != "missing":
            lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Payment requisites")
    for k, v in report["payment_requisites"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Safety")
    for k, v in report["safety"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Double SHA")
    lines.append(report["double_sha"])

    (ROOT / "posts/cybra_security_analytics_report.md").write_text("\n".join(lines), encoding="utf-8")

    with (ROOT / "proofs/cybra_security_analytics.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "feeds/cybra_security_analytics_report.json",
            "posts/cybra_security_analytics_report.md",
            "data/cybra_security_analytics/scans/latest_scan.json"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

def submit_ai(report):
    task = {
        "topic": "CYBRA Security Analytics missing items and risk repair",
        "type": "cybra_security_analytics_task",
        "priority": "critical" if report["critical"] else "normal",
        "payload": {
            "source": "cybra_security_analytics",
            "risk_score": report["risk_score"],
            "risk_level": report["risk_level"],
            "missing": report["missing"],
            "warnings": report["warnings"],
            "critical": report["critical"],
            "parliament": report["parliament"],
            "convert_to_mining_block_first": True,
            "send_to_pool_mining": True,
            "real_payment_now": False,
            "automatic_SWIFT": False,
            "automatic_external_tx": False,
            "manual_OWNER_approval_required": True
        }
    }
    task["double_sha"] = dsha(json.dumps(task, ensure_ascii=False, sort_keys=True))
    save_json("data/cybra_security_analytics/tasks/latest_ai_task.json", task)
    redis_lpush(AI_BLOCK_INBOX, task)

def fix_local():
    # Local-only safe fixes: Redis, chmod, gitignore, remote sanitize.
    if not redis_ping():
        run(["redis-server", "--daemonize", "yes", "--bind", "127.0.0.1", "--port", "6379", "--dir", str(ROOT / "runtime/redis"), "--save", "", "--appendonly", "no"])

    for f in [
        "bin/cybra-security-analytics",
        "bin/cybra-autoheal",
        "bin/cybra-finance-bin",
        "cybra_security_analytics.sh",
        "cybra_autoheal.sh",
        "cybra_finance_committees.sh",
        "kybra_valid.sh",
        "cybra_payment_requisites.sh"
    ]:
        p = ROOT / f
        if p.exists():
            try:
                p.chmod(p.stat().st_mode | 0o111)
            except Exception:
                pass

    remote = git_remote_safe()
    if remote.get("token_exposed"):
        run(["git", "remote", "set-url", "origin", "https://github.com/Lubnysash1980/CYBRA.git"])

    ignore = ROOT / ".gitignore"
    extra = [
        "runtime/",
        "logs/",
        "*.log",
        "*.pid",
        "dump.rdb",
        "*.rdb",
        ".env",
        "*.key",
        "*.pem",
        "id_rsa",
        "id_ed25519",
        "*private*",
        "*secret*",
        "*token*"
    ]
    old = ignore.read_text(encoding="utf-8") if ignore.exists() else ""
    for x in extra:
        if x not in old:
            old += "\n" + x
    ignore.write_text(old.strip() + "\n", encoding="utf-8")

def cycle():
    fix_local()
    report = scan()
    write_report(report)
    submit_ai(report)

    if exists("cybra_closed_sha_bridge.sh"):
        subprocess.run(["bash", "cybra_closed_sha_bridge.sh", "cycle"], cwd=ROOT)

    print("✅ security analytics cycle complete")
    print("RISK_LEVEL:", report["risk_level"])
    print("RISK_SCORE:", report["risk_score"])
    print("MISSING:", len(report["missing"]))
    print("CRITICAL:", len(report["critical"]))

def status():
    report = load_json("feeds/cybra_security_analytics_report.json", {})
    if not report:
        report = scan()
        write_report(report)

    print("SECURITY_ANALYTICS:", "active")
    print("RISK_LEVEL:", report.get("risk_level"))
    print("RISK_SCORE:", report.get("risk_score"))
    print("MISSING:", len(report.get("missing", [])))
    print("CRITICAL:", len(report.get("critical", [])))
    print("PARLIAMENT_QUEUE:", report.get("parliament", {}).get("queue"))
    print("PARLIAMENT_FAILED:", report.get("parliament", {}).get("failed"))
    print("TOTAL_KIBRA_EST:", report.get("balance", {}).get("estimated_kibra_default_reward_100"))
    print("REAL_MARKET_CONFIRMED:", report.get("market", {}).get("real_market_confirmed"))
    print("PAYMENT_READY:", report.get("payment_requisites", {}).get("ready"))
    print("AUDIT:", redis_len(AUDIT))
    print("ALERTS:", redis_len(ALERTS))

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "scan":
        report = scan()
        write_report(report)
        print(json.dumps(report, ensure_ascii=False, indent=2))
    elif cmd == "report":
        report = scan()
        write_report(report)
        print("✅ report generated")
        print("REPORT: posts/cybra_security_analytics_report.md")
        print("PROOF: proofs/cybra_security_analytics.sha256")
    elif cmd == "submit-ai":
        report = scan()
        write_report(report)
        submit_ai(report)
        print("✅ AI task submitted")
    elif cmd == "fix-local":
        fix_local()
        print("✅ local security fixes applied")
    elif cmd == "cycle":
        cycle()
    elif cmd == "status":
        status()
    else:
        raise SystemExit("Usage: status|scan|report|submit-ai|fix-local|cycle")

if __name__ == "__main__":
    main()
PY

chmod +x bin/cybra-security-analytics
ln -sf "$HOME/CYBRA/bin/cybra-security-analytics" "$PREFIX/bin/cybra-security-analytics" 2>/dev/null || true

cat > cybra_security_analytics.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  status|scan|report|submit-ai|fix-local|cycle)
    bin/cybra-security-analytics "$@"
    ;;
  start-watch)
    mkdir -p logs/cybra_security_analytics runtime
    nohup bash cybra_security_analytics.sh watch "${2:-60}" > logs/cybra_security_analytics/watch.log 2>&1 &
    echo $! > runtime/cybra_security_analytics.pid
    echo "✅ CYBRA Security Analytics watcher started"
    echo "PID: $(cat runtime/cybra_security_analytics.pid)"
    ;;
  watch)
    termux-wake-lock 2>/dev/null || true
    while true; do
      date
      bin/cybra-security-analytics cycle || true
      sleep "${2:-60}"
    done
    ;;
  stop-watch)
    if [ -f runtime/cybra_security_analytics.pid ]; then
      kill "$(cat runtime/cybra_security_analytics.pid)" 2>/dev/null || true
      rm -f runtime/cybra_security_analytics.pid
    fi
    termux-wake-unlock 2>/dev/null || true
    echo "✅ CYBRA Security Analytics watcher stopped"
    ;;
  log)
    tail -f logs/cybra_security_analytics/watch.log
    ;;
  proof)
    cat proofs/cybra_security_analytics.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_security_analytics.sh status"
    echo "  bash cybra_security_analytics.sh scan"
    echo "  bash cybra_security_analytics.sh report"
    echo "  bash cybra_security_analytics.sh submit-ai"
    echo "  bash cybra_security_analytics.sh fix-local"
    echo "  bash cybra_security_analytics.sh cycle"
    echo "  bash cybra_security_analytics.sh start-watch 60"
    ;;
esac
EOF

chmod +x cybra_security_analytics.sh

cat > cybra_security_analytics_handler.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

bin/cybra-security-analytics cycle >/dev/null 2>&1 || true
EOF

chmod +x cybra_security_analytics_handler.sh

redis-cli HSET cybra:executor:mapping cybra_security_analytics_task cybra_security_analytics_handler.sh >/dev/null || true

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
if p.exists():
    s = p.read_text(encoding="utf-8")

    if 'r.hget("cybra:executor:mapping", task_type)' not in s:
        old = "script_name = SCRIPT_MAP.get(task_type)"
        new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
        if old in s:
            s = s.replace(old, new, 1)

    if '"cybra_security_analytics_task"' not in s:
        i = s.find("SCRIPT_MAP")
        j = s.find("{", i)
        if i >= 0 and j >= 0:
            s = s[:j+1] + '\n    "cybra_security_analytics_task": "cybra_security_analytics_handler.sh",' + s[j+1:]

    p.write_text(s, encoding="utf-8")
    print("✅ parliament executor patched")
else:
    print("⚠ parliament_executor_v6.py not found")
PY

rm -rf __pycache__ bin/__pycache__
python3 -m py_compile bin/cybra-security-analytics
test -f parliament_executor_v6.py && python3 -m py_compile parliament_executor_v6.py || true
rm -rf __pycache__ bin/__pycache__

echo
echo "=== FIRST SECURITY CYCLE ==="
bash cybra_security_analytics.sh cycle
bash cybra_security_analytics.sh status

echo
echo "=== PROOF CHECK ==="
sha256sum -c proofs/cybra_security_analytics.sha256 || true

echo
echo "✅ CYBRA SECURITY ANALYTICS INSTALLED"
