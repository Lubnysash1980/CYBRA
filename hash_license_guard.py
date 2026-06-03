#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
import sys
from pathlib import Path

ROOT = Path.home() / "CYBRA"

AUDIT_KEY = "cybra:hash_license_guard:audit"
FROZEN_KEY = "cybra:hash_license_guard:frozen"
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

def hlen(key):
    code, out, err = run(["redis-cli", "HLEN", key])
    return int(out) if code == 0 and out.isdigit() else 0

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

def subject_id(name):
    return sha(name.strip().lower())[:16]

def add_subject(name, evidence="", commercial="unknown", has_license="unknown"):
    sid = subject_id(name)
    obj = {
        "subject_id": sid,
        "subject": name,
        "commercial_use": commercial,
        "has_owner_license": has_license,
        "evidence": evidence,
        "status": "PENDING_AUDIT",
        "created_at": time.time(),
        "created_at_iso": now_iso()
    }
    obj["double_sha"] = dsha(obj)
    save(f"data/hash_license_guard/subjects/{sid}.json", obj)

    rpush(AUDIT_KEY, {
        "status": "subject_added",
        "subject_id": sid,
        "subject": name,
        "double_sha": obj["double_sha"],
        "time": obj["created_at"]
    })

    print("✅ subject added")
    print("SUBJECT_ID:", sid)
    print("STATUS: PENDING_AUDIT")

def detect_violation(obj):
    evidence = json.dumps(obj, ensure_ascii=False).lower()

    commercial_markers = [
        "paid", "commercial", "monetize", "monetization", "sale", "sold",
        "subscription", "saas", "api", "backend", "service", "platform",
        "for profit", "client", "customers", "revenue"
    ]

    license_positive = [
        "owner approval", "owner-approved", "licensed", "valid license",
        "written authorization", "license_id", "permission granted"
    ]

    license_negative = [
        "without permission", "unauthorized", "no license", "copied",
        "stolen", "unlicensed", "no owner approval", "without owner approval"
    ]

    commercial_found = obj.get("commercial_use") is True or obj.get("commercial_use") == "true" or any(x in evidence for x in commercial_markers)
    licensed_found = obj.get("has_owner_license") is True or obj.get("has_owner_license") == "true" or any(x in evidence for x in license_positive)
    unlicensed_found = obj.get("has_owner_license") is False or obj.get("has_owner_license") == "false" or any(x in evidence for x in license_negative)

    violation_confirmed = commercial_found and unlicensed_found and not licensed_found

    reasons = []
    if commercial_found:
        reasons.append("commercial_use_detected")
    if unlicensed_found:
        reasons.append("no_valid_owner_license_detected")
    if licensed_found:
        reasons.append("owner_license_or_permission_detected")
    if not commercial_found:
        reasons.append("commercial_use_not_confirmed")
    if not unlicensed_found:
        reasons.append("license_violation_not_confirmed")

    return {
        "violation_confirmed": violation_confirmed,
        "commercial_found": commercial_found,
        "licensed_found": licensed_found,
        "unlicensed_found": unlicensed_found,
        "reasons": reasons
    }

def audit_subject(sid):
    obj = load(f"data/hash_license_guard/subjects/{sid}.json", {})
    if not obj:
        raise SystemExit("subject not found")

    result = detect_violation(obj)

    audit = {
        "status": "audit_completed",
        "subject_id": sid,
        "subject": obj.get("subject"),
        "audit_result": result,
        "time": time.time(),
        "time_iso": now_iso(),
        "safety": {
            "internal_status_only": True,
            "real_payment_now": False,
            "automatic_external_tx": False,
            "external_blocking": False,
            "manual_OWNER_approval_required": True
        }
    }
    audit["double_sha"] = dsha(audit)

    obj["last_audit"] = audit
    obj["status"] = "VIOLATION_CONFIRMED" if result["violation_confirmed"] else "NO_CONFIRMED_VIOLATION"
    obj["updated_at"] = time.time()
    obj["double_sha"] = dsha(obj)

    save(f"data/hash_license_guard/subjects/{sid}.json", obj)
    save(f"data/hash_license_guard/evidence/{sid}_audit.json", audit)

    rpush(AUDIT_KEY, audit)

    print("✅ audit completed")
    print("SUBJECT_ID:", sid)
    print("VIOLATION_CONFIRMED:", result["violation_confirmed"])
    print("STATUS:", obj["status"])

    return obj, audit

