#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

echo "=== CYBRA FINANCE DEPARTMENT INSTALL ==="

mkdir -p \
  parliament/departments/finance_department \
  parliament/finance \
  posts feeds proofs logs/finance data/finance

touch .gitignore
for item in \
  "private_vault/" \
  "dump.rdb" \
  "__pycache__/" \
  "runtime/" \
  "ai_network/" \
  "recovery/" \
  "token/runtime/rpc.env" \
  "data/finance/private/" \
  "*.key" \
  "*.pem" \
  "*secret*" \
  "*card*" \
  "*bank*"
do
  grep -qxF "$item" .gitignore || echo "$item" >> .gitignore
done

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

python3 - <<'PY' >/dev/null 2>&1 || python3 -m pip install redis
import redis
PY

cat > parliament/departments/finance_department/department.json <<'JSON'
{
  "department_id": "finance_department",
  "name": "CYBRA Finance Department",
  "status": "active",
  "mission": "Контролювати бюджет, фінансові ризики, поетапні платежі, фінансовий аудит і оплатні рішення Кіберапарламенту без автоматичного виконання платежів.",
  "powers": [
    "budget_review",
    "risk_scoring",
    "payment_stage_planning",
    "invoice_checklist",
    "financial_audit",
    "cost_optimization",
    "proof_generation",
    "owner_approval_required"
  ],
  "limits": [
    "no_automatic_payment_execution",
    "no_card_data_in_git",
    "no_bank_credentials_in_git",
    "no_private_keys",
    "no_secret_dump",
    "no_uncontrolled_spending",
    "no_illegal_finance",
    "owner_final_approval_required"
  ]
}
JSON

cat > parliament/finance/finance_policy.json <<'JSON'
{
  "name": "CYBRA Finance Policy",
  "status": "active",
  "rules": {
    "payment_execution_allowed": false,
    "owner_manual_approval_required": true,
    "staged_payments_only": true,
    "advance_payment_risk_check_required": true,
    "contract_or_invoice_required": true,
    "proof_required": true,
    "audit_required": true,
    "no_private_payment_data_in_git": true,
    "no_bank_or_card_secrets": true
  },
  "payment_stages": [
    "proposal",
    "legal_review",
    "budget_review",
    "risk_review",
    "owner_approval",
    "manual_external_payment_only",
    "confirmation",
    "audit_close"
  ],
  "blocked": [
    "automatic transfer",
    "card storage",
    "bank login storage",
    "seed phrase storage",
    "private key storage",
    "unverified supplier payment",
    "full prepayment without protection"
  ]
}
JSON

cat > cybra_finance_department.py <<'PY'
#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from pathlib import Path
from collections import Counter

import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

RESULT_KEYS = [
    "cybra:parliament:results",
    "cybra:parliament:failed",
    "cybra:review:approved",
    "cybra:review:hold",
    "cybra:review:rejected",
    "cybra:evolution:approved",
    "cybra:evolution:hold",
    "cybra:evolution:rejected"
]

FIN_AUDIT = "cybra:finance:audit"
FIN_LEDGER = "cybra:finance:ledger"

