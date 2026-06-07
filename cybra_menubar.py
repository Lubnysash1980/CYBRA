#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import time
import hashlib
from pathlib import Path

ROOT = Path.home() / "CYBRA"

AI_BLOCK_INBOX = "cybra:ai:tasks:block_inbox"
PARLIAMENT_QUEUE = "cybra:parliament:queue"
AUDIT_KEY = "cybra:menubar:audit"
TASKS_KEY = "cybra:menubar:tasks"
POSTS_KEY = "cybra:menubar:posts"
WITHDRAW_KEY = "cybra:menubar:withdraw_proposals"

def sha(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def dsha(obj):
    text = json.dumps(obj, ensure_ascii=False, sort_keys=True)
    return sha(sha(text))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def run(cmd, timeout=120):
    try:
        p = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True, timeout=timeout)
        return p.returncode, p.stdout.strip(), p.stderr.strip()
    except Exception as e:
        return 1, "", str(e)

def exists(path):
    return (ROOT / path).exists()

def count(pattern):
    return len(list(ROOT.glob(pattern)))

def rlen(key):
    code, out, err = run(["redis-cli", "LLEN", key], timeout=20)
    return int(out) if code == 0 and out.strip().isdigit() else 0

def rpush(key, obj):
    run(["redis-cli", "LPUSH", key, json.dumps(obj, ensure_ascii=False)], timeout=20)

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

def read_text(path):
    p = ROOT / path
    if not p.exists():
        return ""
    return p.read_text(encoding="utf-8", errors="ignore")

def ensure_redis():
    code, out, err = run(["redis-cli", "ping"], timeout=20)
    if code == 0 and out == "PONG":
        return True
    (ROOT / "runtime/redis").mkdir(parents=True, exist_ok=True)
    run([
        "redis-server",
        "--daemonize", "yes",
        "--bind", "127.0.0.1",
        "--port", "6379",
        "--dir", str(ROOT / "runtime/redis"),
        "--save", "",
        "--appendonly", "no"
    ], timeout=30)
    time.sleep(1)
    code, out, err = run(["redis-cli", "ping"], timeout=20)
    return code == 0 and out == "PONG"

def mask_public_files():
    profile = load_json("data/cybra_payment_requisites/payer_profile.json", {})
    tax_id = str(profile.get("payer_tax_id_or_edrpou", "") or "")
    if not tax_id or len(tax_id) < 4:
        return
    masked = tax_id[:4] + "******"
    for folder in ["posts", "feeds"]:
        d = ROOT / folder
        if not d.exists():
            continue
        for p in list(d.glob("*.md")) + list(d.glob("*.json")):
            text = p.read_text(encoding="utf-8", errors="ignore")
            if tax_id in text:
                p.write_text(text.replace(tax_id, masked), encoding="utf-8")

def safe_id(text):
    text = text.strip().lower()
    text = re.sub(r"[^a-z0-9_/-]+", "_", text)
    text = text.strip("_")
    return text or ("committee_" + sha(str(time.time()))[:8])

