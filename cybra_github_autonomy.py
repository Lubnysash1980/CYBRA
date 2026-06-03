#!/usr/bin/env python3
import json
import os
import time
import hashlib
import subprocess
import sys
from pathlib import Path

ROOT = Path(os.environ.get("CYBRA_WORKDIR", os.getcwd())).resolve()

AUDIT_KEY = "cybra:github_autonomy:audit"
AI_BLOCK_INBOX = "cybra:ai:tasks:block_inbox"

SAFE_COMMANDS = [
    ["bash", "cybra_redis_committee.sh", "ensure"],
    ["bash", "cybra_security_analytics.sh", "cycle"],
    ["bash", "cybra_conformation8.sh", "cycle"],
    ["bash", "cybra_autoheal.sh", "cycle"],
    ["bash", "cybra_recovery.sh", "report"],
    ["bash", "cybra_kibra_stats.sh", "report"],
    ["bash", "cybra_market_proof_collector.sh", "collect"],
    ["bash", "cybra_real_market_price_gate.sh", "status"],
    ["bash", "cybra_closed_sha_bridge.sh", "cycle"],
    ["python3", "parliament_executor_v6.py"]
]

MODULES = [
    "cybra_redis_committee.sh",
    "cybra_security_analytics.sh",
    "cybra_conformation8.sh",
    "cybra_autoheal.sh",
    "cybra_recovery.sh",
    "cybra_kibra_stats.sh",
    "cybra_dashboard.sh",
    "cybra_payment_requisites.sh",
    "kybra_valid.sh",
    "cybra_market_proof_collector.sh",
    "cybra_real_market_price_gate.sh",
    "cybra_closed_sha_bridge.sh",
    "cybra_frozen_committee.sh",
    "hash_license_guard.sh",
    "bin/cybra-finance-bin"
]

