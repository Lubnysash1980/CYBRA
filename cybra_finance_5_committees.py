#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"

AUDIT = "cybra:finance:5_committees:audit"
AI_BLOCK_INBOX = "cybra:ai:tasks:block_inbox"
PARLIAMENT_QUEUE = "cybra:parliament:queue"

def sha(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def dsha(text):
    return sha(sha(text))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def run(cmd):
    try:
        p = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
        return p.returncode, p.stdout.strip(), p.stderr.strip()
    except Exception as e:
        return 1, "", str(e)

def redis_lpush(key, obj):
    run(["redis-cli", "LPUSH", key, json.dumps(obj, ensure_ascii=False)])

def redis_hset(key, field, value):
    run(["redis-cli", "HSET", key, field, value])

def redis_len(key):
    code, out, err = run(["redis-cli", "LLEN", key])
    if code == 0 and out.strip().isdigit():
        return int(out.strip())
    return 0

def save_json(path, obj):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

def load_json(path, default=None):
    p = ROOT / path
    if not p.exists():
        return default if default is not None else {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return default if default is not None else {}

def file_sha(path):
    p = ROOT / path
    if not p.exists():
        return None
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def git_cmd(cmd):
    code, out, err = run(cmd)
    return out if code == 0 else ""

COMMITTEES = [
    {
        "id": "finance_finder_committee",
        "name": "Комітет-Шукач",
        "role": "finder",
        "mission": "Шукати, яких модулів, реквізитів, proof, SWIFT/Bank/PSP адаптерів, cold-wallet записів і процедур не вистачає.",
        "tasks": [
            "scan_missing_finance_modules",
            "scan_missing_payment_requisites",
            "scan_missing_swift_bank_psp_templates",
            "scan_missing_cold_wallets",
            "scan_missing_price_liquidity_proofs"
        ]
    },
    {
        "id": "finance_teacher_committee",
        "name": "Комітет-Навчач",
        "role": "teacher",
        "mission": "Створювати правила, інструкції, політики безпечної роботи фінансової системи.",
        "tasks": [
            "create_user_instructions",
            "create_safe_payment_policy",
            "create_no_private_key_policy",
            "create_swift_bank_psp_training",
            "create_owner_approval_policy"
        ]
    },
    {
        "id": "finance_worker_committee",
        "name": "Комітет-Воркер",
        "role": "worker",
        "mission": "Виконувати роботу через бінарник cybra-finance-bin і допоміжні модулі.",
        "tasks": [
            "run_cybra_finance_bin_report",
            "create_payment_proposals",
            "create_swift_bank_drafts",
            "update_cold_wallet_registry",
            "update_finance_reports"
        ]
    },
    {
        "id": "finance_parliament_task_committee",
        "name": "Комітет Завдань Кіберпарламенту",
        "role": "parliament_tasker",
        "mission": "Формувати AI-завдання для Кіберпарламенту і передавати їх через mining blocks.",
        "tasks": [
            "create_ai_tasks",
            "send_to_block_inbox",
            "send_to_closed_sha_bridge",
            "send_to_pool_mining",
            "track_parliament_results"
        ]
    },
    {
        "id": "finance_tester_committee",
        "name": "Комітет-Тестер",
        "role": "tester",
        "mission": "Тестувати фінансовий модуль під екосистему власника: status, proof, queues, reports, бінарник, безпечність.",
        "tasks": [
            "test_binary_compile",
            "test_redis_queues",
            "test_payment_proposal_flow",
            "test_no_private_keys",
            "test_no_automatic_real_payment",
            "test_sha_proofs"
        ]
    }
]

def current_state():
    return {
        "time": time.time(),
        "time_iso": now_iso(),
        "binary_exists": (ROOT / "bin/cybra-finance-bin").exists(),
        "binary_global_exists": Path(str(Path.home()) + "/../usr/bin/cybra-finance-bin").exists(),
        "cold_finance_report_exists": (ROOT / "feeds/cybra_cold_finance_binary_report.json").exists(),
        "cold_payment_requisites_exists": (ROOT / "posts/cybra_cold_payment_requisites.txt").exists(),
        "kybra_valid_exists": (ROOT / "kybra_valid_gateway.py").exists(),
        "payment_requisites_exists": (ROOT / "feeds/cybra_payment_requisites_package.json").exists(),
        "redis_ping": run(["redis-cli", "ping"])[1] == "PONG",
        "queues": {
            "block_inbox": redis_len(AI_BLOCK_INBOX),
            "parliament_queue": redis_len(PARLIAMENT_QUEUE),
            "parliament_failed": redis_len("cybra:parliament:failed"),
            "task_block_mempool": redis_len("cybra:kibra:task_blocks:mempool"),
            "pool_mining_blocks": redis_len("cybra:kibra:pool:mining_blocks"),
            "task_blocks_mined": redis_len("cybra:kibra:task_blocks:mined")
        },
        "proofs": {
            "cold_finance": file_sha("proofs/cybra_cold_finance_binary.sha256"),
            "payment_requisites": file_sha("proofs/cybra_payment_requisites_package.sha256"),
            "kybra_valid": file_sha("proofs/kybra_valid_wallet_gateway.sha256"),
            "redis_committee": file_sha("proofs/finance_redis_committee.sha256")
        },
        "git": {
            "branch": git_cmd(["git", "branch", "--show-current"]),
            "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"]),
            "dirty_files": len(git_cmd(["git", "status", "--short"]).splitlines())
        }
    }

