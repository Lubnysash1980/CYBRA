#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

echo "=== CYBRA EVO COMMITTEE MODULE INSTALL START ==="

mkdir -p parliament/evo parliament/committees posts feeds proofs logs/evo handlers

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1
redis-cli ping >/dev/null

python3 - <<'PY' >/dev/null 2>&1 || python3 -m pip install redis
import redis
PY

cat > parliament/evo/evo_laws.json <<'JSON'
{
  "name": "CYBRA EVO Laws",
  "version": "1.0",
  "status": "active",
  "mission": "Дозволити Кіберапарламенту еволюційно створювати нові внутрішні комітети для підтримки своєї роботи.",
  "laws": [
    {
      "id": "EVO-001",
      "name": "Law of Need",
      "rule": "Новий комітет створюється тільки тоді, коли є задача, прогалина, no_executor_mapping або потреба підтримки парламенту."
    },
    {
      "id": "EVO-002",
      "name": "Law of Safety",
      "rule": "Комітет не може виконувати незаконні дії, втручання в чужі акаунти, блокування рахунків, переказ коштів або роботу з private keys."
    },
    {
      "id": "EVO-003",
      "name": "Law of Audit",
      "rule": "Кожне створення комітету пишеться в Redis audit, feeds, posts і proofs."
    },
    {
      "id": "EVO-004",
      "name": "Law of Mapping",
      "rule": "Комітет може отримати executor mapping тільки для безпечного handler-а."
    },
    {
      "id": "EVO-005",
      "name": "Law of Revision",
      "rule": "Нові комітети мають бути видимі ревізійному органу та аналітичному комітету."
    },
    {
      "id": "EVO-006",
      "name": "Law of Reversibility",
      "rule": "Будь-який комітет можна відключити через статус disabled без видалення audit."
    },
    {
      "id": "EVO-007",
      "name": "Law of Proof",
      "rule": "Кожна EVO-дія має double SHA або sha256 proof."
    }
  ],
  "policy": {
    "internal_digital_committees_only": true,
    "no_private_keys": true,
    "no_seed_phrases": true,
    "no_secret_dump": true,
    "no_illegal_actions": true,
    "human_owner_control_required": true
  }
}
JSON

cat > cybra_evo_committee_factory.py <<'PY'
#!/usr/bin/env python3
import json
import time
import hashlib
import re
import sys
import subprocess
from pathlib import Path
from collections import Counter

import redis

r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

RESULT_KEYS = [
    "cybra:parliament:results",
    "cybra:parliament:failed"
]

EVO_AUDIT = "cybra:evo:audit"
EVO_COMMITTEES = "cybra:evo:committees"
EXECUTOR_MAPPING = "cybra:executor:mapping"

DEFAULT_SUPPORT = {
    "self_expanding_execution_engine_task": {
        "committee_id": "self_expansion_committee",
        "name": "Self Expansion Committee",
        "mission": "Аналізувати задачі саморозширення Кіберапарламенту та пропонувати безпечні нові handler-и і комітети."
    },
    "executor_autoheal_task": {
        "committee_id": "guardian_recovery_committee",
        "name": "Guardian Recovery Committee",
        "mission": "Підтримувати executor, autoheal, recovery, double SHA та контроль помилок."
    },
    "codespaces_keepalive_task": {
        "committee_id": "codespaces_support_committee",
        "name": "Codespaces Support Committee",
        "mission": "Підтримувати GitHub Codespaces, keepalive, синхронізацію з Termux та bridge."
    },
    "github_double_backend_task": {
        "committee_id": "github_backend_committee",
        "name": "GitHub Double Backend Committee",
        "mission": "Підтримувати GitHub backend, double SHA, bridge, push/pull, proof-публікації."
    },
    "ai_task": {
        "committee_id": "ai_tasks_committee",
        "name": "AI Tasks Committee",
        "mission": "Перевіряти AI-задачі, формувати безпечні технічні плани та handler-и."
    },
    "queue_fix": {
        "committee_id": "queue_integrity_committee",
        "name": "Queue Integrity Committee",
        "mission": "Контролювати Redis-черги, queue routing, review queue, execution queue та results."
    },
    "test": {
        "committee_id": "testing_committee",
        "name": "Testing Committee",
        "mission": "Перевіряти тестові задачі, handler-и, mapping та результати."
    },
    "air_alert_task": {
        "committee_id": "safety_alert_committee",
        "name": "Safety Alert Committee",
        "mission": "Підтримувати задачі безпеки, повітряної тривоги та official_source_required режим."
    }
}

