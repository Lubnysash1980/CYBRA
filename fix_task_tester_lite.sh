#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== FIX CYBRA TASK TESTER LITE MODE ==="

mkdir -p data/cybra_task_tests/reports data/cybra_task_tests/tasks posts feeds proofs logs/task_tests runtime/redis

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir "$HOME/CYBRA/runtime/redis" --save "" --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

cat > cybra_task_execution_tester.py <<'PY'
#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
import sys
from pathlib import Path

ROOT = Path.home() / "CYBRA"
AI_INBOX = "cybra:ai:tasks:block_inbox"
PARLIAMENT_QUEUE = "cybra:parliament:queue"
PARLIAMENT_FAILED = "cybra:parliament:failed"
AUDIT = "cybra:task_execution_test:audit"

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(obj):
    text = json.dumps(obj, ensure_ascii=False, sort_keys=True)
    return sha(sha(text))

def run(cmd, timeout=60):
    try:
        p = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True, timeout=timeout)
        return {
            "cmd": " ".join(cmd),
            "ok": p.returncode == 0,
            "code": p.returncode,
            "stdout": p.stdout[-1200:],
            "stderr": p.stderr[-800:]
        }
    except Exception as e:
        return {
            "cmd": " ".join(cmd),
            "ok": False,
            "code": 1,
            "stdout": "",
            "stderr": str(e)
        }

def exists(p):
    return (ROOT / p).exists()

def count(pattern):
    return len(list(ROOT.glob(pattern)))

def redis(args):
    r = run(["redis-cli"] + args, timeout=20)
    return r["code"], r["stdout"].strip(), r["stderr"].strip()

def rlen(key):
    code, out, _ = redis(["LLEN", key])
    return int(out) if code == 0 and out.isdigit() else 0

def hget(key, field):
    code, out, _ = redis(["HGET", key, field])
    return out if code == 0 else ""

def rpush(key, obj):
    redis(["LPUSH", key, json.dumps(obj, ensure_ascii=False)])

def ensure_redis():
    code, out, _ = redis(["ping"])
    if out == "PONG":
        return True
    (ROOT / "runtime/redis").mkdir(parents=True, exist_ok=True)
    subprocess.run([
        "redis-server",
        "--daemonize", "yes",
        "--bind", "127.0.0.1",
        "--port", "6379",
        "--dir", str(ROOT / "runtime/redis"),
        "--save", "",
        "--appendonly", "no"
    ], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1)
    code, out, _ = redis(["ping"])
    return out == "PONG"

def save_json(path, obj):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

def load_json(path):
    p = ROOT / path
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return {}

def task_map():
    return {
        "menubar_owner_task": {
            "handler": "cybra_menubar_handler.sh",
            "script": "cybra_menubar.sh",
            "safe_cmd": ["bash", "cybra_menubar.sh", "report"],
            "report": "posts/cybra_menubar_report.md"
        },
        "it_evolution_task": {
            "handler": "cybra_it_evolution_handler.sh",
            "script": "cybra_it_evolution.sh",
            "safe_cmd": ["bash", "cybra_it_evolution.sh", "report"],
            "report": "posts/cybra_it_evolution_report.md"
        },
        "codespace_runtime_committee_task": {
            "handler": "cybra_codespace_runtime_handler.sh",
            "script": "cybra_codespace_runtime.sh",
            "safe_cmd": ["bash", "cybra_codespace_runtime.sh", "status"],
            "report": "posts/cybra_codespace_runtime_report.md"
        },
        "frozen_license_committee_task": {
            "handler": "cybra_frozen_committee_handler.sh",
            "script": "cybra_frozen_committee.sh",
            "safe_cmd": ["bash", "cybra_frozen_committee.sh", "report"],
            "report": "posts/frozen_license_committee_report.md"
        },
        "hash_license_violation_audit_task": {
            "handler": "hash_license_guard_handler.sh",
            "script": "hash_license_guard.sh",
            "safe_cmd": ["bash", "hash_license_guard.sh", "report"],
            "report": "posts/hash_license_guard_report.md"
        },
        "evolution_tracker_task": {
            "handler": "cybra_evolution.sh",
            "script": "cybra_evolution.sh",
            "safe_cmd": ["bash", "cybra_evolution.sh", "status"],
            "report": "posts/cybra_evolution_today.md"
        }
    }