def freeze_subject(sid):
    obj, audit = audit_subject(sid)

    if not audit["audit_result"]["violation_confirmed"]:
        print("⚠ not frozen: violation not confirmed")
        return

    frozen = {
        "status": "FROZEN",
        "subject_id": sid,
        "subject": obj.get("subject"),
        "reason": "unauthorized commercial use of Hash Module confirmed by audit",
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
            "no_external_interference": True,
            "real_payment_now": False,
            "automatic_external_tx": False,
            "external_blocking": False,
            "manual_OWNER_approval_required": True
        }
    }
    frozen["double_sha"] = dsha(frozen)

    save(f"data/hash_license_guard/frozen/{sid}.json", frozen)
    hset(FROZEN_KEY, sid, json.dumps(frozen, ensure_ascii=False))
    rpush(AUDIT_KEY, frozen)

    obj["status"] = "FROZEN"
    obj["frozen"] = frozen
    obj["double_sha"] = dsha(obj)
    save(f"data/hash_license_guard/subjects/{sid}.json", obj)

    print("🧊 STATUS: FROZEN")
    print("SUBJECT_ID:", sid)
    print("DOUBLE_SHA:", frozen["double_sha"])

def scan_all():
    subjects = list((ROOT / "data/hash_license_guard/subjects").glob("*.json"))
    results = []

    for p in subjects:
        sid = p.stem
        obj, audit = audit_subject(sid)
        if audit["audit_result"]["violation_confirmed"]:
            freeze_subject(sid)
        results.append({
            "subject_id": sid,
            "subject": obj.get("subject"),
            "status": load(f"data/hash_license_guard/subjects/{sid}.json", {}).get("status"),
            "violation_confirmed": audit["audit_result"]["violation_confirmed"]
        })

    print("✅ scan completed")
    print("SUBJECTS:", len(results))
    print("FROZEN:", len([x for x in results if x["status"] == "FROZEN"]))

def submit_ai_task():
    task = {
        "topic": "Hash Module License Guard Audit",
        "type": "hash_license_violation_audit_task",
        "priority": "critical",
        "payload": {
            "source": "hash_license_guard_committee",
            "goal": "Audit unauthorized commercial use of the OWNER Hash Module. If violation is found and confirmed by audit, mark internal CYBRA status as FROZEN.",
            "license_policy": "data/hash_license_guard/license_policy.json",
            "committee": "hash_license_guard_committee",
            "frozen_scope": "internal_status_only",
            "convert_to_mining_block_first": True,
            "send_to_pool_mining": True,
            "audit_required": True,
            "evidence_required": True,
            "violation_confirmation_required": True,
            "real_payment_now": False,
            "automatic_external_tx": False,
            "external_blocking": False,
            "manual_OWNER_approval_required": True
        },
        "time": time.time(),
        "time_iso": now_iso()
    }
    task["double_sha"] = dsha(task)

    save("data/hash_license_guard/tasks/latest_ai_task.json", task)
    rpush(AI_BLOCK_INBOX, task)
    rpush(AUDIT_KEY, {"status": "ai_task_submitted", "double_sha": task["double_sha"], "time": task["time"]})

    print("✅ AI task submitted to CYBRA Parliament block inbox")
    print("DOUBLE_SHA:", task["double_sha"])