CORE_COMMITTEES = [
    {
        "committee_id": "evo_council",
        "name": "EVO Council",
        "mission": "Керувати правилами еволюції Кіберапарламенту і дозволом на створення нових комітетів.",
        "task_types": ["evo_committee_task", "committee_creation_task"]
    },
    {
        "committee_id": "executor_mapping_committee",
        "name": "Executor Mapping Committee",
        "mission": "Керувати Redis executor mapping і прибирати no_executor_mapping.",
        "task_types": ["mapping_task"]
    },
    {
        "committee_id": "task_lifecycle_committee",
        "name": "Task Lifecycle Committee",
        "mission": "Стежити за життєвим циклом задачі: review → execution → result → audit → revision.",
        "task_types": ["task_lifecycle_task"]
    },
    {
        "committee_id": "parliament_support_committee",
        "name": "Parliament Support Committee",
        "mission": "Підтримувати роботу Кіберапарламенту, органів, комітетів, звітів і proof-файлів.",
        "task_types": ["parliament_support_task"]
    }
]

def dsha(text: str) -> str:
    h1 = hashlib.sha256(text.encode("utf-8")).hexdigest()
    return hashlib.sha256(h1.encode("utf-8")).hexdigest()

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def slugify(text):
    text = text.lower().strip()
    text = re.sub(r"[^a-z0-9_ -]+", "", text)
    text = re.sub(r"[\s-]+", "_", text)
    text = text.strip("_")
    return text or "committee"

def git_cmd(cmd):
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def safe_json(raw):
    try:
        return json.loads(raw)
    except Exception:
        return None

def detect_no_mapping():
    items = []
    for key in RESULT_KEYS:
        for raw in r.lrange(key, 0, 499):
            obj = safe_json(raw)
            if isinstance(obj, dict) and obj.get("status") == "no_executor_mapping":
                obj["_source_key"] = key
                items.append(obj)
    return items

def write_committee(committee_id, name, mission, task_types=None, source="manual"):
    task_types = task_types or []
    committee_id = slugify(committee_id)

    base = Path("parliament/committees") / committee_id
    base.mkdir(parents=True, exist_ok=True)

    committee = {
        "committee_id": committee_id,
        "name": name,
        "status": "active",
        "source": source,
        "created_at": now_iso(),
        "mission": mission,
        "task_types": task_types,
        "powers": [
            "analyze_tasks",
            "recommend_handlers",
            "write_reports",
            "write_feeds",
            "write_proofs",
            "request_executor_mapping"
        ],
        "limits": [
            "no_private_keys",
            "no_secret_dump",
            "no_illegal_actions",
            "no_real_world_force",
            "internal_digital_committee_only"
        ],
        "outputs": {
            "committee_json": str(base / "committee.json"),
            "readme": str(base / "README.md")
        }
    }

    committee["double_sha"] = dsha(json.dumps(committee, ensure_ascii=False, sort_keys=True))

    (base / "committee.json").write_text(json.dumps(committee, ensure_ascii=False, indent=2))

    readme = f"""# {name}

Status: active  
Committee ID: `{committee_id}`  
Double SHA: `{committee["double_sha"]}`

## Mission

{mission}

## Task types

{chr(10).join("- `" + x + "`" for x in task_types) if task_types else "- none"}

## Powers

- analyze_tasks
- recommend_handlers
- write_reports
- write_feeds
- write_proofs
- request_executor_mapping

## Limits

- no private keys
- no secret dump
- no illegal actions
- internal digital committee only
"""
    (base / "README.md").write_text(readme)

    r.hset(EVO_COMMITTEES, committee_id, json.dumps(committee, ensure_ascii=False))
    r.lpush(EVO_AUDIT, json.dumps({
        "status": "committee_created_or_updated",
        "committee_id": committee_id,
        "name": name,
        "task_types": task_types,
        "source": source,
        "time": time.time(),
        "double_sha": committee["double_sha"]
    }, ensure_ascii=False))

    return committee

def load_all_committees():
    raw = r.hgetall(EVO_COMMITTEES)
    committees = []
    for _, value in raw.items():
        obj = safe_json(value)
        if obj:
            committees.append(obj)
    return sorted(committees, key=lambda x: x.get("committee_id", ""))

