#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

mkdir -p posts feeds proofs parliament/orchestrator

cat > parliament/orchestrator/main_orchestrator_policy.json <<'JSON'
{
  "name": "CYBRA Main Orchestrator Policy",
  "status": "active",
  "main_orchestrator": "OWNER",
  "owner_role": "головний оркестратор",
  "cybra_parliament_mode": "closed_internal_self_seal",
  "rules": {
    "internal_key_hidden": true,
    "external_key_visible": true,
    "cybra_parliament_can_self_seal": true,
    "owner_is_main_orchestrator": true,
    "evolution_only": true,
    "block_degradation": true,
    "audit_required": true,
    "proof_required": true,
    "no_private_keys_in_git": true,
    "no_secret_dump": true
  }
}
JSON

cat > feeds/main_orchestrator_status.json <<'JSON'
{
  "status": "submitted",
  "topic": "CYBRA Closed Internal Self-Seal With Main Orchestrator",
  "main_orchestrator": "OWNER",
  "mode": "closed_internal_parliament",
  "evolution_only": true
}
JSON

cat > posts/main_orchestrator_status.md <<'MD'
# CYBRA Main Orchestrator

Status: submitted

Main orchestrator:
OWNER

Mode:
CYBRA Parliament closed internal self-seal

Rules:

- Кіберапарламент закривається внутрішньою печаткою.
- Внутрішній ключ не показується.
- Зовнішній ключ / SHA можна бачити.
- Головний оркестратор — OWNER.
- Рішення приймаються тільки за принципом еволюції.
- Деградаційні, небезпечні або незаконні задачі блокуються.
MD

sha256sum \
  parliament/orchestrator/main_orchestrator_policy.json \
  feeds/main_orchestrator_status.json \
  posts/main_orchestrator_status.md \
  > proofs/main_orchestrator.sha256

redis-cli HSET cybra:executor:mapping closed_evolution_selfseal_task closed_evolution_selfseal_handler.sh >/dev/null

cybra parliament '{
  "topic": "CYBRA Closed Internal Self-Seal With Main Orchestrator",
  "type": "closed_evolution_selfseal_task",
  "priority": "critical",
  "payload": {
    "mode": "closed_internal_decision",
    "main_orchestrator": "OWNER",
    "goal": "Кіберапарламент закривається всередині власною печаткою, а OWNER залишається головним оркестратором",
    "rules": [
      "internal key hidden",
      "external key visible",
      "owner is main orchestrator",
      "evolution only",
      "audit required",
      "proof required",
      "block degradation"
    ]
  }
}'

echo "✅ Closed orchestrator task submitted"
