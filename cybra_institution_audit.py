#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from pathlib import Path
from collections import Counter, defaultdict

import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

TASK_KEYS = [
    "cybra:parliament:queue",
    "cybra:parliament:results",
    "cybra:parliament:failed",
    "cybra:review:approved",
    "cybra:review:hold",
    "cybra:review:rejected",
    "cybra:evolution:approved",
    "cybra:evolution:hold",
    "cybra:evolution:rejected"
]

REQUIRED_ORGANS = {
    "review": {
        "path": "parliament/review",
        "purpose": "Перевірка задач перед виконанням"
    },
    "revision": {
        "path": "parliament/revision",
        "purpose": "Ревізія виконаних і невиконаних задач"
    },
    "analytics": {
        "path": "parliament/analytics",
        "purpose": "Аналітика результатів роботи"
    },
    "education": {
        "path": "parliament/education",
        "purpose": "Освіта, інструкції, документація"
    },
    "evo": {
        "path": "parliament/evo",
        "purpose": "Створення нових комітетів і розвиток"
    },
    "evolution": {
        "path": "parliament/evolution",
        "purpose": "Фільтр розвитку проти деградації"
    },
    "audit": {
        "path": "parliament/audit",
        "purpose": "Audit, dedupe, tag logging"
    },
    "protection": {
        "path": "parliament/protection",
        "purpose": "Захист системи, секретів, Git, runtime"
    },
    "departments": {
        "path": "parliament/departments",
        "purpose": "Департаменти підтримки платформи"
    },
    "committees": {
        "path": "parliament/committees",
        "purpose": "Комітети під типи задач"
    }
}

CORE_DEPARTMENTS = {
    "executor_department": "Контроль executor, worker, handler execution",
    "mapping_department": "Redis executor mapping і відсутні handler-и",
    "security_department": "Захист від секретів у Git, private keys, runtime leaks",
    "proof_department": "Proof, sha256, double SHA, root hash",
    "recovery_department": "AutoHeal, recovery capsule, backup/restore",
    "statistics_department": "Статистика задач, статусів, результатів",
    "legal_compliance_department": "Правовий і безпечний compliance-filter",
    "evolution_department": "Принцип розвитку, hold/reject деградаційних задач"
}

PROTECTION_RULES = {
    "git_secret_guard": [
        "private_vault/",
        "dump.rdb",
        "token/runtime/rpc.env",
        "__pycache__/",
        "ai_network/",
        "recovery_packs/",
        "recovery_unpack/"
    ],
    "execution_guard": [
        "no private keys in Git",
        "no secret dump",
        "no uncontrolled payments",
        "no illegal actions",
        "review before sensitive tasks",
        "evolution-only development"
    ],
    "task_integrity": [
        "double_sha",
        "fingerprint",
        "audit",
        "dedupe",
        "proof",
        "result record"
    ]
}