def sha(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def dsha(text: str) -> str:
    return sha(sha(text))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def git_cmd(cmd):
    try:
        return subprocess.check_output(cmd, cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def load_json(raw, source):
    try:
        obj = json.loads(raw)
        if isinstance(obj, dict):
            obj["_source_key"] = source
            return obj
    except Exception:
        pass
    return {"status": "raw_unparsed", "raw": raw, "_source_key": source}

def scan_items():
    items = []
    for key in RESULT_KEYS:
        for raw in r.lrange(key, 0, 499):
            items.append(load_json(raw, key))
    return items

def finance_keywords_score(item):
    raw = json.dumps(item, ensure_ascii=False).lower()

    finance_words = [
        "payment", "оплата", "оплатити", "платіж", "budget", "бюджет",
        "invoice", "рахунок", "кошти", "вартість", "ціна", "cost",
        "фінанс", "finance", "supplier", "постачальник", "contract", "договір"
    ]

    risk_words = [
        "автоматично оплатити", "full prepayment", "повна передоплата",
        "без підтвердження", "card", "bank login", "seed phrase",
        "private key", "секрет", "пароль", "інн в git"
    ]

    score = 0
    finance_hits = []
    risk_hits = []

    for w in finance_words:
        if w in raw:
            score += 1
            finance_hits.append(w)

    for w in risk_words:
        if w in raw:
            score -= 5
            risk_hits.append(w)

    return score, finance_hits, risk_hits

def create_budget_template():
    path = ROOT / "data/finance/budget_ledger_template.json"
    if not path.exists():
        template = {
            "ledger": "CYBRA Finance Ledger Template",
            "status": "template",
            "entries": [],
            "rules": {
                "manual_payment_only": True,
                "owner_approval_required": True,
                "proof_required": True,
                "no_secrets": True
            }
        }
        path.write_text(json.dumps(template, ensure_ascii=False, indent=2))
    return path

def report():
    r.ping()

    (ROOT / "posts").mkdir(exist_ok=True)
    (ROOT / "feeds").mkdir(exist_ok=True)
    (ROOT / "proofs").mkdir(exist_ok=True)
    (ROOT / "logs/finance").mkdir(parents=True, exist_ok=True)
    (ROOT / "data/finance").mkdir(parents=True, exist_ok=True)

    items = scan_items()

    statuses = Counter(str(x.get("status", "unknown")) for x in items)
    types = Counter(str(x.get("type", "unknown")) for x in items)
    sources = Counter(str(x.get("_source_key", "unknown")) for x in items)

    finance_related = []
    risk_items = []

    for item in items:
        score, finance_hits, risk_hits = finance_keywords_score(item)

        if finance_hits or risk_hits:
            row = {
                "topic": item.get("topic"),
                "type": item.get("type"),
                "status": item.get("status"),
                "source": item.get("_source_key"),
                "score": score,
                "finance_hits": finance_hits,
                "risk_hits": risk_hits,
                "recommendation": None
            }

            if risk_hits:
                row["recommendation"] = "HOLD: фінансовий ризик. Потрібна ручна перевірка OWNER + документи."
                risk_items.append(row)
            else:
                row["recommendation"] = "OK_FOR_REVIEW: можна аналізувати бюджет, але без автоматичної оплати."

            finance_related.append(row)

    budget_template = create_budget_template()

    report_obj = {
        "department": "CYBRA Finance Department",
        "status": "generated",
        "time": time.time(),
        "time_iso": now_iso(),
        "git": {
            "branch": git_cmd(["git", "branch", "--show-current"]),
            "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"]),
            "dirty_files": len(git_cmd(["git", "status", "--short"]).splitlines())
        },
        "summary": {
            "records_checked": len(items),
            "finance_related_records": len(finance_related),
            "risk_items": len(risk_items),
            "finance_audit_records": r.llen(FIN_AUDIT),
            "finance_ledger_records": r.llen(FIN_LEDGER),
            "payment_execution_allowed": False,
            "owner_manual_approval_required": True
        },
        "statuses": dict(statuses),
        "types": dict(types),
        "sources": dict(sources),
        "finance_related": finance_related[:50],
        "risk_items": risk_items[:50],
        "budget_template": str(budget_template.relative_to(ROOT)),
        "policy": "parliament/finance/finance_policy.json"
    }

    report_obj["double_sha"] = dsha(json.dumps(report_obj, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/finance_department_report.json").write_text(
        json.dumps(report_obj, ensure_ascii=False, indent=2)
    )

    def lines(data):
        if not data:
            return "- none"
        return "\n".join(f"- `{k}`: {v}" for k, v in sorted(data.items(), key=lambda x: x[1], reverse=True))

    finance_lines = ""
    for x in finance_related[:30]:
        finance_lines += (
            f"- `{x.get('status')}` / `{x.get('type')}` — {x.get('topic')} "
            f"score={x.get('score')} recommendation: {x.get('recommendation')}\n"
        )
    if not finance_lines:
        finance_lines = "- none\n"

    risk_lines = ""
    for x in risk_items[:30]:
        risk_lines += (
            f"- `{x.get('type')}` — {x.get('topic')} "
            f"risk_hits={x.get('risk_hits')} recommendation: {x.get('recommendation')}\n"
        )
    if not risk_lines:
        risk_lines = "- none\n"

    md = f"""# CYBRA Finance Department

Status: active  
Report status: generated  
Double SHA: `{report_obj["double_sha"]}`

## Rules

- Payment execution allowed: **false**
- OWNER manual approval required: **true**
- Staged payments only: **true**
- No card/bank/private data in GitHub: **true**
- Contract/invoice/proof required: **true**

## Summary

- Records checked: {report_obj["summary"]["records_checked"]}
- Finance-related records: {report_obj["summary"]["finance_related_records"]}
- Risk items: {report_obj["summary"]["risk_items"]}
- Finance audit records: {report_obj["summary"]["finance_audit_records"]}
- Finance ledger records: {report_obj["summary"]["finance_ledger_records"]}

## Statuses

{lines(report_obj["statuses"])}

## Task types

{lines(report_obj["types"])}

## Finance-related items

{finance_lines}

## Risk items

{risk_lines}

## Files

- `parliament/departments/finance_department/department.json`
- `parliament/finance/finance_policy.json`
- `data/finance/budget_ledger_template.json`
- `feeds/finance_department_report.json`
- `posts/finance_department_report.md`
- `proofs/finance_department.sha256`
"""

    (ROOT / "posts/finance_department_report.md").write_text(md)

    with (ROOT / "proofs/finance_department.sha256").open("w") as f:
        subprocess.run(
            [
                "sha256sum",
                "parliament/departments/finance_department/department.json",
                "parliament/finance/finance_policy.json",
                "data/finance/budget_ledger_template.json",
                "feeds/finance_department_report.json",
                "posts/finance_department_report.md"
            ],
            cwd=ROOT,
            stdout=f,
            stderr=subprocess.DEVNULL
        )

    r.lpush(FIN_AUDIT, json.dumps({
        "status": "finance_report_generated",
        "time": report_obj["time"],
        "double_sha": report_obj["double_sha"],
        "risk_items": len(risk_items),
        "finance_related": len(finance_related)
    }, ensure_ascii=False))

    print("✅ CYBRA Finance Department report generated")
    print("Report: posts/finance_department_report.md")
    print("Feed: feeds/finance_department_report.json")
    print("Proof: proofs/finance_department.sha256")

def add_ledger_entry(raw):
    obj = json.loads(raw)
    obj["status"] = "proposal_only"
    obj["payment_execution_allowed"] = False
    obj["owner_manual_approval_required"] = True
    obj["time"] = time.time()
    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))

    r.lpush(FIN_LEDGER, json.dumps(obj, ensure_ascii=False))

    (ROOT / "logs/finance").mkdir(parents=True, exist_ok=True)
    (ROOT / "logs/finance/latest_ledger_entry.json").write_text(
        json.dumps(obj, ensure_ascii=False, indent=2)
    )

    print("✅ finance ledger proposal added")
    print("Double SHA:", obj["double_sha"])