def write_report(committees, no_mapping_items):
    Path("feeds").mkdir(exist_ok=True)
    Path("posts").mkdir(exist_ok=True)
    Path("proofs").mkdir(exist_ok=True)

    no_mapping_types = Counter(str(x.get("type")) for x in no_mapping_items)

    report = {
        "module": "CYBRA EVO Committee Module",
        "status": "generated",
        "time": time.time(),
        "time_iso": now_iso(),
        "git": {
            "branch": git_cmd(["git", "branch", "--show-current"]),
            "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"]),
            "dirty_files": len(git_cmd(["git", "status", "--short"]).splitlines())
        },
        "summary": {
            "committees": len(committees),
            "no_mapping_items_seen": len(no_mapping_items),
            "no_mapping_types": dict(no_mapping_types),
            "executor_mapping_count": len(r.hgetall(EXECUTOR_MAPPING))
        },
        "committees": committees,
        "no_mapping_items": no_mapping_items[:50],
        "evo_laws_file": "parliament/evo/evo_laws.json"
    }

    report["double_sha"] = dsha(json.dumps(report, ensure_ascii=False, sort_keys=True))

    Path("feeds/evo_committee_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2)
    )

    committee_lines = ""
    for c in committees:
        committee_lines += f"- **{c.get('name')}** / `{c.get('committee_id')}` — {c.get('mission')}\n"

    no_map_lines = ""
    for t, count in no_mapping_types.items():
        no_map_lines += f"- `{t}`: {count}\n"
    if not no_map_lines:
        no_map_lines = "- none\n"

    md = f"""# CYBRA EVO Committee Module

Status: generated  
Double SHA: `{report["double_sha"]}`

## Summary

- Committees: {report["summary"]["committees"]}
- No mapping items seen: {report["summary"]["no_mapping_items_seen"]}
- Executor mapping count: {report["summary"]["executor_mapping_count"]}

## No mapping types

{no_map_lines}

## Committees

{committee_lines}

## EVO Laws

See: `parliament/evo/evo_laws.json`

## Policy

- internal digital committees only
- no private keys
- no seed phrases
- no illegal actions
- human owner control required
"""

    Path("posts/evo_committee_report.md").write_text(md)

    with open("proofs/evo_committee.sha256", "w") as proof:
        subprocess.run(
            [
                "sha256sum",
                "parliament/evo/evo_laws.json",
                "feeds/evo_committee_report.json",
                "posts/evo_committee_report.md"
            ],
            stdout=proof,
            stderr=subprocess.DEVNULL
        )

    return report

def auto_mode():
    created = []

    for c in CORE_COMMITTEES:
        created.append(write_committee(
            c["committee_id"],
            c["name"],
            c["mission"],
            c.get("task_types", []),
            source="core"
        ))

    no_mapping = detect_no_mapping()

    for item in no_mapping:
        task_type = str(item.get("type", "unknown"))
        meta = DEFAULT_SUPPORT.get(task_type)
        if not meta:
            committee_id = slugify(task_type + "_committee")
            meta = {
                "committee_id": committee_id,
                "name": task_type.replace("_", " ").title() + " Committee",
                "mission": f"Підтримувати задачі типу {task_type}, створювати безпечні handler-и і звіти."
            }

        created.append(write_committee(
            meta["committee_id"],
            meta["name"],
            meta["mission"],
            task_types=[task_type],
            source="no_executor_mapping_scan"
        ))

        safe_support_types = {
            "self_expanding_execution_engine_task",
            "executor_autoheal_task",
            "codespaces_keepalive_task",
            "github_double_backend_task",
            "ai_task",
            "queue_fix",
            "test"
        }

        if task_type in safe_support_types:
            r.hset(EXECUTOR_MAPPING, task_type, "evo_committee_handler.sh")

    r.hset(EXECUTOR_MAPPING, "evo_committee_task", "evo_committee_handler.sh")
    r.hset(EXECUTOR_MAPPING, "committee_creation_task", "evo_committee_handler.sh")

    committees = load_all_committees()
    report = write_report(committees, no_mapping)

    print("✅ CYBRA EVO committees generated")
    print("Committees:", len(committees))
    print("Report: posts/evo_committee_report.md")
    print("Feed: feeds/evo_committee_report.json")
    print("Proof: proofs/evo_committee.sha256")
    print("Double SHA:", report["double_sha"])

def create_mode(args):
    if len(args) < 3:
        raise SystemExit("Usage: python3 cybra_evo_committee_factory.py create <committee_id> <name> <mission> [task_type1,task_type2]")

    committee_id = args[0]
    name = args[1]
    mission = args[2]
    task_types = []
    if len(args) >= 4:
        task_types = [x.strip() for x in args[3].split(",") if x.strip()]

    committee = write_committee(committee_id, name, mission, task_types, source="manual")
    committees = load_all_committees()
    no_mapping = detect_no_mapping()
    write_report(committees, no_mapping)

    print("✅ committee created:", committee["committee_id"])

def main():
    r.ping()
    cmd = sys.argv[1] if len(sys.argv) > 1 else "auto"

    if cmd == "auto":
        auto_mode()
    elif cmd == "create":
        create_mode(sys.argv[2:])
    elif cmd == "report":
        committees = load_all_committees()
        no_mapping = detect_no_mapping()
        report = write_report(committees, no_mapping)
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        raise SystemExit("Usage: auto | create | report")