def sha(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def dsha(text: str) -> str:
    return sha(sha(text))

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
    return {"status": "raw_unparsed", "_source_key": source, "raw": raw}

def scan_tasks():
    items = []
    for key in TASK_KEYS:
        try:
            for raw in r.lrange(key, 0, 499):
                items.append(load_json(raw, key))
        except Exception:
            pass
    return items

def slug(text):
    text = str(text or "unknown").lower()
    safe = []
    for ch in text:
        if ch.isalnum() or ch in "_-":
            safe.append(ch)
        elif ch.isspace():
            safe.append("_")
    s = "".join(safe).strip("_")
    return s[:80] or "unknown"

def file_count(path):
    p = ROOT / path
    if not p.exists():
        return 0
    return sum(1 for x in p.rglob("*") if x.is_file())

def committee_path_for_type(task_type):
    return ROOT / "parliament" / "committees" / f"{slug(task_type)}_committee"

def create_department(dep_id, purpose):
    base = ROOT / "parliament" / "departments" / dep_id
    base.mkdir(parents=True, exist_ok=True)

    obj = {
        "department_id": dep_id,
        "status": "active",
        "purpose": purpose,
        "created_or_checked_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "rules": [
            "audit_required",
            "proof_required",
            "no_private_keys",
            "no_secret_dump",
            "evolution_only"
        ]
    }

    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))

    (base / "department.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2))
    (base / "README.md").write_text(
        f"# {dep_id}\n\nStatus: active\n\nPurpose:\n{purpose}\n\nDouble SHA:\n`{obj['double_sha']}`\n"
    )

    return obj

def create_committee_for_task(task_type, topics):
    cid = f"{slug(task_type)}_committee"
    base = committee_path_for_type(task_type)
    base.mkdir(parents=True, exist_ok=True)

    obj = {
        "committee_id": cid,
        "status": "active",
        "task_type": task_type,
        "topics_seen": sorted(list(set(str(x) for x in topics)))[:20],
        "purpose": f"Підтримувати задачі типу {task_type}: mapping, handler, audit, proof, diagnostics.",
        "powers": [
            "analyze_tasks",
            "recommend_handler",
            "check_mapping",
            "write_reports",
            "request_revision",
            "request_evolution_review"
        ],
        "limits": [
            "no_private_keys",
            "no_secret_dump",
            "no_illegal_actions",
            "no_uncontrolled_payments"
        ],
        "created_or_checked_at": time.strftime("%Y-%m-%dT%H:%M:%S%z")
    }

    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))

    (base / "committee.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2))
    (base / "README.md").write_text(
        f"# {cid}\n\nStatus: active\n\nTask type:\n`{task_type}`\n\nPurpose:\n{obj['purpose']}\n\nDouble SHA:\n`{obj['double_sha']}`\n"
    )

    return obj

def create_protection():
    base = ROOT / "parliament" / "protection"
    base.mkdir(parents=True, exist_ok=True)

    obj = {
        "name": "CYBRA Parliament Protection Layer",
        "status": "active",
        "rules": PROTECTION_RULES,
        "created_or_checked_at": time.strftime("%Y-%m-%dT%H:%M:%S%z")
    }

    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))

    (base / "protection_policy.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2))
    (base / "README.md").write_text(
        "# CYBRA Parliament Protection Layer\n\n"
        "Status: active\n\n"
        "Цей шар перевіряє Git, секрети, runtime, proof, audit, dedupe, evolution-only.\n\n"
        f"Double SHA:\n`{obj['double_sha']}`\n"
    )

    return obj

def ensure_gitignore():
    ignore = ROOT / ".gitignore"
    current = ignore.read_text() if ignore.exists() else ""
    added = []
    for x in PROTECTION_RULES["git_secret_guard"]:
        if x not in current.splitlines():
            current += "\n" + x
            added.append(x)
    ignore.write_text(current.strip() + "\n")
    return added

def audit(repair=False):
    r.ping()

    items = scan_tasks()
    mapping = r.hgetall("cybra:executor:mapping")

    types = Counter(str(x.get("type", "unknown")) for x in items)
    statuses = Counter(str(x.get("status", "unknown")) for x in items)
    sources = Counter(str(x.get("_source_key", "unknown")) for x in items)

    topics_by_type = defaultdict(list)
    for x in items:
        topics_by_type[str(x.get("type", "unknown"))].append(x.get("topic"))

    organ_state = {}
    missing_organs = []

    for organ, meta in REQUIRED_ORGANS.items():
        p = ROOT / meta["path"]
        exists = p.exists()
        organ_state[organ] = {
            "path": meta["path"],
            "exists": exists,
            "files": file_count(meta["path"]),
            "purpose": meta["purpose"]
        }
        if not exists:
            missing_organs.append(organ)

    task_support = []
    missing_support = []
    missing_handlers = []

    for task_type in sorted(types.keys()):
        if task_type in ("None", "unknown", "null"):
            continue

        handler = mapping.get(task_type)
        handler_exists = False

        if handler:
            if handler.endswith(".sh") or handler.endswith(".py") or handler.endswith(".mjs") or handler.endswith(".js"):
                handler_exists = (ROOT / handler).exists()
            else:
                handler_exists = True

        committee_path = committee_path_for_type(task_type)
        committee_exists = committee_path.exists()

        row = {
            "task_type": task_type,
            "count": types[task_type],
            "mapping": handler,
            "mapping_exists": bool(handler),
            "handler_exists": handler_exists,
            "committee_path": str(committee_path.relative_to(ROOT)),
            "committee_exists": committee_exists
        }

        task_support.append(row)

        if not handler:
            missing_support.append(row)
        elif not handler_exists:
            missing_handlers.append(row)

    created = {
        "departments": [],
        "committees": [],
        "protection": False,
        "gitignore_added": []
    }

    if repair:
        for dep_id, purpose in CORE_DEPARTMENTS.items():
            created["departments"].append(create_department(dep_id, purpose))

        create_protection()
        created["protection"] = True
        created["gitignore_added"] = ensure_gitignore()

        for task_type in sorted(types.keys()):
            if task_type in ("None", "unknown", "null"):
                continue
            created["committees"].append(
                create_committee_for_task(task_type, topics_by_type[task_type])
            )

        r.lpush("cybra:institution:audit", json.dumps({
            "status": "repair_executed",
            "time": time.time(),
            "departments_created_or_checked": len(created["departments"]),
            "committees_created_or_checked": len(created["committees"])
        }, ensure_ascii=False))

    recommendations = []

    if missing_organs:
        recommendations.append({
            "level": "critical",
            "message": "Не всі базові органи Кіберапарламенту існують.",
            "missing": missing_organs,
            "action": "Запусти repair: bash cybra_institution.sh repair"
        })

    if missing_support:
        recommendations.append({
            "level": "important",
            "message": "Є типи задач без Redis executor mapping.",
            "types": [x["task_type"] for x in missing_support],
            "action": "Створити handler або направити через EVO committee."
        })

    if missing_handlers:
        recommendations.append({
            "level": "warning",
            "message": "Є mapping, але файл handler-а відсутній.",
            "items": missing_handlers[:20],
            "action": "Відновити handler-файли або змінити mapping."
        })

    no_committee = [x for x in task_support if not x["committee_exists"]]
    if no_committee:
        recommendations.append({
            "level": "development",
            "message": "Для частини task types немає окремих комітетів.",
            "types": [x["task_type"] for x in no_committee[:30]],
            "action": "Запусти repair, щоб створити committee skeleton."
        })

    if not recommendations:
        recommendations.append({
            "level": "ok",
            "message": "Кіберапарламент має базові департаменти, комітети, mapping і захист для поточних тасків.",
            "action": "Продовжувати тестування."
        })

    report = {
        "name": "CYBRA Parliament Institution Audit",
        "status": "generated",
        "mode": "repair" if repair else "check",
        "time": time.time(),
        "git": {
            "branch": git_cmd(["git", "branch", "--show-current"]),
            "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"]),
            "dirty_files": len(git_cmd(["git", "status", "--short"]).splitlines())
        },
        "summary": {
            "tasks_checked": len(items),
            "task_types": len(types),
            "executor_mapping_count": len(mapping),
            "required_organs": len(REQUIRED_ORGANS),
            "missing_organs": len(missing_organs),
            "task_types_without_mapping": len(missing_support),
            "mapped_handlers_missing_files": len(missing_handlers),
            "task_types_without_committee": len(no_committee),
            "departments_files": file_count("parliament/departments"),
            "committees_files": file_count("parliament/committees"),
            "protection_files": file_count("parliament/protection")
        },
        "statuses": dict(statuses),
        "types": dict(types),
        "sources": dict(sources),
        "organ_state": organ_state,
        "task_support": task_support,
        "missing_support": missing_support,
        "missing_handlers": missing_handlers,
        "recommendations": recommendations,
        "created_or_checked": created
    }

    report["double_sha"] = dsha(json.dumps(report, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/institution_audit_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2)
    )

    def lines(data):
        if not data:
            return "- none"
        return "\n".join(f"- `{k}`: {v}" for k, v in sorted(data.items(), key=lambda x: x[1], reverse=True))

    org_md = ""
    for k, v in organ_state.items():
        mark = "✅" if v["exists"] else "❌"
        org_md += f"- {mark} `{k}` — {v['path']} — {v['purpose']}\n"

    support_md = ""
    for row in task_support:
        support_md += (
            f"- `{row['task_type']}` count={row['count']} "
            f"mapping=`{row['mapping']}` handler_exists={row['handler_exists']} "
            f"committee_exists={row['committee_exists']}\n"
        )

    rec_md = ""
    for rec in recommendations:
        rec_md += f"- **{rec.get('level')}**: {rec.get('message')} Action: `{rec.get('action')}`\n"

    md = f"""# CYBRA Parliament Institution Audit

Status: generated  
Mode: {report["mode"]}  
Double SHA: `{report["double_sha"]}`

## Summary

- Tasks checked: {report["summary"]["tasks_checked"]}
- Task types: {report["summary"]["task_types"]}
- Executor mapping count: {report["summary"]["executor_mapping_count"]}
- Required organs: {report["summary"]["required_organs"]}
- Missing organs: {report["summary"]["missing_organs"]}
- Task types without mapping: {report["summary"]["task_types_without_mapping"]}
- Mapped handlers missing files: {report["summary"]["mapped_handlers_missing_files"]}
- Task types without committee: {report["summary"]["task_types_without_committee"]}
- Departments files: {report["summary"]["departments_files"]}
- Committees files: {report["summary"]["committees_files"]}
- Protection files: {report["summary"]["protection_files"]}

## Organs

{org_md}

## Statuses

{lines(report["statuses"])}

## Task types

{lines(report["types"])}

## Task support matrix

{support_md}

## Recommendations

{rec_md}
"""

    (ROOT / "posts/institution_audit_report.md").write_text(md)

    with (ROOT / "proofs/institution_audit_report.sha256").open("w") as f:
        subprocess.run(
            [
                "sha256sum",
                "feeds/institution_audit_report.json",
                "posts/institution_audit_report.md"
            ],
            cwd=ROOT,
            stdout=f,
            stderr=subprocess.DEVNULL
        )

    r.lpush("cybra:institution:audit", json.dumps({
        "status": "institution_audit_generated",
        "mode": report["mode"],
        "time": report["time"],
        "double_sha": report["double_sha"],
        "tasks_checked": len(items),
        "missing_organs": len(missing_organs),
        "missing_mapping": len(missing_support)
    }, ensure_ascii=False))

    print("✅ CYBRA institution audit generated")
    print("Mode:", report["mode"])
    print("Report: posts/institution_audit_report.md")
    print("Feed: feeds/institution_audit_report.json")
    print("Proof: proofs/institution_audit_report.sha256")
    print()
    print(md)

def main():
    import sys
    mode = sys.argv[1] if len(sys.argv) > 1 else "check"
    if mode == "repair":
        audit(repair=True)
    else:
        audit(repair=False)

if __name__ == "__main__":
    main()
