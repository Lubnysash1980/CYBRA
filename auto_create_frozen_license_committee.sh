#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA"

echo "=== CREATE CYBRA FROZEN LICENSE COMMITTEE ==="

mkdir -p \
  parliament/committees/frozen_license_committee \
  parliament/departments/finance_department/frozen_license_committee \
  parliament/departments/cybra_finance_department/frozen_license_committee \
  data/frozen_license_committee/{licenses,cases,evidence,frozen,unfrozen,reports,tasks} \
  posts feeds proofs logs/frozen_license_committee runtime/redis runtime

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes \
    --bind 127.0.0.1 \
    --port 6379 \
    --dir "$HOME/CYBRA/runtime/redis" \
    --save "" \
    --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

cat > parliament/committees/frozen_license_committee/committee.json <<'JSON'
{
  "committee_id": "frozen_license_committee",
  "name": "Frozen Committee for OWNER Licenses",
  "status": "active",
  "parent": "cybra_parliament",
  "mission": "Protect OWNER licenses. If unauthorized commercial use is detected and confirmed by audit, mark the subject with internal CYBRA status: FROZEN.",
  "scope": [
    "OWNER license registry",
    "commercial use audit",
    "evidence collection",
    "violation confirmation",
    "internal FROZEN status",
    "manual OWNER review",
    "unfreeze only by OWNER approval"
  ],
  "frozen_meaning": [
    "commercial permission suspended",
    "monetization rights blocked",
    "integration rights revoked",
    "license case requires OWNER review"
  ],
  "blocked_actions": [
    "no account seizure",
    "no bank blocking",
    "no external system interference",
    "no unlawful access",
    "no automatic financial action",
    "no automatic SWIFT",
    "no automatic external transaction"
  ],
  "rule": "FROZEN applies only after audit confirms a license violation. FROZEN is an internal CYBRA/KYBRA license status.",
  "manual_OWNER_approval_required": true
}
JSON

cp parliament/committees/frozen_license_committee/committee.json \
   parliament/departments/finance_department/frozen_license_committee/committee.json 2>/dev/null || true

cp parliament/committees/frozen_license_committee/committee.json \
   parliament/departments/cybra_finance_department/frozen_license_committee/committee.json 2>/dev/null || true

cat > cybra_frozen_committee.py <<'PY'
#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
import sys
from pathlib import Path

ROOT = Path.home() / "CYBRA"

AUDIT_KEY = "cybra:frozen_committee:audit"
FROZEN_KEY = "cybra:frozen_committee:frozen"
AI_BLOCK_INBOX = "cybra:ai:tasks:block_inbox"

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(obj):
    text = json.dumps(obj, ensure_ascii=False, sort_keys=True)
    return sha(sha(text))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def run(cmd):
    try:
        p = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
        return p.returncode, p.stdout.strip(), p.stderr.strip()
    except Exception as e:
        return 1, "", str(e)

def rpush(key, obj):
    run(["redis-cli", "LPUSH", key, json.dumps(obj, ensure_ascii=False)])

def hset(key, field, value):
    run(["redis-cli", "HSET", key, field, value])

def hdel(key, field):
    run(["redis-cli", "HDEL", key, field])

def rlen(key):
    code, out, err = run(["redis-cli", "LLEN", key])
    return int(out) if code == 0 and out.strip().isdigit() else 0

def hlen(key):
    code, out, err = run(["redis-cli", "HLEN", key])
    return int(out) if code == 0 and out.strip().isdigit() else 0

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

def license_id(name):
    return sha(name.strip().lower())[:16]

def case_id(license_name, subject, evidence):
    base = license_name.strip().lower() + "|" + subject.strip().lower() + "|" + evidence.strip().lower()
    return sha(base)[:16]

def register_license(name, description="OWNER controlled license"):
    lid = license_id(name)
    obj = {
        "license_id": lid,
        "license_name": name,
        "description": description,
        "owner_controlled": True,
        "commercial_use_requires_owner_approval": True,
        "frozen_rule": "If unauthorized commercial use is detected and confirmed by audit, mark internal status FROZEN.",
        "created_at": time.time(),
        "created_at_iso": now_iso(),
        "safety": {
            "internal_status_only": True,
            "real_payment_now": False,
            "automatic_SWIFT": False,
            "automatic_external_tx": False,
            "external_blocking": False,
            "manual_OWNER_approval_required": True
        }
    }
    obj["double_sha"] = dsha(obj)
    save(f"data/frozen_license_committee/licenses/{lid}.json", obj)
    rpush(AUDIT_KEY, {"status": "license_registered", "license_id": lid, "license_name": name, "double_sha": obj["double_sha"], "time": time.time()})
    print("✅ license registered")
    print("LICENSE_ID:", lid)
    print("LICENSE:", name)

