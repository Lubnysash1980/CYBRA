#!/usr/bin/env python3
import json, time, hashlib, subprocess, sys, os
from pathlib import Path

ROOT = Path.home() / "CYBRA"
AI_INBOX = "cybra:ai:tasks:block_inbox"
AUDIT = "cybra:it_evolution:audit"
REGISTRY = ROOT / "data/cybra_it_evolution/registry/scripts.json"

def sha(x): return hashlib.sha256(x.encode("utf-8")).hexdigest()
def dsha(o): return sha(sha(json.dumps(o, ensure_ascii=False, sort_keys=True)))
def now(): return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def run(cmd, timeout=180):
    try:
        p = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True, timeout=timeout)
        return p.returncode, p.stdout.strip(), p.stderr.strip()
    except Exception as e:
        return 1, "", str(e)

def rpush(key, obj):
    run(["redis-cli", "LPUSH", key, json.dumps(obj, ensure_ascii=False)], 20)

def rlen(key):
    code, out, _ = run(["redis-cli", "LLEN", key], 20)
    return int(out) if code == 0 and out.strip().isdigit() else 0

def exists(p): return (ROOT / p).exists()
def count(pattern): return len(list(ROOT.glob(pattern)))

def load_json(path, default=None):
    p = ROOT / path if isinstance(path, str) else path
    if not p.exists(): return default if default is not None else {}
    try: return json.loads(p.read_text(encoding="utf-8"))
    except Exception: return default if default is not None else {}

def save_json(path, obj):
    p = ROOT / path if isinstance(path, str) else path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

def ensure_redis():
    code, out, _ = run(["redis-cli", "ping"], 20)
    if code == 0 and out == "PONG": return True
    (ROOT / "runtime/redis").mkdir(parents=True, exist_ok=True)
    run(["redis-server", "--daemonize", "yes", "--bind", "127.0.0.1", "--port", "6379", "--dir", str(ROOT/"runtime/redis"), "--save", "", "--appendonly", "no"], 30)
    time.sleep(1)
    code, out, _ = run(["redis-cli", "ping"], 20)
    return code == 0 and out == "PONG"

def default_registry():
    return {
        "safe": {
            "menubar": {"path": "cybra_menubar.sh", "cmd": ["bash", "cybra_menubar.sh", "status"]},
            "evolution": {"path": "cybra_evolution.sh", "cmd": ["bash", "cybra_evolution.sh", "today"]},
            "autoheal": {"path": "cybra_autoheal.sh", "cmd": ["bash", "cybra_autoheal.sh", "cycle"]},
            "security": {"path": "cybra_security_analytics.sh", "cmd": ["bash", "cybra_security_analytics.sh", "cycle"]},
            "conformation": {"path": "cybra_conformation8.sh", "cmd": ["bash", "cybra_conformation8.sh", "cycle"]},
            "recovery": {"path": "cybra_menu_recovery_bridge.sh", "cmd": ["bash", "cybra_menu_recovery_bridge.sh", "cycle"]},
            "dashboard": {"path": "cybra_dashboard.sh", "cmd": ["bash", "cybra_dashboard.sh", "report"]},
            "codespace": {"path": "cybra_codespace_runtime.sh", "cmd": ["bash", "cybra_codespace_runtime.sh", "cycle", "it-evolution"]},
            "ai_blocks": {"path": "cybra_ai_blocks.sh", "cmd": ["bash", "cybra_ai_blocks.sh", "until-done"]},
            "promo": {"path": "cybra_mint_promo.sh", "cmd": ["bash", "cybra_mint_promo.sh", "report"]}
        }
    }

def registry():
    if not REGISTRY.exists():
        save_json(REGISTRY, default_registry())
    return load_json(REGISTRY, default_registry())

def register_script(name, path, command):
    reg = registry()
    reg.setdefault("safe", {})
    reg["safe"][name] = {"path": path, "cmd": command}
    save_json(REGISTRY, reg)
    print("✅ registered:", name, "->", " ".join(command))

def safe_clean():
    removed = []
    for pattern in ["**/__pycache__", ".pytest_cache"]:
        for p in ROOT.glob(pattern):
            if p.is_dir():
                subprocess.run(["rm", "-rf", str(p)])
                removed.append(str(p.relative_to(ROOT)))
    obj = {"status": "safe_clean_completed", "removed": removed, "time": time.time(), "time_iso": now()}
    obj["double_sha"] = dsha(obj)
    save_json("data/cybra_it_evolution/reports/latest_cleanup.json", obj)
    print("✅ safe cleanup done")
    print("Removed:", len(removed))

