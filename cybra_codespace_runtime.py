#!/usr/bin/env python3
import json
import os
import time
import hashlib
import subprocess
import sys
from pathlib import Path

ROOT = Path(os.environ.get("CYBRA_WORKDIR", str(Path.home() / "CYBRA"))).expanduser().resolve()

AUDIT_KEY = "cybra:codespace_runtime:audit"
AI_BLOCK_INBOX = "cybra:ai:tasks:block_inbox"
PARLIAMENT_QUEUE = "cybra:parliament:queue"

WATCH_MODULES = [
    "cybra_redis_committee.sh",
    "cybra_autoheal.sh",
    "cybra_security_analytics.sh",
    "cybra_conformation8.sh",
    "cybra_recovery.sh",
    "cybra_dashboard.sh",
    "cybra_kibra_stats.sh",
    "cybra_closed_sha_bridge.sh",
    "parliament_executor_v6.py"
]

SAFE_CYCLE_COMMANDS = [
    ["bash", "cybra_redis_committee.sh", "ensure"],
    ["bash", "cybra_security_analytics.sh", "cycle"],
    ["bash", "cybra_conformation8.sh", "cycle"],
    ["bash", "cybra_autoheal.sh", "cycle"],
    ["bash", "cybra_recovery.sh", "report"],
    ["bash", "cybra_kibra_stats.sh", "report"],
    ["bash", "cybra_closed_sha_bridge.sh", "cycle"],
    ["python3", "parliament_executor_v6.py"]
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

def chmod_runtime():
    fixed = []
    for p in ROOT.glob("*.sh"):
        try:
            p.chmod(p.stat().st_mode | 0o111)
            fixed.append(str(p.relative_to(ROOT)))
        except Exception:
            pass
    bindir = ROOT / "bin"
    if bindir.exists():
        for p in bindir.glob("*"):
            if p.is_file():
                try:
                    p.chmod(p.stat().st_mode | 0o111)
                    fixed.append(str(p.relative_to(ROOT)))
                except Exception:
                    pass
    return fixed

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
    return sorted(set(changed))

def safe_gitignore():
    lines = [
        "runtime/",
        "logs/",
        "*.log",
        "*.pid",
        "dump.rdb",
        "*.rdb",
        ".env",
        "*.key",
        "*.pem",
        "id_rsa",
        "id_ed25519",
        "*private*",
        "*secret*",
        "*token*",
        "data/cybra_payment_requisites/private/",
        "posts/private/",
        "feeds/private/",
        "proofs/private/",
        "*.local.json",
        "owner_identity*",
        "payer_identity*",
        "data/cybra_dashboard/dashboard_token.local"
    ]
    p = ROOT / ".gitignore"
    old = p.read_text(encoding="utf-8") if p.exists() else ""
    arr = old.splitlines()
    for line in lines:
        if line not in arr:
            arr.append(line)
    p.write_text("\n".join(arr).strip() + "\n", encoding="utf-8")
    run(["git", "rm", "--cached", "dump.rdb"], timeout=30)

def backend_name():
    if os.environ.get("CODESPACES") == "true":
        return "GITHUB_CODESPACE_BACKEND"
    if os.environ.get("GITHUB_ACTIONS") == "true":
        return "GITHUB_ACTIONS_EPHEMERAL_BACKEND"
    return "LOCAL_TERMUX_BACKEND"

def runtime_status():
    ensure_redis()
    chmod_runtime()
    safe_gitignore()
    masked = mask_private_public_files()

    main_blocks = count("blockchain/kibra_chain/blocks/block_*.json")
    task_blocks = count("blockchain/kibra_chain/task_blocks/*.json")

    status = {
        "status": "codespace_runtime_status",
        "time": time.time(),
        "time_iso": now_iso(),
        "backend": backend_name(),
        "root": str(ROOT),
        "redis": redis_ping(),
        "modules": {m: exists(m) for m in WATCH_MODULES},
        "reports": {
            "autoheal": exists("posts/cybra_autoheal_7lvl_report.md"),
            "security": exists("posts/cybra_security_analytics_report.md"),
            "conformation8": exists("posts/cybra_conformation8_report.md"),
            "autorecovery": exists("posts/cybra_autorecovery_report.md"),
            "dashboard": exists("posts/cybra_dashboard_report.md"),
            "github_autonomy": exists("posts/cybra_github_autonomy_report.md"),
            "kibra_stats": exists("posts/kibra_stats_recommendations_report.md")
        },
        "blocks": {
            "main_blocks": main_blocks,
            "task_blocks": task_blocks,
            "estimated_kibra_default_reward_100": (main_blocks + task_blocks) * 100
        },
        "queues": {
            "ai_block_inbox": rlen(AI_BLOCK_INBOX),
            "task_block_mempool": rlen("cybra:kibra:task_blocks:mempool"),
            "pool_mining_blocks": rlen("cybra:kibra:pool:mining_blocks"),
            "task_blocks_mined": rlen("cybra:kibra:task_blocks:mined"),
            "parliament_queue": rlen(PARLIAMENT_QUEUE),
            "parliament_failed": rlen("cybra:parliament:failed"),
            "parliament_results": rlen("cybra:parliament:results"),
            "codespace_audit": rlen(AUDIT_KEY)
        },
        "privacy": {
            "masked_public_files": masked,
            "private_identity_included": False,
            "private_keys_collected": False,
            "seed_phrase_collected": False
        },
        "safety": {
            "real_payment_now": False,
            "automatic_SWIFT": False,
            "automatic_external_tx": False,
            "manual_OWNER_approval_required": True
        }
    }
    status["health_ok"] = status["redis"] and status["queues"]["parliament_failed"] == 0
    status["double_sha"] = dsha(status)
    return status

def safe_cycle(env="manual"):
    before = runtime_status()
    results = []

    for cmd in SAFE_CYCLE_COMMANDS:
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
            "stdout_tail": out[-1000:],
            "stderr_tail": err[-1000:]
        })

    after = runtime_status()

    task = {
        "topic": "Codespace Runtime Committee safe cycle",
        "type": "codespace_runtime_committee_task",
        "priority": "critical" if not after["health_ok"] else "normal",
        "payload": {
            "source": "codespace_runtime_committee",
            "backend": after["backend"],
            "goal": "Keep CYBRA working on GitHub Codespaces/GitHub Actions with watchdog, AutoHeal, double backend and Double-SHA proof.",
            "before_sha": before["double_sha"],
            "after_sha": after["double_sha"],
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
    save_json("data/cybra_codespace_runtime/tasks/latest_ai_task.json", task)
    rpush(AI_BLOCK_INBOX, task)

    report = {
        "status": "codespace_runtime_cycle_completed",
        "environment": env,
        "time": time.time(),
        "time_iso": now_iso(),
        "before": before,
        "after": after,
        "commands": results,
        "ai_task_sha": task["double_sha"],
        "double_backend": {
            "local_termux_backend_supported": True,
            "github_codespace_backend_supported": True,
            "github_actions_ephemeral_backend_supported": True,
            "active_backend": after["backend"]
        },
        "watchdog": {
            "redis_watch": True,
            "autoheal_watch": True,
            "security_watch": True,
            "conformation_watch": True,
            "dashboard_watch": True,
            "recovery_watch": True
        },
        "safety": after["safety"]
    }
    report["double_sha"] = dsha(report)

    save_json("feeds/cybra_codespace_runtime_report.json", report)
    save_json("data/cybra_codespace_runtime/reports/latest_report.json", report)

    lines = []
    lines.append("# CYBRA GitHub Codespace Runtime Committee Report")
    lines.append("")
    lines.append("Status: cycle_completed")
    lines.append(f"Backend: {after['backend']}")
    lines.append(f"Health OK: {after['health_ok']}")
    lines.append("")
    lines.append("## Modules")
    for k, v in after["modules"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Reports")
    for k, v in after["reports"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Blocks")
    for k, v in after["blocks"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Queues")
    for k, v in after["queues"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Double backend")
    for k, v in report["double_backend"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Watchdog")
    for k, v in report["watchdog"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Safety")
    for k, v in after["safety"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Double SHA")
    lines.append(report["double_sha"])

    (ROOT / "posts").mkdir(exist_ok=True)
    (ROOT / "posts/cybra_codespace_runtime_report.md").write_text("\n".join(lines), encoding="utf-8")

    (ROOT / "proofs").mkdir(exist_ok=True)
    with (ROOT / "proofs/cybra_codespace_runtime.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "parliament/committees/codespace_runtime_committee/committee.json",
            "feeds/cybra_codespace_runtime_report.json",
            "posts/cybra_codespace_runtime_report.md",
            "data/cybra_codespace_runtime/reports/latest_report.json"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    rpush(AUDIT_KEY, {
        "status": "cycle_completed",
        "backend": after["backend"],
        "health_ok": after["health_ok"],
        "double_sha": report["double_sha"],
        "time": report["time"]
    })

    print("✅ CYBRA Codespace Runtime cycle completed")
    print("BACKEND:", after["backend"])
    print("HEALTH_OK:", after["health_ok"])
    print("REPORT: posts/cybra_codespace_runtime_report.md")
    print("PROOF: proofs/cybra_codespace_runtime.sha256")
    print("DOUBLE_SHA:", report["double_sha"])

def start_dashboard():
    if not exists("cybra_dashboard.sh"):
        print("dashboard wrapper missing")
        return
    run(["bash", "cybra_dashboard.sh", "restart", "8099", "127.0.0.1"], timeout=60)
    print("✅ dashboard requested: http://127.0.0.1:8099")

def status_cli():
    s = runtime_status()
    print("CODESPACE_RUNTIME_COMMITTEE: active")
    print("BACKEND:", s["backend"])
    print("HEALTH_OK:", s["health_ok"])
    print("REDIS:", s["redis"])
    print("MAIN_BLOCKS:", s["blocks"]["main_blocks"])
    print("TASK_BLOCKS:", s["blocks"]["task_blocks"])
    print("EST_KIBRA:", s["blocks"]["estimated_kibra_default_reward_100"])
    print("AI_BLOCK_INBOX:", s["queues"]["ai_block_inbox"])
    print("PARLIAMENT_FAILED:", s["queues"]["parliament_failed"])
    print("REPORT_EXISTS:", exists("posts/cybra_codespace_runtime_report.md"))
    print("AUDIT:", s["queues"]["codespace_audit"])

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        status_cli()
    elif cmd == "cycle":
        env = sys.argv[2] if len(sys.argv) > 2 else backend_name()
        safe_cycle(env)
    elif cmd == "dashboard":
        start_dashboard()
    else:
        raise SystemExit("Usage: status|cycle [ENV]|dashboard")

if __name__ == "__main__":
    main()