def add_case(license_name, subject, evidence):
    lid = license_id(license_name)
    cid = case_id(license_name, subject, evidence)

    if not (ROOT / f"data/frozen_license_committee/licenses/{lid}.json").exists():
        register_license(license_name, "Auto-created OWNER license registry entry")

    obj = {
        "case_id": cid,
        "license_id": lid,
        "license_name": license_name,
        "subject": subject,
        "evidence": evidence,
        "status": "PENDING_AUDIT",
        "created_at": time.time(),
        "created_at_iso": now_iso(),
        "safety": {
            "internal_status_only": True,
            "real_payment_now": False,
            "automatic_external_tx": False,
            "external_blocking": False,
            "manual_OWNER_approval_required": True
        }
    }
    obj["double_sha"] = dsha(obj)
    save(f"data/frozen_license_committee/cases/{cid}.json", obj)
    save(f"data/frozen_license_committee/evidence/{cid}_evidence.json", obj)

    rpush(AUDIT_KEY, {"status": "case_added", "case_id": cid, "license_name": license_name, "subject": subject, "double_sha": obj["double_sha"], "time": time.time()})
    print("✅ case added")
    print("CASE_ID:", cid)
    print("STATUS: PENDING_AUDIT")

def detect_violation(case):
    text = json.dumps(case, ensure_ascii=False).lower()

    commercial_markers = [
        "commercial", "paid", "sale", "sold", "monetize", "monetization",
        "subscription", "saas", "api", "backend", "platform", "service",
        "client", "customer", "revenue", "for profit", "business use"
    ]

    no_license_markers = [
        "unauthorized", "without permission", "without owner approval",
        "no license", "unlicensed", "copied", "redistributed without permission",
        "commercial use without approval"
    ]

    license_ok_markers = [
        "owner approval", "owner-approved", "valid license", "licensed",
        "written authorization", "permission granted", "license_id"
    ]

    commercial_found = any(x in text for x in commercial_markers)
    no_license_found = any(x in text for x in no_license_markers)
    license_ok_found = any(x in text for x in license_ok_markers)

    confirmed = commercial_found and no_license_found and not license_ok_found

    reasons = []
    if commercial_found:
        reasons.append("commercial_use_detected")
    else:
        reasons.append("commercial_use_not_confirmed")

    if no_license_found:
        reasons.append("no_owner_license_detected")
    else:
        reasons.append("license_violation_not_confirmed")

    if license_ok_found:
        reasons.append("valid_license_or_owner_permission_detected")

    return {
        "violation_confirmed": confirmed,
        "commercial_found": commercial_found,
        "no_license_found": no_license_found,
        "license_ok_found": license_ok_found,
        "reasons": reasons
    }

def audit_case(cid):
    case = load(f"data/frozen_license_committee/cases/{cid}.json", {})
    if not case:
        raise SystemExit("case not found")

    result = detect_violation(case)

    audit = {
        "status": "audit_completed",
        "case_id": cid,
        "license_name": case.get("license_name"),
        "subject": case.get("subject"),
        "result": result,
        "time": time.time(),
        "time_iso": now_iso(),
        "safety": {
            "internal_status_only": True,
            "real_payment_now": False,
            "automatic_SWIFT": False,
            "automatic_external_tx": False,
            "external_blocking": False,
            "manual_OWNER_approval_required": True
        }
    }
    audit["double_sha"] = dsha(audit)

    case["last_audit"] = audit
    case["status"] = "VIOLATION_CONFIRMED" if result["violation_confirmed"] else "NO_CONFIRMED_VIOLATION"
    case["updated_at"] = time.time()
    case["double_sha"] = dsha(case)

    save(f"data/frozen_license_committee/cases/{cid}.json", case)
    save(f"data/frozen_license_committee/evidence/{cid}_audit.json", audit)

    rpush(AUDIT_KEY, audit)

    print("✅ audit completed")
    print("CASE_ID:", cid)
    print("VIOLATION_CONFIRMED:", result["violation_confirmed"])
    print("STATUS:", case["status"])

    return case, audit

