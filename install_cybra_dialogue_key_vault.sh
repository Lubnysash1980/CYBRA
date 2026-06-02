#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

echo "=== CYBRA DIALOGUE KEY VAULT INSTALL ==="

mkdir -p parliament/dialogue posts feeds proofs private_vault/dialogue logs/dialogue handlers

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

# Захист від випадкового пушу приватних даних
touch .gitignore
grep -qxF "private_vault/" .gitignore || echo "private_vault/" >> .gitignore
grep -qxF "token/runtime/rpc.env" .gitignore || echo "token/runtime/rpc.env" >> .gitignore
grep -qxF "dump.rdb" .gitignore || echo "dump.rdb" >> .gitignore
grep -qxF "ai_network/" .gitignore || echo "ai_network/" >> .gitignore

DIALOGUE_ID="CYBRA_DIALOGUE_$(date +%Y%m%d_%H%M%S)_$(openssl rand -hex 4 2>/dev/null || date +%s)"
PRIVATE_JSON="private_vault/dialogue/${DIALOGUE_ID}.private.json"
PRIVATE_ENC="private_vault/dialogue/${DIALOGUE_ID}.private.json.enc"

echo
echo "Введи ПІБ локально. Не буде пушитись у GitHub."
read -r -p "ПІБ: " CYBRA_FULL_NAME

echo
echo "Введи ІНН/ідентифікатор локально. Не буде видно на екрані і не буде пушитись."
read -s -r -p "ІНН/ID: " CYBRA_PRIVATE_ID
echo

echo
echo "Створи пароль для шифрування vault. Його НЕ буде збережено."
read -s -r -p "Vault password: " CYBRA_VAULT_PASS
echo

export CYBRA_FULL_NAME
export CYBRA_PRIVATE_ID
export CYBRA_VAULT_PASS
export DIALOGUE_ID
export PRIVATE_JSON
export PRIVATE_ENC

python3 - <<'PY'
import json, os, time
from pathlib import Path

payload = {
    "dialogue_id": os.environ["DIALOGUE_ID"],
    "status": "private_encrypted_dialogue_record",
    "owner_identity": {
        "full_name": os.environ.get("CYBRA_FULL_NAME", ""),
        "private_id": os.environ.get("CYBRA_PRIVATE_ID", "")
    },
    "proposal_terms": {
        "personal_share_percent_requested": 40,
        "additional_reserved_percent_requested": 40,
        "remaining_percent_subject_to_legal_review": 20,
        "legal_status": "proposal_only_not_contract"
    },
    "timeline": {
        "target_months": 2,
        "mode": "step_by_step_dialogue_and_legal_review"
    },
    "allowed_scope": [
        "legal discussion",
        "official channel preparation",
        "budget risk discussion without payment execution",
        "dialogue history preservation",
        "encrypted ownership/intention record",
        "compliance review"
    ],
    "blocked_scope": [
        "weapon technical development",
        "missile guidance or propulsion instructions",
        "targeting",
        "battlefield coordination",
        "procurement execution",
        "payment execution",
        "private keys or banking secrets"
    ],
    "created_at": time.time()
}

Path(os.environ["PRIVATE_JSON"]).write_text(
    json.dumps(payload, ensure_ascii=False, indent=2),
    encoding="utf-8"
)
PY

openssl enc -aes-256-cbc -pbkdf2 -salt \
  -in "$PRIVATE_JSON" \
  -out "$PRIVATE_ENC" \
  -pass env:CYBRA_VAULT_PASS

PRIVATE_SHA="$(sha256sum "$PRIVATE_ENC" | awk '{print $1}')"

rm -f "$PRIVATE_JSON"
unset CYBRA_VAULT_PASS
unset CYBRA_PRIVATE_ID

