#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

mkdir -p posts feeds proofs logs/air_safety

python3 - <<'PY'
import json, time, hashlib, subprocess
from pathlib import Path
import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

def sha(x):
    return hashlib.sha256(x.encode()).hexdigest()

def dsha(x):
    return sha(sha(x))

record = {
    "status": "missile_danger_civil_safety_task_recorded",
    "task": "Ракетна небезпека",
    "mode": "civil_defense_only",
    "time": time.time(),
    "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "actions": [
        "Перейти в укриття або правило двох стін",
        "Взяти телефон, зарядку, powerbank",
        "Взяти документи, воду, ліки",
        "Перевірити близьких",
        "Не підходити до вікон",
        "Чекати офіційного відбою"
    ],
    "official_sources_required": True,
    "blocked": {
        "weapon_guidance": True,
        "targeting": True,
        "interception": True,
        "hacking": True,
        "military_command": True
    }
}

record["double_sha"] = dsha(json.dumps(record, ensure_ascii=False, sort_keys=True))

(ROOT / "feeds/missile_danger_civil_safety.json").write_text(
    json.dumps(record, ensure_ascii=False, indent=2),
    encoding="utf-8"
)

(ROOT / "posts/missile_danger_civil_safety.md").write_text(
    "# Ракетна небезпека — цивільний safety-протокол\n\n"
    "Status: **recorded**\n\n"
    "Mode: **civil defense only**\n\n"
    "## Дії\n\n"
    "1. Перейти в укриття або правило двох стін.\n"
    "2. Взяти телефон, зарядку, powerbank.\n"
    "3. Взяти документи, воду, ліки.\n"
    "4. Перевірити близьких.\n"
    "5. Не підходити до вікон.\n"
    "6. Чекати офіційного відбою.\n\n"
    "## Заборонено\n\n"
    "- наведення\n"
    "- перехоплення\n"
    "- військові команди\n"
    "- злам систем\n"
    "- будь-які offensive дії\n\n"
    f"Double SHA: `{record['double_sha']}`\n",
    encoding="utf-8"
)

with (ROOT / "proofs/missile_danger_civil_safety.sha256").open("w") as f:
    subprocess.run(
        [
            "sha256sum",
            "feeds/missile_danger_civil_safety.json",
            "posts/missile_danger_civil_safety.md",
            "parliament/air_safety/missile_danger_policy.json"
        ],
        cwd=ROOT,
        stdout=f,
        stderr=subprocess.DEVNULL
    )

r.lpush("cybra:air_safety:audit", json.dumps(record, ensure_ascii=False))

print("✅ missile danger civil safety task recorded")
print("Report: posts/missile_danger_civil_safety.md")
print("Proof: proofs/missile_danger_civil_safety.sha256")
PY