def freeze_case(cid):
    case, audit = audit_case(cid)

    if not audit["result"]["violation_confirmed"]:
        print("⚠ NOT FROZEN: violation not confirmed")
        return

    frozen = {
        "status": "FROZEN",
        "case_id": cid,
        "license_id": case.get("license_id"),
        "license_name": case.get("license_name"),
        "subject": case.get("subject"),
        "reason": "unauthorized commercial use confirmed by audit",
        "audit_sha": audit["double_sha"],
        "frozen_at": time.time(),
        "frozen_at_iso": now_iso(),
        "scope": "internal CYBRA/KYBRA license status only",
        "effects": [
            "commercial_permission_suspended",
            "monetization_rights_blocked",
            "integration_rights_revoked",
            "manual_OWNER_review_required"
        ],
        "safety": {
            "no_account_seizure": True,
            "no_bank_blocking": True,
            "no_external_interference": True,
            "internal_status_only": True,
            "real_payment_now": False,
            "automatic_SWIFT": False,
            "automatic_external_tx": False,
            "external_blocking": False,
            "manual_OWNER_approval_required": True
        }
    }
    frozen["double_sha"] = dsha(frozen)

    save(f"data/frozen_license_committee/frozen/{cid}.json", frozen)
    hset(FROZEN_KEY, cid, json.dumps(frozen, ensure_ascii=False))
    rpush(AUDIT_KEY, frozen)

    case["status"] = "FROZEN"
    case["frozen"] = frozen
    case["double_sha"] = dsha(case)
    save(f"data/frozen_license_committee/cases/{cid}.json", case)

    print("🧊 INTERNAL STATUS: FROZEN")
    print("CASE_ID:", cid)
    print("DOUBLE_SHA:", frozen["double_sha"])

def unfreeze_case(cid, reason):
    frozen_path = ROOT / f"data/frozen_license_committee/frozen/{cid}.json"
    case = load(f"data/frozen_license_committee/cases/{cid}.json", {})

    obj = {
        "status": "UNFROZEN_BY_OWNER_REVIEW",
        "case_id": cid,
        "reason": reason,
        "time": time.time(),
        "time_iso": now_iso(),
        "manual_OWNER_approval_required": True,
        "real_payment_now": False,
        "automatic_external_tx": False
    }
    obj["double_sha"] = dsha(obj)

    save(f"data/frozen_license_committee/unfrozen/{cid}.json", obj)

    if case:
        case["status"] = "UNFROZEN_BY_OWNER_REVIEW"
        case["unfreeze"] = obj
        case["double_sha"] = dsha(case)
        save(f"data/frozen_license_committee/cases/{cid}.json", case)

    hdel(FROZEN_KEY, cid)
    rpush(AUDIT_KEY, obj)

    print("✅ case unfrozen by OWNER review")
    print("CASE_ID:", cid)

def scan_all():
    files = list((ROOT / "data/frozen_license_committee/cases").glob("*.json"))
    frozen_count = 0

    for p in files:
        cid = p.stem
        case, audit = audit_case(cid)
        if audit["result"]["violation_confirmed"]:
            freeze_case(cid)
            frozen_count += 1

    print("✅ scan completed")
    print("CASES:", len(files))
    print("FROZEN_NOW:", frozen_count)

def submit_ai():
    task = {
        "topic": "Frozen Committee OWNER License Audit",
        "type": "frozen_license_committee_task",
        "priority": "critical",
        "payload": {
            "source": "frozen_license_committee",
            "goal": "Audit OWNER licenses. If unauthorized commercial use is detected and confirmed, mark internal CYBRA status as FROZEN.",
            "committee": "frozen_license_committee",
            "audit_required": True,
            "evidence_required": True,
            "violation_confirmation_required": True,
            "frozen_scope": "internal_status_only",
            "convert_to_mining_block_first": True,
            "send_to_pool_mining": True,
            "real_payment_now": False,
            "automatic_SWIFT": False,
            "automatic_external_tx": False,
            "external_blocking": False,
            "manual_OWNER_approval_required": True
        },
        "time": time.time(),
        "time_iso": now_iso()
    }
    task["double_sha"] = dsha(task)

    save("data/frozen_license_committee/tasks/latest_ai_task.json", task)
    rpush(AI_BLOCK_INBOX, task)
    rpush(AUDIT_KEY, {"status": "ai_task_submitted", "double_sha": task["double_sha"], "time": task["time"]})

    print("✅ AI task submitted to block inbox")
    print("DOUBLE_SHA:", task["double_sha"])

