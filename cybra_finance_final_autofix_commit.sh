#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA"

echo "=== CYBRA FINANCE FINAL AUTOFIX + COMMIT ==="

mkdir -p data/kibra_market/price_proof_templates posts feeds proofs logs/final_fix runtime/redis

echo
echo "=== 1. REDIS CHECK ==="
if [ -f cybra_redis_committee.sh ]; then
  bash cybra_redis_committee.sh ensure || true
fi

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir "$HOME/CYBRA/runtime/redis" --save "" --appendonly no >/dev/null 2>&1 || true
fi

redis-cli ping || true

echo
echo "=== 2. RESTORE MARKET PROOF COLLECTOR IF MISSING ==="

if [ ! -f cybra_market_proof_collector.sh ]; then
cat > cybra_market_proof_collector.py <<'PY'
#!/usr/bin/env python3
import json, time, hashlib, subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"
AUDIT = "cybra:kibra:market_proof_collector:audit"
AI_BLOCK_INBOX = "cybra:ai:tasks:block_inbox"

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(x):
    return sha(sha(x))

def run(cmd):
    try:
        p = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
        return p.returncode, p.stdout.strip(), p.stderr.strip()
    except Exception as e:
        return 1, "", str(e)

def rpush(key, obj):
    run(["redis-cli", "LPUSH", key, json.dumps(obj, ensure_ascii=False)])

def rlen(key):
    code, out, err = run(["redis-cli", "LLEN", key])
    return int(out) if code == 0 and out.isdigit() else 0

def save(path, obj):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