def build_report(mode="lite", command_results=None):
    ensure_redis()

    results = {}
    for task_type, meta in task_map().items():
        mapped = hget("cybra:executor:mapping", task_type)
        handler_exists = exists(meta["handler"]) or (mapped and exists(mapped))
        script_exists = exists(meta["script"])
        report_exists = exists(meta["report"])

        if handler_exists and script_exists and report_exists:
            status = "EXECUTED_PREVIOUSLY_AND_READY"
        elif handler_exists and script_exists:
            status = "WILL_EXECUTE"
        elif script_exists:
            status = "SCRIPT_EXISTS_BUT_HANDLER_MISSING"
        else:
            status = "MISSING"

        results[task_type] = {
            "status": status,
            "handler": meta["handler"],
            "redis_mapped_handler": mapped or "none",
            "handler_exists": bool(handler_exists),
            "script": meta["script"],
            "script_exists": bool(script_exists),
            "report": meta["report"],
            "report_exists": bool(report_exists)
        }

    summary = {
        "executed_previously_and_ready": len([x for x in results.values() if x["status"] == "EXECUTED_PREVIOUSLY_AND_READY"]),
        "will_execute": len([x for x in results.values() if x["status"] == "WILL_EXECUTE"]),
        "handler_missing": len([x for x in results.values() if x["status"] == "SCRIPT_EXISTS_BUT_HANDLER_MISSING"]),
        "missing": len([x for x in results.values() if x["status"] == "MISSING"])
    }

    obj = {
        "status": "task_execution_lite_report",
        "mode": mode,
        "time": time.time(),
        "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "summary": summary,
        "tasks": results,
        "queues": {
            "ai_block_inbox": rlen(AI_INBOX),
            "parliament_queue": rlen(PARLIAMENT_QUEUE),
            "parliament_failed": rlen(PARLIAMENT_FAILED),
            "task_blocks": count("blockchain/kibra_chain/task_blocks/*.json")
        },
        "command_results": command_results or [],
        "safety": {
            "heavy_cycles_auto_run": False,
            "real_payment_now": False,
            "automatic_SWIFT": False,
            "automatic_external_tx": False,
            "private_key_required": False,
            "seed_phrase_required": False,
            "manual_OWNER_approval_required": True
        }
    }

    obj["overall_status"] = "OK" if summary["missing"] == 0 else "NEEDS_ATTENTION"
    obj["double_sha"] = dsha(obj)

    save_json("feeds/cybra_task_execution_test_report.json", obj)
    save_json("data/cybra_task_tests/reports/latest_report.json", obj)

    lines = []
    lines.append("# CYBRA Task Execution Lite Test Report")
    lines.append("")
    lines.append(f"Overall status: {obj['overall_status']}")
    lines.append(f"Mode: {mode}")
    lines.append("")
    lines.append("## Summary")
    for k, v in summary.items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Queues")
    for k, v in obj["queues"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Task readiness")
    for task_type, item in results.items():
        lines.append("")
        lines.append(f"### {task_type}")
        lines.append(f"Status: {item['status']}")
        lines.append(f"Handler exists: {item['handler_exists']}")
        lines.append(f"Script exists: {item['script_exists']}")
        lines.append(f"Report exists: {item['report_exists']}")
        lines.append(f"Redis mapped handler: {item['redis_mapped_handler']}")
    lines.append("")
    lines.append("## Meaning")
    lines.append("- EXECUTED_PREVIOUSLY_AND_READY: report exists, script exists, handler exists.")
    lines.append("- WILL_EXECUTE: script/handler exists, report will be created on cycle.")
    lines.append("- SCRIPT_EXISTS_BUT_HANDLER_MISSING: script exists, but executor mapping/handler missing.")
    lines.append("- MISSING: script/module missing.")
    lines.append("")
    lines.append("## Safety")
    for k, v in obj["safety"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Double SHA")
    lines.append(obj["double_sha"])

    (ROOT / "posts/cybra_task_execution_test_report.md").write_text("\n".join(lines), encoding="utf-8")

    with (ROOT / "proofs/cybra_task_execution_test.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "feeds/cybra_task_execution_test_report.json",
            "posts/cybra_task_execution_test_report.md",
            "data/cybra_task_tests/reports/latest_report.json"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    rpush(AUDIT, {
        "status": "task_execution_lite_report",
        "overall_status": obj["overall_status"],
        "double_sha": obj["double_sha"],
        "time": obj["time"]
    })

    return obj

def queue_test():
    ensure_redis()
    task = {
        "topic": "CYBRA queue execution test",
        "type": "menubar_owner_task",
        "priority": "test",
        "source": "cybra_task_execution_tester_lite",
        "payload": {
            "test": True,
            "real_payment_now": False,
            "automatic_SWIFT": False,
            "automatic_external_tx": False,
            "manual_OWNER_approval_required": True
        },
        "time": time.time(),
        "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z")
    }
    task["double_sha"] = dsha(task)
    save_json(f"data/cybra_task_tests/tasks/{task['double_sha'][:16]}_queue_test.json", task)
    before = rlen(AI_INBOX)
    rpush(AI_INBOX, task)
    after = rlen(AI_INBOX)
    obj = build_report("queue-test")
    print("✅ Queue test submitted")
    print("AI_INBOX_BEFORE:", before)
    print("AI_INBOX_AFTER:", after)
    print("TASK_SHA:", task["double_sha"])
    print("REPORT: posts/cybra_task_execution_test_report.md")

def run_one(name):
    ensure_redis()
    aliases = {
        "menubar": "menubar_owner_task",
        "it": "it_evolution_task",
        "runtime": "codespace_runtime_committee_task",
        "frozen": "frozen_license_committee_task",
        "hash": "hash_license_violation_audit_task",
        "evolution": "evolution_tracker_task"
    }
    task_type = aliases.get(name, name)
    meta = task_map().get(task_type)
    if not meta:
        print("Unknown task/module:", name)
        print("Available:", ", ".join(aliases.keys()))
        return

    if not exists(meta["script"]):
        print("MISSING SCRIPT:", meta["script"])
        build_report("run-one-missing")
        return

    print("RUN SAFE COMMAND:", " ".join(meta["safe_cmd"]))
    res = run(meta["safe_cmd"], timeout=90)
    obj = build_report("run-one-" + name, [res])
    print("CODE:", res["code"])
    print("OK:", res["ok"])
    if res["stdout"]:
        print(res["stdout"])
    if res["stderr"]:
        print(res["stderr"])
    print("REPORT:", "posts/cybra_task_execution_test_report.md")
    print("OVERALL:", obj["overall_status"])

def status():
    rep = load_json("data/cybra_task_tests/reports/latest_report.json")
    if not rep:
        print("No task test report yet. Run: cybra-task-test run")
        return
    print("CYBRA_TASK_EXECUTION_TESTER_LITE: active")
    print("OVERALL:", rep.get("overall_status"))
    print("MODE:", rep.get("mode"))
    print("READY:", rep.get("summary", {}).get("executed_previously_and_ready"))
    print("WILL_EXECUTE:", rep.get("summary", {}).get("will_execute"))
    print("HANDLER_MISSING:", rep.get("summary", {}).get("handler_missing"))
    print("MISSING:", rep.get("summary", {}).get("missing"))
    print("AI_INBOX:", rep.get("queues", {}).get("ai_block_inbox"))
    print("PARLIAMENT_FAILED:", rep.get("queues", {}).get("parliament_failed"))
    print("TASK_BLOCKS:", rep.get("queues", {}).get("task_blocks"))

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd in ["run", "lite", "test"]:
        obj = build_report("lite")
        print("✅ Lite task execution test completed")
        print("OVERALL:", obj["overall_status"])
        print("READY:", obj["summary"]["executed_previously_and_ready"])
        print("WILL_EXECUTE:", obj["summary"]["will_execute"])
        print("MISSING:", obj["summary"]["missing"])
        print("REPORT: posts/cybra_task_execution_test_report.md")
    elif cmd == "queue":
        queue_test()
    elif cmd == "one":
        run_one(sys.argv[2] if len(sys.argv) > 2 else "menubar")
    elif cmd == "status":
        status()
    else:
        print("Usage: status|run|lite|queue|one MODULE")
        print("MODULE: menubar|it|runtime|frozen|hash|evolution")

if __name__ == "__main__":
    main()
PY

cat > cybra_task_test.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

case "${1:-status}" in
  status|run|lite|test|queue)
    python3 cybra_task_execution_tester.py "$1"
    ;;
  one)
    python3 cybra_task_execution_tester.py one "${2:-menubar}"
    ;;
  report)
    cat posts/cybra_task_execution_test_report.md
    ;;
  proof)
    cat proofs/cybra_task_execution_test.sha256
    ;;
  *)
    echo "Usage:"
    echo "  cybra-task-test status"
    echo "  cybra-task-test run"
    echo "  cybra-task-test queue"
    echo "  cybra-task-test one menubar"
    echo "  cybra-task-test one it"
    echo "  cybra-task-test report"
    ;;
esac
EOF

chmod +x cybra_task_execution_tester.py cybra_task_test.sh
ln -sf "$HOME/CYBRA/cybra_task_test.sh" "$PREFIX/bin/cybra-task-test" 2>/dev/null || true

python3 -m py_compile cybra_task_execution_tester.py
rm -rf __pycache__ 2>/dev/null || true

echo
echo "=== RUN SAFE LITE TEST ==="
bash cybra_task_test.sh run

echo
echo "=== STATUS ==="
bash cybra_task_test.sh status

echo
echo "✅ TASK TESTER LITE FIXED"
echo "Commands:"
echo "  cybra-task-test run"
echo "  cybra-task-test queue"
echo "  cybra-task-test one menubar"
echo "  cybra-task-test report"