def report():
    licenses = [load(str(p.relative_to(ROOT)), {}) for p in (ROOT / "data/frozen_license_committee/licenses").glob("*.json")]
    cases = [load(str(p.relative_to(ROOT)), {}) for p in (ROOT / "data/frozen_license_committee/cases").glob("*.json")]
    frozen = [load(str(p.relative_to(ROOT)), {}) for p in (ROOT / "data/frozen_license_committee/frozen").glob("*.json")]

    obj = {
        "status": "frozen_license_committee_report_generated",
        "time": time.time(),
        "time_iso": now_iso(),
        "licenses_total": len(licenses),
        "cases_total": len(cases),
        "frozen_total": len(frozen),
        "licenses": [{"license_id": x.get("license_id"), "license_name": x.get("license_name")} for x in licenses],
        "cases": [{"case_id": x.get("case_id"), "license_name": x.get("license_name"), "subject": x.get("subject"), "status": x.get("status")} for x in cases],
        "frozen": [{"case_id": x.get("case_id"), "license_name": x.get("license_name"), "subject": x.get("subject"), "status": x.get("status"), "reason": x.get("reason")} for x in frozen],
        "queues": {
            "audit": rlen(AUDIT_KEY),
            "frozen_hash": hlen(FROZEN_KEY),
            "ai_block_inbox": rlen(AI_BLOCK_INBOX),
            "parliament_queue": rlen("cybra:parliament:queue"),
            "parliament_failed": rlen("cybra:parliament:failed")
        },
        "safety": {
            "internal_status_only": True,
            "real_payment_now": False,
            "automatic_SWIFT": False,
            "automatic_external_tx": False,
            "external_blocking": False,
            "manual_OWNER_approval_required": True
        }
    }
    obj["double_sha"] = dsha(obj)

    save("feeds/frozen_license_committee_report.json", obj)
    save("data/frozen_license_committee/reports/latest_report.json", obj)

    lines = []
    lines.append("# CYBRA Frozen License Committee Report")
    lines.append("")
    lines.append("Status: generated")
    lines.append(f"Licenses total: {obj['licenses_total']}")
    lines.append(f"Cases total: {obj['cases_total']}")
    lines.append(f"Frozen total: {obj['frozen_total']}")
    lines.append("")
    lines.append("## Licenses")
    if obj["licenses"]:
        for x in obj["licenses"]:
            lines.append(f"- {x['license_id']} / {x['license_name']}")
    else:
        lines.append("None")
    lines.append("")
    lines.append("## Cases")
    if obj["cases"]:
        for x in obj["cases"]:
            lines.append(f"- {x['case_id']} / {x['status']} / {x['license_name']} / {x['subject']}")
    else:
        lines.append("None")
    lines.append("")
    lines.append("## Frozen")
    if obj["frozen"]:
        for x in obj["frozen"]:
            lines.append(f"- FROZEN / {x['case_id']} / {x['license_name']} / {x['subject']}")
    else:
        lines.append("None")
    lines.append("")
    lines.append("## Rule")
    lines.append("If unauthorized commercial use of an OWNER license is detected and confirmed by audit, the subject receives internal STATUS: FROZEN.")
    lines.append("")
    lines.append("## Safety")
    for k, v in obj["safety"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Double SHA")
    lines.append(obj["double_sha"])

    (ROOT / "posts/frozen_license_committee_report.md").write_text("\n".join(lines), encoding="utf-8")

    with (ROOT / "proofs/frozen_license_committee.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "parliament/committees/frozen_license_committee/committee.json",
            "feeds/frozen_license_committee_report.json",
            "posts/frozen_license_committee_report.md"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    print("✅ report generated")
    print("REPORT: posts/frozen_license_committee_report.md")
    print("PROOF: proofs/frozen_license_committee.sha256")

def status():
    print("FROZEN_LICENSE_COMMITTEE: active")
    print("AUDIT:", rlen(AUDIT_KEY))
    print("FROZEN:", hlen(FROZEN_KEY))
    print("AI_BLOCK_INBOX:", rlen(AI_BLOCK_INBOX))
    print("PARLIAMENT_FAILED:", rlen("cybra:parliament:failed"))
    print("REPORT_EXISTS:", (ROOT / "posts/frozen_license_committee_report.md").exists())

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "status":
        status()
    elif cmd == "register":
        name = sys.argv[2] if len(sys.argv) > 2 else "OWNER License"
        desc = " ".join(sys.argv[3:]) if len(sys.argv) > 3 else "OWNER controlled license"
        register_license(name, desc)
    elif cmd == "case":
        if len(sys.argv) < 5:
            raise SystemExit("Usage: case LICENSE_NAME SUBJECT EVIDENCE")
        add_case(sys.argv[2], sys.argv[3], " ".join(sys.argv[4:]))
    elif cmd == "audit":
        audit_case(sys.argv[2])
    elif cmd == "freeze":
        freeze_case(sys.argv[2])
    elif cmd == "unfreeze":
        reason = " ".join(sys.argv[3:]) if len(sys.argv) > 3 else "OWNER manual review"
        unfreeze_case(sys.argv[2], reason)
    elif cmd == "scan":
        scan_all()
    elif cmd == "submit-ai":
        submit_ai()
    elif cmd == "report":
        report()
    elif cmd == "cycle":
        submit_ai()
        scan_all()
        report()
    else:
        raise SystemExit("Usage: status|register NAME DESC|case LICENSE SUBJECT EVIDENCE|audit CASE_ID|freeze CASE_ID|unfreeze CASE_ID REASON|scan|submit-ai|report|cycle")

if __name__ == "__main__":
    main()
PY

chmod +x cybra_frozen_committee.py

cat > cybra_frozen_committee.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  status|scan|submit-ai|report|cycle)
    python3 cybra_frozen_committee.py "$@"
    ;;
  register)
    shift
    python3 cybra_frozen_committee.py register "$@"
    ;;
  case)
    shift
    python3 cybra_frozen_committee.py case "$@"
    ;;
  audit)
    python3 cybra_frozen_committee.py audit "$2"
    ;;
  freeze)
    python3 cybra_frozen_committee.py freeze "$2"
    ;;
  unfreeze)
    shift
    python3 cybra_frozen_committee.py unfreeze "$@"
    ;;
  proof)
    cat proofs/frozen_license_committee.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_frozen_committee.sh status"
    echo "  bash cybra_frozen_committee.sh register 'Hash Module' 'OWNER Hash Module license'"
    echo "  bash cybra_frozen_committee.sh case 'Hash Module' 'Subject' 'evidence text'"
    echo "  bash cybra_frozen_committee.sh audit CASE_ID"
    echo "  bash cybra_frozen_committee.sh freeze CASE_ID"
    echo "  bash cybra_frozen_committee.sh unfreeze CASE_ID 'OWNER approved'"
    echo "  bash cybra_frozen_committee.sh scan"
    echo "  bash cybra_frozen_committee.sh cycle"
    ;;