def get_state():
    ensure_redis()
    mask_public_files()

    main_blocks = count("blockchain/kibra_chain/blocks/block_*.json")
    task_blocks = count("blockchain/kibra_chain/task_blocks/*.json")
    estimated_kibra = (main_blocks + task_blocks) * 100

    payment = load_json("feeds/cybra_payment_requisites_package.json", {})
    market = load_json("feeds/kibra_real_market_price_gate.json", {})
    dashboard = load_json("feeds/cybra_dashboard_report.json", {})
    github_runtime = load_json("feeds/cybra_codespace_runtime_report.json", {})

    validation = payment.get("validation", {})

    modules = {
        "dashboard": exists("cybra_dashboard.sh"),
        "codespace_runtime": exists("cybra_codespace_runtime.sh"),
        "autoheal": exists("cybra_autoheal.sh"),
        "security": exists("cybra_security_analytics.sh"),
        "conformation8": exists("cybra_conformation8.sh"),
        "recovery": exists("cybra_recovery.sh"),
        "kibra_stats": exists("cybra_kibra_stats.sh"),
        "payment": exists("cybra_payment_requisites.sh"),
        "kybra_valid": exists("kybra_valid.sh"),
        "frozen_committee": exists("cybra_frozen_committee.sh"),
        "hash_license_guard": exists("hash_license_guard.sh"),
        "parliament_executor": exists("parliament_executor_v6.py")
    }

    state = {
        "status": "cybra_menubar_state",
        "time": time.time(),
        "time_iso": now_iso(),
        "tokens": {
            "main_blocks": main_blocks,
            "task_blocks": task_blocks,
            "estimated_kibra_default_reward_100": estimated_kibra,
            "price_usd_per_kibra": market.get("price_usd_per_kibra", 0),
            "real_market_confirmed": bool(market.get("real_market_confirmed", False))
        },
        "finance": {
            "payment_ready": bool(validation.get("ready", False)),
            "bank_ready": bool(validation.get("bank_ready", False)),
            "psp_ready": bool(validation.get("psp_ready", False)),
            "real_payment_now": False,
            "real_sell_now": False
        },
        "queues": {
            "ai_block_inbox": rlen(AI_BLOCK_INBOX),
            "task_block_mempool": rlen("cybra:kibra:task_blocks:mempool"),
            "pool_mining_blocks": rlen("cybra:kibra:pool:mining_blocks"),
            "task_blocks_mined": rlen("cybra:kibra:task_blocks:mined"),
            "parliament_queue": rlen(PARLIAMENT_QUEUE),
            "parliament_results": rlen("cybra:parliament:results"),
            "parliament_failed": rlen("cybra:parliament:failed"),
            "menubar_tasks": rlen(TASKS_KEY),
            "menubar_posts": rlen(POSTS_KEY),
            "withdraw_proposals": rlen(WITHDRAW_KEY)
        },
        "modules": modules,
        "reports": {
            "dashboard": exists("posts/cybra_dashboard_report.md"),
            "codespace_runtime": exists("posts/cybra_codespace_runtime_report.md"),
            "autoheal": exists("posts/cybra_autoheal_7lvl_report.md"),
            "security": exists("posts/cybra_security_analytics_report.md"),
            "conformation8": exists("posts/cybra_conformation8_report.md"),
            "recovery": exists("posts/cybra_autorecovery_report.md"),
            "kibra_stats": exists("posts/kibra_stats_recommendations_report.md"),
            "payment": exists("posts/cybra_payment_requisites_package.md")
        },
        "safety": {
            "automatic_real_payment": False,
            "automatic_SWIFT": False,
            "automatic_external_tx": False,
            "seed_phrase_required": False,
            "private_key_required": False,
            "manual_OWNER_approval_required": True
        }
    }
    state["double_sha"] = dsha(state)
    return state

def extract_recommendations():
    files = [
        "posts/kibra_stats_recommendations_report.md",
        "posts/cybra_security_analytics_report.md",
        "posts/cybra_conformation8_report.md",
        "posts/cybra_test_autofix_recommendations_report.md",
        "posts/cybra_dashboard_report.md",
        "posts/cybra_codespace_runtime_report.md"
    ]

    out = []
    for rel in files:
        text = read_text(rel)
        if not text:
            continue
        lines = text.splitlines()
        capture = False
        for line in lines:
            s = line.strip()
            if s.startswith("## Parliament recommendations") or s.startswith("## Audit recommendations") or s.startswith("## Recommendations") or s.startswith("## Missing / Issues"):
                capture = True
                continue
            if capture and s.startswith("## "):
                capture = False
            if capture and s:
                out.append(f"{rel}: {s}")
    return out[-40:]

