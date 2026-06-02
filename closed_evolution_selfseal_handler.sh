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