esac
EOF

chmod +x cybra_frozen_committee.sh

cat > cybra_frozen_committee_handler.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

bash cybra_frozen_committee.sh cycle >/dev/null 2>&1 || true
EOF

chmod +x cybra_frozen_committee_handler.sh

redis-cli HSET cybra:executor:mapping frozen_license_committee_task cybra_frozen_committee_handler.sh >/dev/null || true

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

    if '"frozen_license_committee_task"' not in s:
        i = s.find("SCRIPT_MAP")
        j = s.find("{", i)
        if i >= 0 and j >= 0:
            s = s[:j+1] + '\n    "frozen_license_committee_task": "cybra_frozen_committee_handler.sh",' + s[j+1:]

    p.write_text(s, encoding="utf-8")
    print("✅ parliament executor patched")
else:
    print("⚠ parliament_executor_v6.py not found")
PY

python3 -m py_compile cybra_frozen_committee.py
test -f parliament_executor_v6.py && python3 -m py_compile parliament_executor_v6.py || true
rm -rf __pycache__

echo
echo "=== REGISTER DEFAULT OWNER LICENSES ==="
bash cybra_frozen_committee.sh register "Hash Module" "OWNER controlled Hash Module commercial license"
bash cybra_frozen_committee.sh register "CYBRA/KYBRA Core Modules" "OWNER controlled CYBRA/KYBRA ecosystem license"

echo
echo "=== SUBMIT AI TASK + REPORT ==="
bash cybra_frozen_committee.sh submit-ai
bash cybra_frozen_committee.sh report

if [ -f cybra_closed_sha_bridge.sh ]; then
  bash cybra_closed_sha_bridge.sh cycle || true
fi

echo
echo "=== STATUS ==="
bash cybra_frozen_committee.sh status
sha256sum -c proofs/frozen_license_committee.sha256 || true

echo
echo "✅ FROZEN LICENSE COMMITTEE INSTALLED"