def print_status():
    s = get_state()

    print("")
    print("╔════════════════════════════════════════════╗")
    print("║          CYBRA / KYBRA TERMUX MENU        ║")
    print("╚════════════════════════════════════════════╝")
    print("")
    print("TOKENS")
    print("  Main blocks:", s["tokens"]["main_blocks"])
    print("  Task blocks:", s["tokens"]["task_blocks"])
    print("  Estimated KIBRA:", s["tokens"]["estimated_kibra_default_reward_100"])
    print("  Price USD/KIBRA:", s["tokens"]["price_usd_per_kibra"])
    print("  Real market confirmed:", s["tokens"]["real_market_confirmed"])
    print("")
    print("FINANCE")
    print("  Payment ready:", s["finance"]["payment_ready"])
    print("  Bank ready:", s["finance"]["bank_ready"])
    print("  PSP ready:", s["finance"]["psp_ready"])
    print("  Real payment now:", s["finance"]["real_payment_now"])
    print("")
    print("PARLIAMENT / TASKS")
    print("  AI block inbox:", s["queues"]["ai_block_inbox"])
    print("  Pool mining blocks:", s["queues"]["pool_mining_blocks"])
    print("  Parliament queue:", s["queues"]["parliament_queue"])
    print("  Parliament results:", s["queues"]["parliament_results"])
    print("  Parliament failed:", s["queues"]["parliament_failed"])
    print("  Withdraw proposals:", s["queues"]["withdraw_proposals"])
    print("")
    print("MODULES")
    for k, v in s["modules"].items():
        print(f"  {k}: {v}")
    print("")
    print("Double SHA:", s["double_sha"])

def submit_task(topic, payload_text="", route="block"):
    ensure_redis()

    task = {
        "topic": topic,
        "type": "menubar_owner_task",
        "priority": "normal",
        "source": "cybra_termux_menubar",
        "payload": {
            "text": payload_text or topic,
            "route": route,
            "convert_to_mining_block_first": True,
            "send_to_pool_mining": True,
            "real_payment_now": False,
            "automatic_SWIFT": False,
            "automatic_external_tx": False,
            "manual_OWNER_approval_required": True
        },
        "time": time.time(),
        "time_iso": now_iso()
    }
    task["double_sha"] = dsha(task)

    save_json(f"data/cybra_menubar/tasks/task_{task['double_sha'][:16]}.json", task)

    if route == "parliament":
        rpush(PARLIAMENT_QUEUE, task)
        target = PARLIAMENT_QUEUE
    else:
        rpush(AI_BLOCK_INBOX, task)
        target = AI_BLOCK_INBOX

    rpush(TASKS_KEY, task)
    rpush(AUDIT_KEY, {"status": "task_submitted", "target": target, "double_sha": task["double_sha"], "time": task["time"]})

    print("✅ Task submitted")
    print("TARGET:", target)
    print("DOUBLE_SHA:", task["double_sha"])

def create_post(title, body):
    post_id = sha(title + body + str(time.time()))[:16]
    obj = {
        "post_id": post_id,
        "title": title,
        "body": body,
        "source": "cybra_termux_menubar",
        "time": time.time(),
        "time_iso": now_iso(),
        "real_payment_now": False,
        "automatic_external_tx": False,
        "manual_OWNER_approval_required": True
    }
    obj["double_sha"] = dsha(obj)

    save_json(f"data/cybra_menubar/posts/{post_id}.json", obj)

    md = f"""# CYBRA Parliament Post

Post ID: {post_id}

## Title

{title}

## Body

{body}

## Safety

real_payment_now: false
automatic_external_tx: false
manual_OWNER_approval_required: true

## Double SHA

{obj['double_sha']}
"""
    (ROOT / f"posts/cybra_parliament_post_{post_id}.md").write_text(md, encoding="utf-8")

    rpush(POSTS_KEY, obj)
    rpush(AI_BLOCK_INBOX, {
        "topic": "CYBRA Parliament Post",
        "type": "menubar_post_task",
        "priority": "normal",
        "payload": obj
    })

    print("✅ Post created")
    print("POST:", f"posts/cybra_parliament_post_{post_id}.md")
    print("DOUBLE_SHA:", obj["double_sha"])