def report():
    subjects = []
    frozen_files = list((ROOT / "data/hash_license_guard/frozen").glob("*.json"))
    subject_files = list((ROOT / "data/hash_license_guard/subjects").glob("*.json"))

    for p in subject_files:
        subjects.append(load(str(p.relative_to(ROOT)), {}))

    frozen = []
    for p in frozen_files:
        frozen.append(load(str(p.relative_to(ROOT)), {}))

    obj = {
        "status": "hash_license_guard_report_generated",
        "time": time.time(),
        "time_iso": now_iso(),
        "subjects_total": len(subjects),
        "frozen_total": len(frozen),
        "subjects": [
            {
                "subject_id": x.get("subject_id"),
                "subject": x.get("subject"),
                "status": x.get("status")
            } for x in subjects
        ],
        "frozen": [
            {
                "subject_id": x.get("subject_id"),
                "subject": x.get("subject"),
                "status": x.get("status"),
                "reason": x.get("reason")
            } for x in frozen
        ],
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
            "automatic_external_tx": False,
            "external_blocking": False,
            "manual_OWNER_approval_required": True
        }
    }
    obj["double_sha"] = dsha(obj)

    save("feeds/hash_license_guard_report.json", obj)
    save("data/hash_license_guard/reports/latest_report.json", obj)

    lines = []
    lines.append("# CYBRA Hash License Guard Report")
    lines.append("")
    lines.append("Status: generated")
    lines.append(f"Subjects total: {obj['subjects_total']}")
    lines.append(f"Frozen total: {obj['frozen_total']}")
    lines.append("")
    lines.append("## Subjects")
    if obj["subjects"]:
        for s in obj["subjects"]:
            lines.append(f"- {s['subject_id']} / {s['status']} / {s['subject']}")
    else:
        lines.append("None")
    lines.append("")
    lines.append("## Frozen")
    if obj["frozen"]:
        for f in obj["frozen"]:
            lines.append(f"- FROZEN / {f['subject_id']} / {f['subject']} / {f['reason']}")
    else:
        lines.append("None")
    lines.append("")
    lines.append("## Rule")
    lines.append("If unauthorized commercial use of the Hash Module is found and confirmed by audit, the subject is marked STATUS: FROZEN.")
    lines.append("")
    lines.append("## Safety")
    for k, v in obj["safety"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Double SHA")
    lines.append(obj["double_sha"])

    (ROOT / "posts/hash_license_guard_report.md").write_text("\n".join(lines), encoding="utf-8")

    with (ROOT / "proofs/hash_license_guard.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "data/hash_license_guard/license_policy.json",
            "parliament/departments/finance_department/hash_license_guard_committee/committee.json",
            "feeds/hash_license_guard_report.json",
            "posts/hash_license_guard_report.md"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    print("✅ report generated")
    print("REPORT: posts/hash_license_guard_report.md")
    print("PROOF: proofs/hash_license_guard.sha256")

def status():
    print("HASH_LICENSE_GUARD: active")
    print("AUDIT:", rlen(AUDIT_KEY))
    print("FROZEN:", hlen(FROZEN_KEY))
    print("AI_BLOCK_INBOX:", rlen(AI_BLOCK_INBOX))
    print("PARLIAMENT_FAILED:", rlen("cybra:parliament:failed"))
    print("REPORT_EXISTS:", (ROOT / "posts/hash_license_guard_report.md").exists())

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "status":
        status()
    elif cmd == "add":
        name = sys.argv[2] if len(sys.argv) > 2 else "UNKNOWN_SUBJECT"
        evidence = " ".join(sys.argv[3:]) if len(sys.argv) > 3 else ""
        add_subject(name, evidence=evidence)
    elif cmd == "audit":
        audit_subject(sys.argv[2])
    elif cmd == "freeze":
        freeze_subject(sys.argv[2])
    elif cmd == "scan":
        scan_all()
    elif cmd == "submit-ai":
        submit_ai_task()
    elif cmd == "report":
        report()
    elif cmd == "cycle":
        submit_ai_task()
        scan_all()
        report()
    else:
        raise SystemExit("Usage: status|add NAME EVIDENCE|audit SUBJECT_ID|freeze SUBJECT_ID|scan|submit-ai|report|cycle")

if __name__ == "__main__":
    main()