def main():
    import sys

    cmd = sys.argv[1] if len(sys.argv) > 1 else "report"

    if cmd == "report":
        report()
    elif cmd == "ledger-add":
        if len(sys.argv) < 3:
            raise SystemExit("Usage: ledger-add '<json>'")
        add_ledger_entry(sys.argv[2])
    else:
        raise SystemExit("Usage: report | ledger-add '<json>'")

if __name__ == "__main__":
    main()
PY

chmod +x cybra_finance_department.py

cat > finance_department_handler.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"
python3 cybra_finance_department.py report
EOF2

chmod +x finance_department_handler.sh

cat > cybra_finance.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

CMD="${1:-status}"
shift || true

case "$CMD" in
  report)
    python3 cybra_finance_department.py report
    cat posts/finance_department_report.md
    ;;
  task)
    cybra parliament '{"topic":"CYBRA Finance Department","type":"finance_department_task","priority":"high","payload":{"mode":"budget_risk_audit_no_payment_execution"}}'
    ;;
  ledger-add)
    python3 cybra_finance_department.py ledger-add "$1"
    ;;
  ledger)
    redis-cli LRANGE cybra:finance:ledger 0 20
    ;;
  audit)
    redis-cli LRANGE cybra:finance:audit 0 20
    ;;
  status)
    redis-cli ping
    echo "FINANCE_AUDIT: $(redis-cli LLEN cybra:finance:audit)"
    echo "FINANCE_LEDGER: $(redis-cli LLEN cybra:finance:ledger)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    echo "MAPPING: $(redis-cli HGET cybra:executor:mapping finance_department_task)"
    test -f posts/finance_department_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  feed)
    cat feeds/finance_department_report.json
    ;;
  proof)
    cat proofs/finance_department.sha256
    ;;
  policy)
    cat parliament/finance/finance_policy.json
    ;;
  *)
    echo "Usage: bash cybra_finance.sh report|task|ledger-add|ledger|audit|status|feed|proof|policy"
    ;;
esac
EOF2

chmod +x cybra_finance.sh

redis-cli HSET cybra:executor:mapping finance_department_task finance_department_handler.sh >/dev/null

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
s = p.read_text()

if 'r.hget("cybra:executor:mapping", task_type)' not in s:
    old = "script_name = SCRIPT_MAP.get(task_type)"
    new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
    if old in s:
        s = s.replace(old, new, 1)

if '"finance_department_task"' not in s:
    i = s.find("SCRIPT_MAP")
    j = s.find("{", i)
    if i >= 0 and j >= 0:
        s = s[:j+1] + '\n    "finance_department_task": "finance_department_handler.sh",' + s[j+1:]

p.write_text(s)
print("✅ finance_department_task mapping ready")
PY

rm -rf __pycache__
python3 -m py_compile parliament_executor_v6.py
rm -rf __pycache__

echo
echo "=== RUN FINANCE REPORT ==="
bash cybra_finance.sh report

echo
echo "=== TEST FINANCE TASK ==="
bash cybra_finance.sh task
cybra worker-start || true
sleep 8

echo
echo "=== STATUS ==="
bash cybra_finance.sh status
cybra status
cybra results | head -5

echo
echo "=== FINANCE DEPARTMENT INSTALLED ==="