def load(path, default=None):
    p = ROOT / path
    if not p.exists():
        return default if default is not None else {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return default if default is not None else {}

def templates():
    save("data/kibra_market/price_proof_templates/dex_pool_proof.json", {
        "proof_type": "pool",
        "provider_name": "",
        "proof_source": "",
        "pair": "KIBRA/USD",
        "quote_reserve_usd": 0,
        "kibra_reserve": 0,
        "provider_review_passed": False,
        "owner_approval": False,
        "real_sell_now": False
    })
    save("data/kibra_market/price_proof_templates/orderbook_provider_proof.json", {
        "proof_type": "orderbook",
        "provider_name": "",
        "proof_source": "",
        "pair": "KIBRA/USD",
        "bid": 0,
        "ask": 0,
        "depth_usd": 0,
        "provider_review_passed": False,
        "owner_approval": False,
        "real_sell_now": False
    })
    save("data/kibra_market/price_proof_templates/reserve_backed_peg_proof.json", {
        "proof_type": "reserve_backed_peg",
        "provider_name": "",
        "proof_source": "",
        "pair": "KIBRA/USD",
        "reserve_usd": 0,
        "kibra_supply_backed": 0,
        "custody_proof_reference": "",
        "provider_review_passed": False,
        "owner_approval": False,
        "real_sell_now": False
    })

def valid(proof):
    errors = []
    provider = proof.get("provider_name", "")
    source = proof.get("proof_source") or proof.get("proof_reference")

    if not provider:
        errors.append("provider_name порожній")
    if not source:
        errors.append("нема proof_source або proof_reference")
    if not proof.get("provider_review_passed"):
        errors.append("provider_review_passed має бути true")
    if not proof.get("owner_approval"):
        errors.append("owner_approval має бути true")

    ptype = proof.get("proof_type", "")
    price = 0

    try:
        if ptype == "pool":
            q = float(proof.get("quote_reserve_usd", 0))
            k = float(proof.get("kibra_reserve", 0))
            if q > 0 and k > 0:
                price = q / k
            else:
                errors.append("нема коректних резервів pool")
        elif ptype == "orderbook":
            bid = float(proof.get("bid", 0))
            ask = float(proof.get("ask", 0))
            if bid > 0 and ask > 0 and ask >= bid:
                price = (bid + ask) / 2
            else:
                errors.append("нема коректних bid/ask")
        elif ptype == "reserve_backed_peg":
            r = float(proof.get("reserve_usd", 0))
            s = float(proof.get("kibra_supply_backed", 0))
            if r > 0 and s > 0:
                price = r / s
            else:
                errors.append("нема коректних reserve/supply")
        else:
            errors.append("unknown proof_type")
    except Exception as e:
        errors.append(str(e))

    return {
        "valid": len(errors) == 0,
        "errors": errors,
        "price_usd_per_kibra": price
    }

def collect():
    templates()
    proof = load("data/kibra_market/real_market_proof.json", {})
    result = valid(proof) if proof else {
        "valid": False,
        "errors": ["real_market_proof.json missing or empty"],
        "price_usd_per_kibra": 0
    }

    report = {
        "status": "valid_candidate_found" if result["valid"] else "no_valid_market_proof",
        "time": time.time(),
        "proof": proof,
        "validation": result,
        "real_market_confirmed": False,
        "real_sell_now": False,
        "manual_OWNER_approval_required": True
    }
    report["double_sha"] = dsha(json.dumps(report, ensure_ascii=False, sort_keys=True))

    save("feeds/kibra_market_proof_collector_report.json", report)
    save("data/kibra_market/proof_collector/latest_report.json", report)

    md = f"""# KIBRA Market Proof Collector

Status: **{report['status']}**

Valid: **{result['valid']}**
Price USD/KIBRA: **{result['price_usd_per_kibra']}**

Errors:

{json.dumps(result['errors'], ensure_ascii=False, indent=2)}

Rule:

Без real pool/orderbook/provider proof ціна не підтверджується як ринкова.

Double SHA:

{report['double_sha']}
"""
    (ROOT / "posts/kibra_market_proof_collector_report.md").write_text(md, encoding="utf-8")

    with (ROOT / "proofs/kibra_market_proof_collector.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "feeds/kibra_market_proof_collector_report.json",
            "posts/kibra_market_proof_collector_report.md"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    rpush(AUDIT, {
        "status": report["status"],
        "valid": result["valid"],
        "double_sha": report["double_sha"],
        "time": report["time"]
    })

    print("✅ market proof collector report generated")
    print("STATUS:", report["status"])
    print("VALID:", result["valid"])
    print("REPORT: posts/kibra_market_proof_collector_report.md")

def submit_ai():
    collect()
    task = {
        "topic": "KIBRA Market Proof Collector",
        "type": "kibra_market_proof_collector_task",
        "priority": "critical",
        "payload": {
            "source": "kibra_market_proof_collector",
            "goal": "Collect and validate real pool/orderbook/provider proof for KIBRA market price.",
            "convert_to_mining_block_first": True,
            "real_payment_now": False,
            "real_sell_now": False,
            "fake_price": False,
            "manual_OWNER_approval_required": True
        }
    }
    rpush(AI_BLOCK_INBOX, task)
    print("AI_TASK_ADDED_TO_BLOCK_INBOX")

def status():
    report = load("feeds/kibra_market_proof_collector_report.json", {})
    print("MARKET_PROOF_COLLECTOR:", "exists")
    print("REPORT_EXISTS:", bool(report))
    print("STATUS:", report.get("status", "missing"))
    print("AUDIT:", rlen(AUDIT))
    print("BLOCK_INBOX:", rlen(AI_BLOCK_INBOX))

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd in ["collect", "report"]:
        collect()
    elif cmd == "submit-ai":
        submit_ai()
    elif cmd == "status":
        status()
    elif cmd == "files":
        templates()
        print("data/kibra_market/price_proof_templates/")
        print("data/kibra_market/real_market_proof.json")
    else:
        raise SystemExit("Usage: status|collect|report|submit-ai|files")

if __name__ == "__main__":
    main()
PY

cat > cybra_market_proof_collector.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  status)
    python3 cybra_market_proof_collector.py status
    ;;
  collect|report)
    python3 cybra_market_proof_collector.py collect
    cat posts/kibra_market_proof_collector_report.md
    ;;
  submit-ai)
    python3 cybra_market_proof_collector.py submit-ai
    ;;
  files)
    python3 cybra_market_proof_collector.py files
    ;;
  proof)
    cat proofs/kibra_market_proof_collector.sha256
    ;;
  *)
    echo "Usage: bash cybra_market_proof_collector.sh status|collect|submit-ai|files|proof"
    ;;
esac
EOF

chmod +x cybra_market_proof_collector.py cybra_market_proof_collector.sh
fi

python3 -m py_compile cybra_market_proof_collector.py || true
bash cybra_market_proof_collector.sh collect || true
bash cybra_market_proof_collector.sh status || true

echo
echo "=== 3. FINAL REPORTS ==="