def create_committee(name, mission):
    cid = safe_id(name)
    committee = {
        "committee_id": cid,
        "name": name,
        "status": "active",
        "parent": "cybra_parliament",
        "mission": mission,
        "created_by": "cybra_termux_menubar",
        "created_at": time.time(),
        "created_at_iso": now_iso(),
        "rules": [
            "AI tasks go through block inbox and mining blocks.",
            "No automatic real payment.",
            "No automatic SWIFT.",
            "No automatic external transaction.",
            "OWNER approval required for real-world actions."
        ],
        "manual_OWNER_approval_required": True
    }
    committee["double_sha"] = dsha(committee)

    paths = [
        f"parliament/committees/{cid}/committee.json",
        f"parliament/departments/finance_department/{cid}/committee.json",
        f"parliament/departments/cybra_finance_department/{cid}/committee.json",
        f"data/cybra_menubar/committees/{cid}.json"
    ]
    for p in paths:
        save_json(p, committee)

    task = {
        "topic": f"Create committee: {name}",
        "type": "menubar_create_committee_task",
        "priority": "normal",
        "payload": {
            "committee_id": cid,
            "name": name,
            "mission": mission,
            "convert_to_mining_block_first": True,
            "send_to_pool_mining": True,
            "real_payment_now": False,
            "automatic_external_tx": False,
            "manual_OWNER_approval_required": True
        },
        "time": time.time(),
        "time_iso": now_iso()
    }
    task["double_sha"] = dsha(task)

    rpush(AI_BLOCK_INBOX, task)
    rpush(AUDIT_KEY, {"status": "committee_created", "committee_id": cid, "double_sha": committee["double_sha"], "time": time.time()})

    print("✅ Committee created")
    print("COMMITTEE_ID:", cid)
    print("PATH:", f"parliament/committees/{cid}/committee.json")

def withdraw_proposal(amount, destination, network="KYBRA_INTERNAL", memo=""):
    state = get_state()
    proposal_id = "WD-" + sha(str(time.time()) + destination + str(amount))[:16].upper()

    proposal = {
        "proposal_id": proposal_id,
        "status": "PENDING_OWNER_APPROVAL",
        "type": "withdraw_proposal",
        "amount_kibra": str(amount),
        "destination": destination,
        "network": network,
        "memo": memo,
        "source": "cybra_termux_menubar",
        "available_estimated_kibra": state["tokens"]["estimated_kibra_default_reward_100"],
        "real_external_tx_now": False,
        "real_payment_now": False,
        "automatic_SWIFT": False,
        "manual_OWNER_approval_required": True,
        "rule": "This is only a withdrawal proposal. No real external transaction is executed.",
        "time": time.time(),
        "time_iso": now_iso()
    }
    proposal["double_sha"] = dsha(proposal)

    save_json(f"data/cybra_menubar/withdraw_proposals/{proposal_id}.json", proposal)

    rpush(WITHDRAW_KEY, proposal)
    rpush(AI_BLOCK_INBOX, {
        "topic": "KIBRA withdraw proposal",
        "type": "menubar_withdraw_proposal_task",
        "priority": "critical",
        "payload": proposal
    })

    print("✅ Withdraw proposal created")
    print("PROPOSAL_ID:", proposal_id)
    print("STATUS: PENDING_OWNER_APPROVAL")
    print("REAL_EXTERNAL_TX_NOW: false")
    print("DOUBLE_SHA:", proposal["double_sha"])

def run_cycle(name):
    commands = {
        "safe": [
            ["bash", "cybra_security_analytics.sh", "cycle"],
            ["bash", "cybra_conformation8.sh", "cycle"],
            ["bash", "cybra_autoheal.sh", "cycle"],
            ["bash", "cybra_kibra_stats.sh", "report"]
        ],
        "bridge": [
            ["bash", "cybra_closed_sha_bridge.sh", "cycle"]
        ],
        "dashboard": [
            ["bash", "cybra_dashboard.sh", "report"]
        ],
        "runtime": [
            ["bash", "cybra_codespace_runtime.sh", "cycle", "menubar"]
        ],
        "finance": [
            ["bash", "cybra_payment_requisites.sh", "report"],
            ["bash", "kybra_valid.sh", "report"],
            ["bash", "cybra_market_proof_collector.sh", "collect"],
            ["bash", "cybra_real_market_price_gate.sh", "status"]
        ],
        "parliament": [
            ["python3", "parliament_executor_v6.py"]
        ]
    }

    selected = commands.get(name, commands["safe"])
    for cmd in selected:
        if cmd[0] == "bash" and not exists(cmd[1]):
            print("⚠ missing:", " ".join(cmd))
            continue
        if cmd[0] == "python3" and not exists(cmd[1]):
            print("⚠ missing:", " ".join(cmd))
            continue
        print("RUN:", " ".join(cmd))
        code, out, err = run(cmd, timeout=240)
        print("CODE:", code)
        if out:
            print(out[-1200:])
        if err:
            print(err[-800:])

    report()