if __name__ == "__main__":
    main()
PY

chmod +x cybra_evo_committee_factory.py

cat > evo_committee_handler.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"
python3 cybra_evo_committee_factory.py auto
EOF2

chmod +x evo_committee_handler.sh

cat > cybra_evo.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

CMD="${1:-status}"
shift || true

case "$CMD" in
  auto)
    python3 cybra_evo_committee_factory.py auto
    ;;
  create)
    python3 cybra_evo_committee_factory.py create "$@"
    ;;
  task)
    cybra parliament '{"topic":"CYBRA EVO Committee Creation","type":"evo_committee_task","priority":"high","payload":{"mode":"auto_create_support_committees"}}'
    ;;
  status)
    redis-cli ping
    echo "EVO_AUDIT: $(redis-cli LLEN cybra:evo:audit)"
    echo "EVO_COMMITTEES: $(redis-cli HLEN cybra:evo:committees)"
    echo "EXECUTOR_MAPPING: $(redis-cli HLEN cybra:executor:mapping)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    test -f posts/evo_committee_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  list)
    redis-cli HGETALL cybra:evo:committees
    ;;
  report)
    cat posts/evo_committee_report.md
    ;;
  feed)
    cat feeds/evo_committee_report.json
    ;;
  proof)
    cat proofs/evo_committee.sha256
    ;;
  audit)
    redis-cli LRANGE cybra:evo:audit 0 20
    ;;
  laws)
    cat parliament/evo/evo_laws.json
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_evo.sh auto"
    echo "  bash cybra_evo.sh create <committee_id> <name> <mission> [task_type1,task_type2]"
    echo "  bash cybra_evo.sh task"
    echo "  bash cybra_evo.sh status|list|report|feed|proof|audit|laws"
    ;;
esac
EOF2

chmod +x cybra_evo.sh

redis-cli HSET cybra:executor:mapping evo_committee_task evo_committee_handler.sh >/dev/null
redis-cli HSET cybra:executor:mapping committee_creation_task evo_committee_handler.sh >/dev/null

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
s = p.read_text()

if 'r.hget("cybra:executor:mapping", task_type)' not in s:
    old = "script_name = SCRIPT_MAP.get(task_type)"
    new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
    if old in s:
        s = s.replace(old, new, 1)
        print("✅ executor patched for Redis mapping")
    else:
        print("⚠ Redis mapping patch skipped: old script_name line not found")
else:
    print("✅ executor already uses Redis mapping")

insertions = {
    "evo_committee_task": "evo_committee_handler.sh",
    "committee_creation_task": "evo_committee_handler.sh"
}

for task_type, handler in insertions.items():
    marker = f'"{task_type}"'
    if marker not in s:
        i = s.find("SCRIPT_MAP")
        if i < 0:
            raise SystemExit("SCRIPT_MAP not found")
        j = s.find("{", i)
        if j < 0:
            raise SystemExit("SCRIPT_MAP brace not found")
        s = s[:j+1] + f'\n    "{task_type}": "{handler}",' + s[j+1:]
        print(f"✅ static mapping inserted: {task_type} -> {handler}")
    else:
        print(f"✅ static mapping exists: {task_type}")

p.write_text(s)
PY

rm -rf __pycache__
python3 -m py_compile parliament_executor_v6.py
rm -rf __pycache__

bash cybra_evo.sh auto

sha256sum \
  parliament/evo/evo_laws.json \
  cybra_evo_committee_factory.py \
  evo_committee_handler.sh \
  cybra_evo.sh \
  feeds/evo_committee_report.json \
  posts/evo_committee_report.md \
  > proofs/evo_committee_install.sha256

echo
echo "=== EVO STATUS ==="
bash cybra_evo.sh status

echo
echo "=== EVO REPORT PREVIEW ==="
head -100 posts/evo_committee_report.md

echo
echo "=== EVO PARLIAMENT TASK TEST ==="
cybra worker-start || true
bash cybra_evo.sh task

sleep 5

cybra status
cybra results | head -5
bash cybra_evo.sh status

echo
echo "=== CYBRA EVO COMMITTEE MODULE INSTALL DONE ==="
echo "Commit:"
echo "git add install_cybra_evo_committee_module_all.sh cybra_evo_committee_factory.py evo_committee_handler.sh cybra_evo.sh parliament/evo/evo_laws.json parliament/committees posts/evo_committee_report.md feeds/evo_committee_report.json proofs/evo_committee.sha256 proofs/evo_committee_install.sha256 parliament_executor_v6.py"
echo "git commit -m 'add CYBRA EVO committee creation module'"
echo "git push origin main"