cat > parliament/dialogue/dialogue_policy.json <<JSON
{
  "name": "CYBRA Dialogue Key Policy",
  "status": "active",
  "dialogue_id": "$DIALOGUE_ID",
  "purpose": "Зберегти зашифрований ключ діалогу, умови 40/40, локальні приватні дані та правовий маршрут без технічної зброярської реалізації.",
  "private_payload": "private_vault/dialogue/${DIALOGUE_ID}.private.json.enc",
  "private_payload_sha256": "$PRIVATE_SHA",
  "rules": {
    "no_private_data_in_git": true,
    "no_payment_execution": true,
    "no_weapon_development": true,
    "legal_dialogue_only": true,
    "official_channels_required": true
  }
}
JSON

cat > feeds/dialogue_key_status.json <<JSON
{
  "status": "dialogue_key_created",
  "dialogue_id": "$DIALOGUE_ID",
  "private_payload_sha256": "$PRIVATE_SHA",
  "private_data_location": "private_vault/dialogue/${DIALOGUE_ID}.private.json.enc",
  "git_safe": true,
  "scope": "legal_dialogue_and_compliance_only",
  "proposal_terms_public": {
    "personal_share_percent_requested": 40,
    "additional_reserved_percent_requested": 40,
    "timeline_target_months": 2,
    "legal_status": "proposal_only_not_contract"
  }
}
JSON

cat > posts/dialogue_key_status.md <<MD
# CYBRA Dialogue Key

Status: dialogue_key_created

Dialogue ID:
\`$DIALOGUE_ID\`

Private encrypted vault:
\`private_vault/dialogue/${DIALOGUE_ID}.private.json.enc\`

Private payload SHA256:
\`$PRIVATE_SHA\`

## Public terms

- 40% requested personal share
- 40% additional reserved share
- 20% subject to legal review
- Target: 2 months
- Status: proposal only, not contract

## Rules

- no private data in GitHub
- no payment execution
- no technical weapon development
- legal dialogue only
- official channels required
MD

cat > dialogue_key_handler.sh <<'HANDLER'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

mkdir -p posts feeds proofs logs/dialogue

TS="$(date -Iseconds)"

python3 - <<'PY'
import json
from pathlib import Path

feed = Path("feeds/dialogue_key_status.json")
data = json.loads(feed.read_text()) if feed.exists() else {"status": "missing"}

Path("posts/dialogue_key_runtime.md").write_text(
    "# CYBRA Dialogue Runtime\n\n"
    f"Status: {data.get('status')}\n\n"
    f"Dialogue ID: `{data.get('dialogue_id')}`\n\n"
    f"Scope: `{data.get('scope')}`\n\n"
    "Mode: legal dialogue and compliance only.\n",
    encoding="utf-8"
)
PY

sha256sum \
  feeds/dialogue_key_status.json \
  posts/dialogue_key_status.md \
  posts/dialogue_key_runtime.md \
  parliament/dialogue/dialogue_policy.json \
  > proofs/dialogue_key.sha256

echo "✅ DIALOGUE KEY HANDLER EXECUTED"
HANDLER

chmod +x dialogue_key_handler.sh

redis-cli HSET cybra:executor:mapping dialogue_key_task dialogue_key_handler.sh >/dev/null

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
s = p.read_text()

if 'r.hget("cybra:executor:mapping", task_type)' not in s:
    old = "script_name = SCRIPT_MAP.get(task_type)"
    new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
    if old in s:
        s = s.replace(old, new, 1)

if '"dialogue_key_task"' not in s:
    i = s.find("SCRIPT_MAP")
    j = s.find("{", i)
    if i >= 0 and j >= 0:
        s = s[:j+1] + '\n    "dialogue_key_task": "dialogue_key_handler.sh",' + s[j+1:]

p.write_text(s)
print("✅ dialogue_key_task mapping ready")
PY

rm -rf __pycache__
python3 -m py_compile parliament_executor_v6.py
rm -rf __pycache__

bash dialogue_key_handler.sh

echo
echo "=== DIALOGUE KEY CREATED ==="
cat posts/dialogue_key_status.md

echo
echo "=== IMPORTANT ==="
echo "Приватний vault НЕ пушити:"
echo "$PRIVATE_ENC"
echo
echo "Для перевірки:"
echo "cat posts/dialogue_key_status.md"
echo "cat feeds/dialogue_key_status.json"
echo "cat proofs/dialogue_key.sha256"
