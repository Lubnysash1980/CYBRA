#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

echo "=== CYBRA CLOSED EVOLUTION SELF-SEAL INSTALL ==="

mkdir -p \
  parliament/evolution_closed \
  private_vault/evolution_closed \
  posts feeds proofs logs/evolution_closed

chmod 700 private_vault private_vault/evolution_closed 2>/dev/null || true

touch .gitignore
grep -qxF "private_vault/" .gitignore || echo "private_vault/" >> .gitignore
grep -qxF "dump.rdb" .gitignore || echo "dump.rdb" >> .gitignore
grep -qxF "__pycache__/" .gitignore || echo "__pycache__/" >> .gitignore
grep -qxF "ai_network/" .gitignore || echo "ai_network/" >> .gitignore
grep -qxF "recovery/" .gitignore || echo "recovery/" >> .gitignore
grep -qxF "token/runtime/rpc.env" .gitignore || echo "token/runtime/rpc.env" >> .gitignore

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1
redis-cli ping >/dev/null

# 1. Зовнішній видимий ключ
if [ ! -f private_vault/evolution_closed/external_visible.token ]; then
  openssl rand -hex 24 > private_vault/evolution_closed/external_visible.token
fi

# 2. Внутрішній закритий ключ Кіберапарламенту
# Він не друкується в консоль і не пушиться в Git.
if [ ! -f private_vault/evolution_closed/internal_parliament_seal.token ]; then
  openssl rand -hex 48 > private_vault/evolution_closed/internal_parliament_seal.token
fi