def sha(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def dsha(obj):
    text = json.dumps(obj, ensure_ascii=False, sort_keys=True)
    return sha(sha(text))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def run(cmd, timeout=240):
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

def load_json(path, default=None):
    p = ROOT / path
    if not p.exists():
        return default if default is not None else {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return default if default is not None else {}

def save_json(path, obj):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

def redis_ping():
    code, out, err = run(["redis-cli", "ping"], timeout=20)
    return code == 0 and out == "PONG"

def ensure_redis():
    if redis_ping():
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
    return redis_ping()

def mask_private_public_files():
    profile = load_json("data/cybra_payment_requisites/payer_profile.json", {})
    tax_id = str(profile.get("payer_tax_id_or_edrpou", "") or "")
    if not tax_id or len(tax_id) < 4:
        return []
    masked = tax_id[:4] + "******"
    changed = []
    for folder in ["posts", "feeds"]:
        d = ROOT / folder
        if not d.exists():
            continue
        for p in list(d.glob("*.md")) + list(d.glob("*.json")):
            text = p.read_text(encoding="utf-8", errors="ignore")
            if tax_id in text:
                p.write_text(text.replace(tax_id, masked), encoding="utf-8")
                changed.append(str(p.relative_to(ROOT)))
    return changed

def create_ai_task(env_name):
    task = {
        "topic": "CYBRA GitHub / Codespaces autonomy verification",
        "type": "github_autonomy_committee_task",
        "priority": "critical",
        "payload": {
            "source": "github_autonomy_committee",
            "environment": env_name,
            "goal": "Ensure CYBRA/KYBRA works autonomously on GitHub Codespaces and GitHub Actions with safe reports, proofs and AI tasks.",
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
    save_json("data/cybra_github_autonomy/tasks/latest_ai_task.json", task)
    rpush(AI_BLOCK_INBOX, task)
    return task

def cycle(env_name="unknown"):
    ensure_redis()

    for m in MODULES:
        p = ROOT / m
        if p.exists():
            try:
                p.chmod(p.stat().st_mode | 0o111)
            except Exception:
                pass

    changed_private = mask_private_public_files()

    results = []
    for cmd in SAFE_COMMANDS:
        if cmd[0] == "bash" and not exists(cmd[1]):
            results.append({"cmd": " ".join(cmd), "ok": False, "missing": True})
            continue
        if cmd[0] == "python3" and not exists(cmd[1]):
            results.append({"cmd": " ".join(cmd), "ok": False, "missing": True})
            continue

        code, out, err = run(cmd, timeout=240)
        results.append({
            "cmd": " ".join(cmd),
            "ok": code == 0,
            "code": code,
            "stdout_tail": out[-1200:],
            "stderr_tail": err[-1200:]
        })

    changed_private += mask_private_public_files()
    ai_task = create_ai_task(env_name)

    main_blocks = count("blockchain/kibra_chain/blocks/block_*.json")
    task_blocks = count("blockchain/kibra_chain/task_blocks/*.json")

    payment = load_json("feeds/cybra_payment_requisites_package.json", {})
    market = load_json("feeds/kibra_real_market_price_gate.json", {})
    security = load_json("feeds/cybra_security_analytics_report.json", {})

    report = {
        "status": "github_autonomy_cycle_completed",
        "time": time.time(),
        "time_iso": now_iso(),
        "environment": env_name,
        "github_actions": os.environ.get("GITHUB_ACTIONS", "false"),
        "codespaces": os.environ.get("CODESPACES", "false"),
        "root": str(ROOT),
        "redis": redis_ping(),
        "modules": {m: exists(m) for m in MODULES},
        "blocks": {
            "main_blocks": main_blocks,
            "task_blocks": task_blocks,
            "estimated_kibra_default_reward_100": (main_blocks + task_blocks) * 100
        },
        "queues": {
            "ai_block_inbox": rlen(AI_BLOCK_INBOX),
            "task_block_mempool": rlen("cybra:kibra:task_blocks:mempool"),
            "pool_mining_blocks": rlen("cybra:kibra:pool:mining_blocks"),
            "parliament_queue": rlen("cybra:parliament:queue"),
            "parliament_failed": rlen("cybra:parliament:failed"),
            "parliament_results": rlen("cybra:parliament:results"),
            "github_autonomy_audit": rlen(AUDIT_KEY)
        },
        "finance": {
            "payment_ready": payment.get("validation", {}).get("ready", False),
            "bank_ready": payment.get("validation", {}).get("bank_ready", False),
            "psp_ready": payment.get("validation", {}).get("psp_ready", False),
            "real_market_confirmed": market.get("real_market_confirmed", False),
            "price_usd_per_kibra": market.get("price_usd_per_kibra", 0),
            "real_payment_now": False
        },
        "security": {
            "risk_level": security.get("risk_level", "UNKNOWN"),
            "risk_score": security.get("risk_score"),
            "private_files_masked": list(sorted(set(changed_private))),
            "private_keys_collected": False,
            "seed_phrase_collected": False,
            "automatic_SWIFT": False,
            "automatic_external_tx": False,
            "manual_OWNER_approval_required": True
        },
        "commands": results,
        "ai_task_double_sha": ai_task["double_sha"],
        "recommendations": [
            "Run CYBRA in Codespaces for interactive dashboard and development.",
            "Run GitHub Actions scheduled cycle for autonomous safe report/proof refresh.",
            "Keep real payments, SWIFT and external tx disabled until OWNER approval.",
            "Provide real bank IBAN or PSP provider for payment readiness.",
            "Provide real pool/orderbook/provider/reserve proof for KIBRA market price."
        ]
    }

    report["double_sha"] = dsha(report)

    save_json("feeds/cybra_github_autonomy_report.json", report)
    save_json("data/cybra_github_autonomy/reports/latest_report.json", report)

    lines = []
    lines.append("# CYBRA GitHub / Codespaces Autonomy Report")
    lines.append("")
    lines.append("Status: github_autonomy_cycle_completed")
    lines.append(f"Environment: {env_name}")
    lines.append(f"Redis: {report['redis']}")
    lines.append("")
    lines.append("## Modules")
    for k, v in report["modules"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Blocks")
    for k, v in report["blocks"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Queues")
    for k, v in report["queues"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Finance")
    for k, v in report["finance"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Recommendations")
    for x in report["recommendations"]:
        lines.append("- " + x)
    lines.append("")
    lines.append("## Safety")
    for k, v in report["security"].items():
        if k != "private_files_masked":
            lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Double SHA")
    lines.append(report["double_sha"])

    (ROOT / "posts").mkdir(exist_ok=True)
    (ROOT / "posts/cybra_github_autonomy_report.md").write_text("\n".join(lines), encoding="utf-8")

    with (ROOT / "proofs/cybra_github_autonomy.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "feeds/cybra_github_autonomy_report.json",
            "posts/cybra_github_autonomy_report.md",
            "data/cybra_github_autonomy/reports/latest_report.json",
            "parliament/committees/github_autonomy_committee/committee.json"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    rpush(AUDIT_KEY, {
        "status": "github_autonomy_cycle_completed",
        "environment": env_name,
        "double_sha": report["double_sha"],
        "time": report["time"]
    })

    print("✅ CYBRA GitHub autonomy cycle completed")
    print("ENV:", env_name)
    print("REDIS:", report["redis"])
    print("MAIN_BLOCKS:", main_blocks)
    print("TASK_BLOCKS:", task_blocks)
    print("PARLIAMENT_FAILED:", report["queues"]["parliament_failed"])
    print("REPORT: posts/cybra_github_autonomy_report.md")
    print("PROOF: proofs/cybra_github_autonomy.sha256")
    print("DOUBLE_SHA:", report["double_sha"])

def status():
    report = load_json("feeds/cybra_github_autonomy_report.json", {})
    print("GITHUB_AUTONOMY_COMMITTEE: active")
    print("REPORT_EXISTS:", exists("posts/cybra_github_autonomy_report.md"))
    print("WORKFLOW_EXISTS:", exists(".github/workflows/cybra-autonomous-cycle.yml"))
    print("DEVCONTAINER_EXISTS:", exists(".devcontainer/devcontainer.json"))
    print("REDIS:", redis_ping())
    print("ENV:", report.get("environment", "none"))
    print("PARLIAMENT_FAILED:", rlen("cybra:parliament:failed"))
    print("AI_BLOCK_INBOX:", rlen(AI_BLOCK_INBOX))
    print("AUDIT:", rlen(AUDIT_KEY))

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "cycle":
        env_name = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("CYBRA_ENV", "local")
        cycle(env_name)
    elif cmd == "status":
        status()
    else:
        raise SystemExit("Usage: status|cycle ENV")

if __name__ == "__main__":
    main()