cybra-finance-bin report || true
bash kybra_valid.sh report || true
bash cybra_payment_requisites.sh report || true
bash cybra_finance_committees.sh report || true
bash cybra_kibra_stats.sh report || true

if [ -f cybra_closed_sha_bridge.sh ]; then
  bash cybra_closed_sha_bridge.sh cycle || true
fi

echo
echo "=== 4. SECURITY: SANITIZE GIT REMOTE TOKEN ==="

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  remote_url="$(git remote get-url origin 2>/dev/null)"
  echo "$remote_url" | grep -q "ghp_"
  if [ "$?" -eq 0 ]; then
    echo "⚠ GitHub token was found inside remote URL. Replacing remote with safe HTTPS URL."
    git remote set-url origin https://github.com/Lubnysash1980/CYBRA.git
  fi
fi

echo
echo "=== 5. GITIGNORE / REMOVE REDIS DB FROM INDEX ==="

cat > .gitignore <<'EOF'
# runtime
runtime/
logs/
*.log
*.pid
__pycache__/
*/__pycache__/

# local redis/db
dump.rdb
*.rdb

# secrets
.env
*.key
*.pem
id_rsa
id_ed25519
*private*
*secret*
*token*
EOF

git rm --cached dump.rdb >/dev/null 2>&1 || true

echo
echo "=== 6. SAFE STAGE FILES ==="

stage() {
  if [ -e "$1" ]; then
    git add -A -- "$1"
  fi
}

stage .gitignore

for p in \
  auto_fix_finance_redis_committee.sh \
  cybra_finance_full_autotest_fix_commit.sh \
  cybra_finance_final_autofix_commit.sh \
  cybra_payment_autoblock.sh \
  kybra_valid_wallet_autoblock.sh \
  auto_rebuild_cybra_cold_finance_binary.sh \
  auto_create_cybra_finance_5_committees.sh \
  cybra_finance_redis_committee.py \
  cybra_payment_requisites.py \
  kybra_valid_gateway.py \
  cybra_finance_5_committees.py \
  cybra_market_proof_collector.py \
  cybra_market_proof_collector.sh \
  cybra_redis_committee.sh \
  cybra_payment_requisites.sh \
  kybra_valid.sh \
  cybra_finance_committees.sh \
  finance_redis_committee_handler.sh \
  cybra_payment_requisites_handler.sh \
  kybra_valid_wallet_handler.sh \
  cybra_cold_finance_binary_handler.sh \
  cybra_finance_5_committees_handler.sh \
  bin/cybra-finance-bin \
  parliament/departments/finance_department \
  parliament/departments/cybra_finance_department \
  parliament/committees \
  data/cybra_payment_requisites \
  data/finance_redis_committee \
  data/kybra_valid \
  data/cybra_cold_finance \
  data/kibra_market \
  data/ai_block_enforcer \
  data/ai_task_blocks \
  data/kibra_bridge \
  data/kibra_closed_sha_pool_bridge \
  blockchain/kibra_chain \
  posts \
  feeds \
  proofs \
  parliament_executor_v6.py
do
  stage "$p"
done

echo
echo "=== 7. GIT STATUS AFTER STAGE ==="
git status --short

echo
echo "=== 8. COMMIT ==="

if git diff --cached --quiet; then
  echo "⚠ No staged changes after safe stage."
else
  git commit -m "finalize CYBRA cold finance system, committees and market proof collector"
fi

echo
echo "=== 9. PUSH ==="

branch="$(git branch --show-current 2>/dev/null)"
[ -z "$branch" ] && branch="main"

git push origin "$branch"
push_code=$?

if [ "$push_code" -ne 0 ]; then
  echo
  echo "⚠ PUSH FAILED."
  echo "Commit is local. Причина може бути auth після видалення токена з remote."
  echo "Варіанти:"
  echo "1) SSH: git remote set-url origin git@github.com:Lubnysash1980/CYBRA.git"
  echo "2) HTTPS без токена: git remote set-url origin https://github.com/Lubnysash1980/CYBRA.git"
fi

echo
echo "=== 10. FINAL CHECK ==="
bash cybra_market_proof_collector.sh status || true
cybra-finance-bin status || true
bash cybra_kibra_stats.sh status || true

echo
echo "✅ FINAL AUTOFIX DONE"