def submit_task(text):
    task = {
        "topic": "CYBRA IT Evolution Task",
        "type": "it_evolution_task",
        "priority": "normal",
        "source": "it_department",
        "payload": {
            "text": text,
            "workflow": "analysis -> script -> test -> report -> proof -> task-block",
            "convert_to_mining_block_first": True,
            "send_to_pool_mining": True,
            "real_payment_now": False,
            "automatic_SWIFT": False,
            "automatic_external_tx": False,
            "manual_OWNER_approval_required": True
        },
        "time": time.time(),
        "time_iso": now()
    }
    task["double_sha"] = dsha(task)
    save_json(f"data/cybra_it_evolution/tasks/task_{task['double_sha'][:16]}.json", task)
    rpush(AI_INBOX, task)
    rpush(AUDIT, {"status": "task_submitted", "sha": task["double_sha"], "time": time.time()})
    print("✅ IT task submitted")
    print("DOUBLE_SHA:", task["double_sha"])

def run_registered(name):
    reg = registry().get("safe", {})
    if name not in reg:
        print("❌ no such safe command:", name)
        return
    item = reg[name]
    if not exists(item["path"]):
        print("❌ missing script:", item["path"])
        return
    code, out, err = run(item["cmd"], 240)
    print("CMD:", " ".join(item["cmd"]))
    print("CODE:", code)
    if out: print(out[-2000:])
    if err: print(err[-1000:])

def build_bin():
    path = ROOT / "bin/cybra-evolution-bin"
    path.write_text("""#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1
python3 cybra_it_evolution.py "$@"
""", encoding="utf-8")
    path.chmod(0o755)
    print("✅ binary dispatcher:", path)

def daily_plan():
    main_blocks = count("blockchain/kibra_chain/blocks/block_*.json")
    task_blocks = count("blockchain/kibra_chain/task_blocks/*.json")
    payment = load_json("feeds/cybra_payment_requisites_package.json", {})
    market = load_json("feeds/kibra_real_market_price_gate.json", {})
    payment_ready = bool(payment.get("validation", {}).get("ready", False))
    market_ready = bool(market.get("real_market_confirmed", False))

    tasks = [
        "Run evolution snapshot and compare daily delta.",
        "Run safe cycles: AutoHeal, Security, Conformation8.",
        "Convert all new AI tasks into task-blocks.",
        "Refresh Menu-Bar report and Dashboard report.",
        "Check Recovery pack and proof."
    ]
    if not payment_ready:
        tasks.append("Close payment blocker: add real IBAN or PSP provider.")
    if not market_ready:
        tasks.append("Close market blocker: add real KIBRA market proof from pool/orderbook/provider.")

    obj = {
        "status": "daily_evolution_plan_generated",
        "date": time.strftime("%Y-%m-%d"),
        "time": time.time(),
        "time_iso": now(),
        "main_blocks": main_blocks,
        "task_blocks": task_blocks,
        "estimated_kibra": (main_blocks + task_blocks) * 100,
        "daily_tasks": tasks,
        "target": {
            "minimum_daily_progress_percent": 1,
            "minimum_new_task_blocks": 1,
            "minimum_reports_refreshed": 3
        },
        "blockers": {
            "payment_ready": payment_ready,
            "market_ready": market_ready
        },
        "safety": {
            "real_payment_now": False,
            "automatic_SWIFT": False,
            "automatic_external_tx": False
        }
    }
    obj["double_sha"] = dsha(obj)
    save_json("feeds/cybra_daily_evolution_plan.json", obj)
    save_json("data/cybra_it_evolution/plans/latest_daily_plan.json", obj)

    md = ["# CYBRA Daily Evolution Plan", "", f"Date: {obj['date']}", f"Estimated KIBRA: {obj['estimated_kibra']}", ""]
    md.append("## Tasks")
    for t in tasks: md.append("- " + t)
    md.append("")
    md.append("## Target")
    for k,v in obj["target"].items(): md.append(f"{k}: {v}")
    md.append("")
    md.append("## Blockers")
    for k,v in obj["blockers"].items(): md.append(f"{k}: {v}")
    md.append("")
    md.append("## Double SHA")
    md.append(obj["double_sha"])
    (ROOT/"posts/cybra_daily_evolution_plan.md").write_text("\n".join(md), encoding="utf-8")
    print("✅ daily evolution plan generated")
    print("REPORT: posts/cybra_daily_evolution_plan.md")

