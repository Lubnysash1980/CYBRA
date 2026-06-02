#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

echo "=== INSTALL AIR / MISSILE DANGER AI TASK ==="

mkdir -p \
  parliament/air_safety \
  parliament/departments/air_safety_department \
  posts feeds proofs logs/air_safety

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes || true
sleep 1

cat > parliament/departments/air_safety_department/department.json <<'JSON'
{
  "department_id": "air_safety_department",
  "name": "CYBRA Air Safety Department",
  "status": "active",
  "mission": "Цивільне реагування на повітряну / ракетну небезпеку: попередження, укриття, чекліст, зв'язок, журнал подій.",
  "allowed": [
    "civilian_alert_record",
    "shelter_checklist",
    "family_contact_check",
    "powerbank_water_documents_check",
    "official_sources_reminder",
    "audit_log"
  ],
  "blocked": [
    "weapon_guidance",
    "targeting",
    "interception",
    "military_command",
    "hacking",
    "tracking_enemy_assets"
  ]
}
JSON

cat > parliament/air_safety/missile_danger_policy.json <<'JSON'
{
  "name": "Missile Danger Civil Safety Policy",
  "status": "active",
  "mode": "civil_defense_only",
  "task": "Ракетна небезпека",
  "rules": {
    "use_official_alert_sources": true,
    "go_to_shelter": true,
    "do_not_ignore_alert": true,
    "no_military_actions": true,
    "no_weapon_guidance": true,
    "no_targeting": true
  },
  "checklist": [
    "Перейти в укриття або правило двох стін",
    "Взяти телефон, зарядку, powerbank",
    "Взяти документи, воду, ліки",
    "Перевірити близьких",
    "Не підходити до вікон",
    "Чекати офіційного відбою"
  ]
}
JSON

cat > air_missile_danger_handler.sh <<'EOF2'
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
EOF2

chmod +x air_missile_danger_handler.sh

redis-cli HSET cybra:executor:mapping air_missile_danger_task air_missile_danger_handler.sh >/dev/null

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
s = p.read_text()

if 'r.hget("cybra:executor:mapping", task_type)' not in s:
    old = "script_name = SCRIPT_MAP.get(task_type)"
    new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
    if old in s:
        s = s.replace(old, new, 1)

if '"air_missile_danger_task"' not in s:
    i = s.find("SCRIPT_MAP")
    j = s.find("{", i)
    if i >= 0 and j >= 0:
        s = s[:j+1] + '\n    "air_missile_danger_task": "air_missile_danger_handler.sh",' + s[j+1:]

p.write_text(s)
print("✅ air_missile_danger_task mapping ready")
PY

python3 -m py_compile parliament_executor_v6.py

echo
echo "=== ADD AI TASK TO PARLIAMENT ==="

cybra parliament '{
  "topic":"Ракетна небезпека",
  "type":"air_missile_danger_task",
  "priority":"critical",
  "payload":{
    "mode":"civil_defense_only",
    "support_ai_parliament":true,
    "official_sources_required":true,
    "shelter_checklist":true,
    "family_contact_check":true,
    "no_weapon_guidance":true,
    "no_targeting":true,
    "no_interception":true,
    "no_hacking":true
  }
}'

echo
echo "=== EXECUTE ==="
python3 parliament_executor_v6.py || true

echo
echo "=== STATUS ==="
echo "AIR_SAFETY_AUDIT: $(redis-cli LLEN cybra:air_safety:audit)"
echo "QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
echo "FAILED: $(redis-cli LLEN cybra:parliament:failed)"
sha256sum -c proofs/missile_danger_civil_safety.sha256 || true

echo
echo "✅ AIR / MISSILE DANGER AI TASK INSTALLED"
