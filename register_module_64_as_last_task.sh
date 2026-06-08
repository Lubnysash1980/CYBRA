#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== РЕЄСТРАЦІЯ MODULE 64 ЯК ОСТАННЬОГО ЗАВДАННЯ ==="

mkdir -p \
  data/cybra_finance/it_department/tasks \
  data/cybra_task_dispatch/locked \
  data/cybra_task_dispatch/audit \
  data/cybra_task_dispatch/actions \
  data/cybra_meta_evolution/tasks \
  parliament/inbox \
  posts feeds proofs runtime/redis

python3 - <<'PY'
import json, time, hashlib, subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"

def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S")

def sha256_file(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def write_json(p, data):
    p = Path(p)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

def write_text(p, text):
    Path(p).parent.mkdir(parents=True, exist_ok=True)
    Path(p).write_text(text, encoding="utf-8")

def redis_push(queue, payload):
    try:
        subprocess.run(
            "redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir runtime/redis --save '' --appendonly no >/dev/null 2>&1",
            shell=True, cwd=ROOT
        )
        return subprocess.run(["redis-cli", "LPUSH", queue, json.dumps(payload, ensure_ascii=False)],
                              cwd=ROOT, capture_output=True).returncode == 0
    except Exception:
        return False

# Знайти всі файли модуля 64
files = []
for pattern in ["**/module_64_part_*.mjs", "**/module_64*/INDEX.md", "**/Module 64/INDEX.md"]:
    files.extend([p for p in Path.home().glob(pattern) if p.is_file()])

# Унікальні файли
unique = []
seen = set()
for p in files:
    if str(p) not in seen:
        seen.add(str(p))
        unique.append(p)

# Аналіз кожного файла
module_files = []
for p in unique:
    try:
        txt = p.read_text(encoding="utf-8", errors="ignore")
        module_files.append({
            "path": str(p),
            "relative_to_home": str(p.relative_to(Path.home())),
            "size_bytes": p.stat().st_size,
            "sha256": sha256_file(p),
            "lines": len(txt.splitlines()),
            "danger_words": [w for w in ["FORCE_TRADE","ACTIVE","NO_WINDOW","order","trade","bybit","leverage"]
                            if w.lower() in txt.lower() or w.lower() in p.name.lower()]
        })
    except Exception as e:
        module_files.append({"path": str(p), "error": str(e)})

# Формування завдання
task_id = f"MODULE-64-FINANCE-AUDIT-{time.strftime('%Y%m%d_%H%M%S')}"
task = {
    "task_id": task_id,
    "timestamp": now(),
    "status": "MODULE_64_REGISTERED_AS_LAST_TASK_FOR_AUDIT",
    "title": "Аудит Module 64 — примусова торгівля без вікна",
    "scope": "FINANCE_TRADING_MODULE_AUDIT_ONLY",
    "module": {
        "module_number": 64,
        "name": "ULTIMATE_FORCE_TRADE_NO_WINDOW",
        "files_count": len(module_files),
        "files": module_files
    },
    "required_actions": [
        "Надіслати фінансовому комітету",
        "Надіслати комітету бінарного коду",
        "Надіслати кіберпарламенту",
        "Перевірити ризик живих ордерів",
        "Перевірити ризик примусової торгівлі без вікна",
        "Переписати в безпечний paper/testnet режим",
        "Блокувати живі ордери до ручного схвалення власником"
    ],
    "routing": {
        "finance": "cybra:finance:evolution:pool",
        "audit": "cybra:audit:finance",
        "parliament": "parliament_inbox",
        "binary": "cybra:binary:tasks",
        "return_rework": "cybra:return:ai_tasks"
    },
    "safety": {
        "real_payment_now": False,
        "real_trading_now": False,
        "live_orders_enabled": False,
        "automatic_external_tx": False,
        "automatic_withdrawals": False,
        "automatic_SWIFT": False,
        "automatic_real_rewards": False,
        "force_trade_blocked_until_audit": True,
        "manual_OWNER_approval_required": True,
        "do_not_store_secrets_in_git": True
    }
}
task["sha256"] = hashlib.sha256(json.dumps(task, ensure_ascii=False, sort_keys=True).encode()).hexdigest()

# Збереження файлів
write_json(ROOT / "data/cybra_finance/it_department/tasks" / f"{task_id}.json", task)
write_json(ROOT / "data/cybra_task_dispatch/locked/last_task_lock.json", {
    "timestamp": now(), "locked": True, "task_id": task_id, "title": task["title"],
    "status": task["status"], "source": f"data/cybra_finance/it_department/tasks/{task_id}.json",
    "sha256": task["sha256"], "rule": "Module 64 — заблоковане останнє завдання"
})
write_json(ROOT / "data/cybra_task_dispatch/audit/module_64_audit_latest.json", {
    "timestamp": now(), "status": "MODULE_64_AUDIT_CREATED", "task_id": task_id,
    "risk": "force trade / no window / active trading module",
    "audit_advice": [
        "❌ Не запускати live-торгівлю",
        "🔍 Перевірити створення реальних ордерів",
        "🔑 API keys / secrets — не в git",
        "✏️ Переписати в paper/testnet режим",
        "✅ Додати ручне підтвердження OWNER",
        "📦 Підключити binary committee"
    ],
    "task_file": f"data/cybra_finance/it_department/tasks/{task_id}.json",
    "safety": task["safety"]
})

# Розсилка в черги Redis
for q in ["cybra:finance:evolution:pool", "cybra:audit:finance", "parliament_inbox",
          "cybra:binary:tasks", "cybra:meta:evolution:pool"]:
    redis_push(q, task)

# Пост і фід
write_text(ROOT / "posts/module_64_last_task.md",
    f"# Module 64 — останнє завдання\n\n**Статус:** MODULE_64_REGISTERED_AS_LAST_TASK_FOR_AUDIT\n\n"
    f"**ID:** `{task_id}`\n**Модуль:** ULTIMATE_FORCE_TRADE_NO_WINDOW\n**Знайдено файлів:** {len(module_files)}\n\n"
    f"## Блокування\n- real_trading_now: false\n- live_orders_enabled: false\n- force_trade_blocked_until_audit: true\n"
    f"- manual_OWNER_approval_required: true\n\n## Команди\n```bash\ncybra-last-task-bar status\ncybra-last-task-bar audit\n"
    f"cybra-last-task-bar merge\ncybra-last-task-bar committees\ncybra-last-task-bar auto\n```")
write_json(ROOT / "feeds/module_64_last_task.json", task)

# Докази (SHA256)
proof_lines = []
for p in [ROOT / f"data/cybra_finance/it_department/tasks/{task_id}.json",
          ROOT / "data/cybra_task_dispatch/locked/last_task_lock.json",
          ROOT / "data/cybra_task_dispatch/audit/module_64_audit_latest.json",
          ROOT / "posts/module_64_last_task.md",
          ROOT / "feeds/module_64_last_task.json"]:
    proof_lines.append(f"{sha256_file(p)}  {p.relative_to(ROOT)}")
write_text(ROOT / "proofs/module_64_last_task.sha256", "\n".join(proof_lines))

print(json.dumps({"status": "MODULE_64_LOCKED_AS_LAST_TASK", "task_id": task_id,
                  "files_found": len(module_files), "task_file": f"data/cybra_finance/it_department/tasks/{task_id}.json",
                  "lock_file": "data/cybra_task_dispatch/locked/last_task_lock.json",
                  "next": ["cybra-last-task-bar status", "cybra-last-task-bar audit", "cybra-last-task-bar merge",
                           "cybra-last-task-bar committees", "cybra-last-task-bar auto"]}, ensure_ascii=False, indent=2))
PY

sha256sum -c proofs/module_64_last_task.sha256