def watchdog_once():
    ensure_redis()
    results = []
    for name in ["evolution", "autoheal", "security", "conformation", "recovery", "dashboard", "ai_blocks"]:
        reg = registry().get("safe", {})
        if name not in reg or not exists(reg[name]["path"]):
            results.append({"name": name, "ok": False, "missing": True})
            continue
        code, out, err = run(reg[name]["cmd"], 240)
        results.append({"name": name, "ok": code == 0, "code": code})
    obj = {"status": "watchdog_once_completed", "time": time.time(), "time_iso": now(), "results": results}
    obj["double_sha"] = dsha(obj)
    save_json("feeds/cybra_it_watchdog_report.json", obj)
    save_json("data/cybra_it_evolution/watchdog/latest_watchdog.json", obj)
    print("✅ watchdog once completed")
    for r in results: print(r)

def report():
    reg = registry()
    modules = {
        "evolution_committee": exists("parliament/committees/evolution_committee/committee.json"),
        "evolution_binary_subcommittee": exists("parliament/committees/evolution_committee/subcommittees/evolution_binary_subcommittee/committee.json"),
        "it_department": exists("parliament/committees/it_department/committee.json"),
        "runtime_continuity": exists("parliament/committees/runtime_continuity_subcommittee/committee.json"),
        "binary_dispatcher": exists("bin/cybra-evolution-bin"),
        "menubar": exists("cybra_menubar.sh"),
        "evolution_tracker": exists("cybra_evolution.sh")
    }
    obj = {
        "status": "it_evolution_department_report",
        "time": time.time(),
        "time_iso": now(),
        "modules": modules,
        "registered_safe_commands": list(reg.get("safe", {}).keys()),
        "queues": {
            "ai_block_inbox": rlen(AI_INBOX),
            "it_audit": rlen(AUDIT),
            "parliament_failed": rlen("cybra:parliament:failed")
        },
        "safety": {
            "real_payment_now": False,
            "automatic_SWIFT": False,
            "automatic_external_tx": False,
            "manual_OWNER_approval_required": True
        }
    }
    obj["double_sha"] = dsha(obj)
    save_json("feeds/cybra_it_evolution_report.json", obj)
    save_json("data/cybra_it_evolution/reports/latest_report.json", obj)

    md = ["# CYBRA IT + Evolution Department Report", "", "Status: generated", "", "## Modules"]
    for k,v in modules.items(): md.append(f"{k}: {v}")
    md.append("")
    md.append("## Registered safe commands")
    for x in obj["registered_safe_commands"]: md.append("- " + x)
    md.append("")
    md.append("## Queues")
    for k,v in obj["queues"].items(): md.append(f"{k}: {v}")
    md.append("")
    md.append("## Safety")
    for k,v in obj["safety"].items(): md.append(f"{k}: {v}")
    md.append("")
    md.append("## Double SHA")
    md.append(obj["double_sha"])
    (ROOT/"posts/cybra_it_evolution_report.md").write_text("\n".join(md), encoding="utf-8")

    with (ROOT/"proofs/cybra_it_evolution.sha256").open("w") as f:
        subprocess.run(["sha256sum", "feeds/cybra_it_evolution_report.json", "posts/cybra_it_evolution_report.md", "data/cybra_it_evolution/reports/latest_report.json"], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    print("✅ IT Evolution report generated")
    print("REPORT: posts/cybra_it_evolution_report.md")
    print("DOUBLE_SHA:", obj["double_sha"])

def cycle():
    build_bin()
    daily_plan()
    watchdog_once()
    report()

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        report()
    elif cmd == "report":
        report()
    elif cmd == "plan":
        daily_plan()
    elif cmd == "task":
        submit_task(" ".join(sys.argv[2:]) or "CYBRA IT task")
    elif cmd == "register":
        if len(sys.argv) < 5:
            print("Usage: register NAME PATH COMMAND...")
            return
        register_script(sys.argv[2], sys.argv[3], sys.argv[4:])
    elif cmd == "run":
        run_registered(sys.argv[2] if len(sys.argv) > 2 else "")
    elif cmd == "build-bin":
        build_bin()
    elif cmd == "watchdog":
        watchdog_once()
    elif cmd == "clean":
        safe_clean()
    elif cmd == "cycle":
        cycle()
    else:
        print("Usage: status|report|plan|task TEXT|register NAME PATH COMMAND...|run NAME|build-bin|watchdog|clean|cycle")

if __name__ == "__main__":
    main()