chmod 600 private_vault/evolution_closed/*.token

EXTERNAL_TOKEN="$(cat private_vault/evolution_closed/external_visible.token)"
EXTERNAL_SHA="$(sha256sum private_vault/evolution_closed/external_visible.token | awk '{print $1}')"
INTERNAL_SHA="$(sha256sum private_vault/evolution_closed/internal_parliament_seal.token | awk '{print $1}')"

cat > parliament/evolution_closed/closed_evolution_policy.json <<JSON
{
  "name": "CYBRA Closed Evolution Self-Seal",
  "status": "active",
  "mode": "closed_internal_parliament_decision",
  "purpose": "Кіберапарламент сам приймає закрите еволюційне рішення, ставить внутрішню печатку і не розкриває внутрішній ключ.",
  "keys": {
    "external_visible_token": "$EXTERNAL_TOKEN",
    "external_visible_sha256": "$EXTERNAL_SHA",
    "internal_seal_sha256_only": "$INTERNAL_SHA",
    "internal_key_visible": false,
    "internal_key_git_allowed": false,
    "internal_key_location": "private_vault/evolution_closed/internal_parliament_seal.token"
  },
  "rules": {
    "accept_only_evolutionary_tasks": true,
    "block_degradation": true,
    "internal_seal_required": true,
    "external_key_visible": true,
    "internal_key_hidden": true,
    "no_private_data_in_git": true,
    "no_secret_dump": true,
    "no_payment_execution": true,
    "no_illegal_actions": true
  }
}
JSON

cat > closed_evolution_selfseal_handler.sh <<'HANDLER'
#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

mkdir -p posts feeds proofs logs/evolution_closed

INTERNAL="private_vault/evolution_closed/internal_parliament_seal.token"
EXTERNAL="private_vault/evolution_closed/external_visible.token"

if [ ! -f "$INTERNAL" ]; then
  echo "❌ internal seal token missing"
  exit 1
fi

if [ ! -f "$EXTERNAL" ]; then
  echo "❌ external visible token missing"
  exit 1
fi

TS="$(date -Iseconds)"
EXTERNAL_SHA="$(sha256sum "$EXTERNAL" | awk '{print $1}')"
INTERNAL_SHA="$(sha256sum "$INTERNAL" | awk '{print $1}')"

python3 - <<'PY'
import json
import time
import hmac
import hashlib
from pathlib import Path

internal = Path("private_vault/evolution_closed/internal_parliament_seal.token").read_text().strip().encode()
external = Path("private_vault/evolution_closed/external_visible.token").read_text().strip()

policy = json.loads(Path("parliament/evolution_closed/closed_evolution_policy.json").read_text())

decision = {
    "topic": "CYBRA Closed Evolution Self-Seal",
    "status": "sealed_by_cybra_parliament",
    "decision": "accept_only_evolutionary_development",
    "closed_mode": True,
    "internal_key_revealed": False,
    "external_visible_token": external,
    "external_visible_sha256": policy["keys"]["external_visible_sha256"],
    "internal_seal_sha256_only": policy["keys"]["internal_seal_sha256_only"],
    "rules": {
        "development_only": True,
        "block_degradation": True,
        "audit_required": True,
        "proof_required": True,
        "no_secret_dump": True,
        "no_private_data_in_git": True
    },
    "time": time.time()
}

raw = json.dumps(decision, ensure_ascii=False, sort_keys=True)
decision["closed_parliament_seal"] = hmac.new(
    internal,
    raw.encode("utf-8"),
    hashlib.sha256
).hexdigest()

decision["double_sha"] = hashlib.sha256(
    hashlib.sha256(
        json.dumps(decision, ensure_ascii=False, sort_keys=True).encode("utf-8")
    ).hexdigest().encode("utf-8")
).hexdigest()

Path("feeds/closed_evolution_selfseal.json").write_text(
    json.dumps(decision, ensure_ascii=False, indent=2)
)

md = f"""# CYBRA Closed Evolution Self-Seal

Status: **sealed_by_cybra_parliament**

Decision:
`accept_only_evolutionary_development`

Closed mode:
`true`

External visible token:
`{decision["external_visible_token"]}`

External visible SHA256:
`{decision["external_visible_sha256"]}`

Internal seal SHA256 only:
`{decision["internal_seal_sha256_only"]}`

Internal key revealed:
`false`

Closed parliament seal:
`{decision["closed_parliament_seal"]}`

Double SHA:
`{decision["double_sha"]}`

## Rule

Кіберапарламент приймає тільки ті задачі, патчі, рішення і проекти, які ведуть до розвитку системи: audit, proof, review, revision, analytics, education, safety, stability, recovery, documentation, lawful compliance.

Все, що веде до деградації, витоку секретів, незаконних дій, неконтрольованих оплат або руйнування системи — hold або reject.

## Key model

- Зовнішній ключ видимий.
- Внутрішній ключ не показується.
- У GitHub внутрішній ключ не додається.
- Назовні виходить тільки SHA і seal.
"""

Path("posts/closed_evolution_selfseal.md").write_text(md)

PY

sha256sum \
  parliament/evolution_closed/closed_evolution_policy.json \
  feeds/closed_evolution_selfseal.json \
  posts/closed_evolution_selfseal.md \
  > proofs/closed_evolution_selfseal.sha256

redis-cli LPUSH cybra:evolution_closed:audit "$(cat feeds/closed_evolution_selfseal.json)" >/dev/null

echo "✅ CLOSED EVOLUTION SELF-SEAL EXECUTED"
echo "Report: posts/closed_evolution_selfseal.md"
HANDLER

chmod +x closed_evolution_selfseal_handler.sh

redis-cli HSET cybra:executor:mapping closed_evolution_selfseal_task closed_evolution_selfseal_handler.sh >/dev/null

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
s = p.read_text()

if 'r.hget("cybra:executor:mapping", task_type)' not in s:
    old = "script_name = SCRIPT_MAP.get(task_type)"
    new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
    if old in s:
        s = s.replace(old, new, 1)

if '"closed_evolution_selfseal_task"' not in s:
    i = s.find("SCRIPT_MAP")
    j = s.find("{", i)
    if i >= 0 and j >= 0:
        s = s[:j+1] + '\n    "closed_evolution_selfseal_task": "closed_evolution_selfseal_handler.sh",' + s[j+1:]

p.write_text(s)
print("✅ closed_evolution_selfseal_task mapping ready")
PY

rm -rf __pycache__
python3 -m py_compile parliament_executor_v6.py
rm -rf __pycache__

# Виконуємо один раз напряму, щоб seal створився
bash closed_evolution_selfseal_handler.sh

# Закидаємо як таск у Кіберапарламент
cybra parliament '{"topic":"CYBRA Closed Evolution Self-Seal","type":"closed_evolution_selfseal_task","priority":"critical","payload":{"mode":"closed_internal_decision","goal":"self seal evolution-only parliament logic"}}' || true

sleep 3

echo
echo "=== CLOSED EVOLUTION STATUS ==="
cat posts/closed_evolution_selfseal.md

echo
echo "=== REDIS ==="
echo "EVOLUTION_CLOSED_AUDIT: $(redis-cli LLEN cybra:evolution_closed:audit)"
echo "MAPPING: $(redis-cli HGET cybra:executor:mapping closed_evolution_selfseal_task)"

echo
echo "=== IMPORTANT ==="
echo "Видимий зовнішній ключ:"
cat private_vault/evolution_closed/external_visible.token
echo
echo
echo "Внутрішній ключ НЕ показується. У GitHub не пушити private_vault/."
echo "Commit safe files only."