def create_committees():
    state = current_state()

    for c in COMMITTEES:
        obj = {
            "committee_id": c["id"],
            "name": c["name"],
            "role": c["role"],
            "parent_department": "cybra_cold_finance_binary_department",
            "status": "active",
            "mission": c["mission"],
            "assigned_tasks": c["tasks"],
            "target_system": "CYBRA Cold Finance Binary System",
            "target_binary": "bin/cybra-finance-bin",
            "ai_task_flow": [
                "committee_task",
                "cybra:ai:tasks:block_inbox",
                "task_block",
                "closed_sha_bridge",
                "pool_mining",
                "AI Parliament result"
            ],
            "safety": {
                "private_keys": False,
                "seed_phrase": False,
                "automatic_swift_payment": False,
                "automatic_external_crypto_tx": False,
                "automatic_real_payment": False,
                "manual_OWNER_approval_required": True
            },
            "created_at": time.time(),
            "created_at_iso": now_iso()
        }
        obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))

        save_json(f"parliament/departments/finance_department/cybra_cold_finance_binary_department/committees/{c['id']}/committee.json", obj)
        save_json(f"parliament/departments/cybra_finance_department/cybra_cold_finance_binary_department/committees/{c['id']}/committee.json", obj)
        save_json(f"data/cybra_cold_finance/committees/{c['id']}.json", obj)

    return state

def build_ai_tasks(state):
    tasks = []

    for c in COMMITTEES:
        task = {
            "topic": f"CYBRA Finance Committee: {c['name']}",
            "type": "cybra_finance_5_committees_task",
            "priority": "critical",
            "payload": {
                "source": "cybra_finance_5_committees",
                "committee_id": c["id"],
                "committee_name": c["name"],
                "role": c["role"],
                "mission": c["mission"],
                "assigned_tasks": c["tasks"],
                "target_binary": "bin/cybra-finance-bin",
                "state_snapshot": state,
                "convert_to_mining_block_first": True,
                "send_to_pool_mining": True,
                "real_payment_now": False,
                "automatic_external_tx": False,
                "automatic_swift": False,
                "manual_OWNER_approval_required": True
            }
        }
        task["double_sha"] = dsha(json.dumps(task, ensure_ascii=False, sort_keys=True))
        tasks.append(task)

    master = {
        "topic": "CYBRA Finance System rebuild by 5 committees",
        "type": "cybra_cold_finance_binary_task",
        "priority": "critical",
        "payload": {
            "source": "cybra_finance_5_committees",
            "goal": "Five committees rebuild, teach, work, task and test the cold finance binary system for owner ecosystem.",
            "committees": [c["id"] for c in COMMITTEES],
            "target_binary": "bin/cybra-finance-bin",
            "convert_to_mining_block_first": True,
            "send_to_pool_mining": True,
            "real_payment_now": False,
            "automatic_external_tx": False,
            "manual_OWNER_approval_required": True
        }
    }
    master["double_sha"] = dsha(json.dumps(master, ensure_ascii=False, sort_keys=True))
    tasks.append(master)

    return tasks

def submit_ai():
    state = create_committees()
    tasks = build_ai_tasks(state)

    for task in tasks:
        redis_lpush(AI_BLOCK_INBOX, task)

    redis_lpush(AUDIT, {
        "status": "finance_5_committees_ai_tasks_submitted",
        "tasks": len(tasks),
        "time": time.time(),
        "time_iso": now_iso()
    })

    print("✅ AI tasks submitted to block inbox")
    print("TASKS:", len(tasks))