def show_recommendations():
    recs = extract_recommendations()
    if not recs:
        print("No recommendations found. Run: bash cybra_menubar.sh cycle safe")
        return
    print("")
    print("=== RECOMMENDATIONS ===")
    for x in recs:
        print("-", x)

def show_finance():
    print("")
    print("=== CYBRA FINANCE ===")
    code, out, err = run(["bin/cybra-finance-bin", "status"], timeout=60) if exists("bin/cybra-finance-bin") else (1, "", "missing")
    if out:
        print(out)
    if exists("kybra_valid.sh"):
        code, out, err = run(["bash", "kybra_valid.sh", "status"], timeout=60)
        if out:
            print("")
            print(out)
    if exists("cybra_payment_requisites.sh"):
        code, out, err = run(["bash", "cybra_payment_requisites.sh", "status"], timeout=60)
        if out:
            print("")
            print(out)

    s = get_state()
    print("")
    print("Payment ready:", s["finance"]["payment_ready"])
    print("Bank ready:", s["finance"]["bank_ready"])
    print("PSP ready:", s["finance"]["psp_ready"])
    print("Real market confirmed:", s["tokens"]["real_market_confirmed"])
    print("Price USD/KIBRA:", s["tokens"]["price_usd_per_kibra"])

def report():
    state = get_state()
    recommendations = extract_recommendations()

    obj = {
        "status": "cybra_menubar_report_generated",
        "time": time.time(),
        "time_iso": now_iso(),
        "state": state,
        "recommendations": recommendations,
        "safety": state["safety"]
    }
    obj["double_sha"] = dsha(obj)

    save_json("feeds/cybra_menubar_report.json", obj)
    save_json("data/cybra_menubar/reports/latest_report.json", obj)

    lines = []
    lines.append("# CYBRA Termux Menu-Bar Report")
    lines.append("")
    lines.append("Status: generated")
    lines.append("")
    lines.append("## Tokens")
    for k, v in state["tokens"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Finance")
    for k, v in state["finance"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Queues")
    for k, v in state["queues"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Modules")
    for k, v in state["modules"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Recommendations")
    if recommendations:
        for r in recommendations[-25:]:
            lines.append("- " + r)
    else:
        lines.append("None")
    lines.append("")
    lines.append("## Safety")
    for k, v in state["safety"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Double SHA")
    lines.append(obj["double_sha"])

    (ROOT / "posts/cybra_menubar_report.md").write_text("\n".join(lines), encoding="utf-8")

    with (ROOT / "proofs/cybra_menubar.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "parliament/committees/termux_menubar_committee/committee.json",
            "feeds/cybra_menubar_report.json",
            "posts/cybra_menubar_report.md",
            "data/cybra_menubar/reports/latest_report.json"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    rpush(AUDIT_KEY, {
        "status": "menubar_report_generated",
        "double_sha": obj["double_sha"],
        "time": obj["time"]
    })

    print("✅ Menu-Bar report generated")
    print("REPORT: posts/cybra_menubar_report.md")
    print("PROOF: proofs/cybra_menubar.sha256")

def interactive_menu():
    while True:
        print_status()
        print("")
        print("════════════ MENU ════════════")
        print("1) Refresh status")
        print("2) Finance status")
        print("3) Submit AI task to Parliament/mining blocks")
        print("4) Create Parliament post")
        print("5) Create new committee")
        print("6) Withdraw proposal")
        print("7) Recommendations / remarks")
        print("8) Run safe autofix cycle")
        print("9) Run bridge / mine AI blocks")
        print("10) Run dashboard report")
        print("11) Run Codespace runtime cycle")
        print("12) Generate Menu-Bar report")
        print("13) Start web dashboard")
        print("14) Recovery / AutoRecovery")
        print("0) Exit")
        print("══════════════════════════════")
        choice = input("Select: ").strip()

        if choice == "0":
            break
        elif choice == "1":
            continue
        elif choice == "2":
            show_finance()
            input("Enter...")
        elif choice == "3":
            topic = input("Task topic: ").strip()
            payload = input("Task details: ").strip()
            route = input("Route block/parliament [block]: ").strip() or "block"
            submit_task(topic, payload, route)
            input("Enter...")
        elif choice == "4":
            title = input("Post title: ").strip()
            body = input("Post body: ").strip()
            create_post(title, body)
            input("Enter...")
        elif choice == "5":
            name = input("Committee name: ").strip()
            mission = input("Committee mission: ").strip()
            create_committee(name, mission)
            input("Enter...")
        elif choice == "6":
            amount = input("Amount KIBRA: ").strip()
            dest = input("Destination/address: ").strip()
            network = input("Network [KYBRA_INTERNAL]: ").strip() or "KYBRA_INTERNAL"
            memo = input("Memo: ").strip()
            withdraw_proposal(amount, dest, network, memo)
            input("Enter...")
        elif choice == "7":
            show_recommendations()
            input("Enter...")
        elif choice == "8":
            run_cycle("safe")
            input("Enter...")
        elif choice == "9":
            run_cycle("bridge")
            input("Enter...")
        elif choice == "10":
            run_cycle("dashboard")
            input("Enter...")
        elif choice == "11":
            run_cycle("runtime")
            input("Enter...")
        elif choice == "12":
            report()
            input("Enter...")
        elif choice == "13":
            if exists("cybra_dashboard.sh"):
                run(["bash", "cybra_dashboard.sh", "restart", "8099", "127.0.0.1"], timeout=60)
                print("OPEN: http://127.0.0.1:8099")
            else:
                print("Dashboard not installed")
            input("Enter...")
        elif choice == "14":
            code, out, err = run(["bash", "cybra_menu_recovery_bridge.sh", "cycle"], timeout=240)
            if out:
                print(out)
            if err:
                print(err)
            report()
            input("Enter...")
        else:
            print("Unknown option")
            time.sleep(1)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", nargs="?", default="menu")
    parser.add_argument("args", nargs="*")
    args = parser.parse_args()

    cmd = args.command

    if cmd == "menu":
        interactive_menu()
    elif cmd == "status":
        print_status()
    elif cmd == "finance":
        show_finance()
    elif cmd == "recommendations":
        show_recommendations()
    elif cmd == "task":
        submit_task(" ".join(args.args) if args.args else "CYBRA Menu-Bar Task")
    elif cmd == "post":
        title = args.args[0] if args.args else "CYBRA Menu-Bar Post"
        body = " ".join(args.args[1:]) if len(args.args) > 1 else ""
        create_post(title, body)
    elif cmd == "committee":
        name = args.args[0] if args.args else "New Committee"
        mission = " ".join(args.args[1:]) if len(args.args) > 1 else "Created from CYBRA Termux Menu-Bar"
        create_committee(name, mission)
    elif cmd == "withdraw":
        if len(args.args) < 2:
            raise SystemExit("Usage: withdraw AMOUNT DESTINATION [NETWORK] [MEMO]")
        amount = args.args[0]
        dest = args.args[1]
        network = args.args[2] if len(args.args) > 2 else "KYBRA_INTERNAL"
        memo = " ".join(args.args[3:]) if len(args.args) > 3 else ""
        withdraw_proposal(amount, dest, network, memo)
    elif cmd == "cycle":
        run_cycle(args.args[0] if args.args else "safe")
    elif cmd == "recovery":
        subcmd = args.args[0] if args.args else "status"
        code, out, err = run(["bash", "cybra_menu_recovery_bridge.sh", subcmd], timeout=240)
        if out:
            print(out)
        if err:
            print(err)
    elif cmd == "report":
        report()
    else:
        raise SystemExit("Usage: menu|status|finance|recommendations|task|post|committee|withdraw|cycle|report")

if __name__ == "__main__":
    main()