def report():
    state = create_committees()
    tasks = build_ai_tasks(state)

    package = {
        "status": "cybra_finance_5_committees_report_generated",
        "time": time.time(),
        "time_iso": now_iso(),
        "committees": COMMITTEES,
        "state": state,
        "ai_tasks_prepared": len(tasks),
        "target_system": "CYBRA Cold Finance Binary System",
        "target_binary": "bin/cybra-finance-bin",
        "flow": [
            "committee",
            "AI task",
            "block inbox",
            "task-block",
            "closed SHA bridge",
            "pool mining",
            "AI Parliament",
            "report/proof"
        ],
        "safety": {
            "private_keys": False,
            "seed_phrase": False,
            "automatic_SWIFT": False,
            "automatic_external_tx": False,
            "automatic_real_payment": False,
            "manual_OWNER_approval_required": True
        }
    }
    package["double_sha"] = dsha(json.dumps(package, ensure_ascii=False, sort_keys=True))

    save_json("feeds/cybra_finance_5_committees_report.json", package)
    save_json("data/cybra_cold_finance/committees/latest_report.json", package)

    lines = []
    lines.append("# CYBRA Finance 5 Committees")
    lines.append("")
    lines.append("Status: active")
    lines.append("")
    lines.append("## Committees")
    lines.append("")
    for c in COMMITTEES:
        lines.append(f"- {c['name']} / {c['role']}: {c['mission']}")
    lines.append("")
    lines.append("## Target")
    lines.append("")
    lines.append("System: CYBRA Cold Finance Binary System")
    lines.append("Binary: bin/cybra-finance-bin")
    lines.append("")
    lines.append("## Current state")
    lines.append("")
    lines.append(f"Binary exists: {state['binary_exists']}")
    lines.append(f"Cold finance report exists: {state['cold_finance_report_exists']}")
    lines.append(f"Payment requisites exists: {state['payment_requisites_exists']}")
    lines.append(f"KYBRA valid exists: {state['kybra_valid_exists']}")
    lines.append(f"Redis ping: {state['redis_ping']}")
    lines.append("")
    lines.append("## Queues")
    lines.append("")
    for k, v in state["queues"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Rules")
    lines.append("")
    lines.append("No private keys.")
    lines.append("No seed phrase.")
    lines.append("No automatic SWIFT.")
    lines.append("No automatic external crypto transaction.")
    lines.append("No automatic real payment.")
    lines.append("All AI tasks go to mining blocks.")
    lines.append("OWNER approval required.")
    lines.append("")
    lines.append("## Double SHA")
    lines.append("")
    lines.append(package["double_sha"])

    (ROOT / "posts/cybra_finance_5_committees_report.md").write_text("\n".join(lines), encoding="utf-8")

    with (ROOT / "proofs/cybra_finance_5_committees.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "feeds/cybra_finance_5_committees_report.json",
            "posts/cybra_finance_5_committees_report.md",
            "data/cybra_cold_finance/committees/latest_report.json"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    redis_lpush(AUDIT, {
        "status": "finance_5_committees_report_generated",
        "committees": 5,
        "ai_tasks_prepared": len(tasks),
        "double_sha": package["double_sha"],
        "time": package["time"]
    })

    print("✅ CYBRA Finance 5 Committees report generated")
    print("COMMITTEES: 5")
    print("AI_TASKS_PREPARED:", len(tasks))
    print("REPORT: posts/cybra_finance_5_committees_report.md")
    print("PROOF: proofs/cybra_finance_5_committees.sha256")

def status():
    state = current_state()
    print("COMMITTEES: 5")
    print("BINARY_EXISTS:", state["binary_exists"])
    print("COLD_FINANCE_REPORT:", state["cold_finance_report_exists"])
    print("REDIS:", state["redis_ping"])
    print("BLOCK_INBOX:", state["queues"]["block_inbox"])
    print("TASK_BLOCK_MEMPOOL:", state["queues"]["task_block_mempool"])
    print("POOL_MINING_BLOCKS:", state["queues"]["pool_mining_blocks"])
    print("PARLIAMENT_QUEUE:", state["queues"]["parliament_queue"])
    print("PARLIAMENT_FAILED:", state["queues"]["parliament_failed"])
    print("AUDIT:", redis_len(AUDIT))

def cycle():
    report()
    submit_ai()

    if (ROOT / "bin/cybra-finance-bin").exists():
        subprocess.run(["bin/cybra-finance-bin", "report"], cwd=ROOT)

    if (ROOT / "cybra_closed_sha_bridge.sh").exists():
        subprocess.run(["bash", "cybra_closed_sha_bridge.sh", "cycle"], cwd=ROOT)
    elif (ROOT / "cybra_ai_block_enforcer.sh").exists():
        subprocess.run(["bash", "cybra_ai_block_enforcer.sh", "enforce", "3"], cwd=ROOT)

    report()
    status()

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "create":
        create_committees()
        report()
    elif cmd == "report":
        report()
    elif cmd == "submit-ai":
        submit_ai()
    elif cmd == "cycle":
        cycle()
    elif cmd == "status":
        status()
    else:
        raise SystemExit("Usage: create|report|submit-ai|cycle|status")

if __name__ == "__main__":
    main()
