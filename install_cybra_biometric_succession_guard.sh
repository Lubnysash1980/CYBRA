#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

echo "=== CYBRA BIOMETRIC SUCCESSION GUARD INSTALL ==="

mkdir -p \
  parliament/succession \
  private_vault/succession \
  posts feeds proofs logs/succession

chmod 700 private_vault private_vault/succession 2>/dev/null || true

touch .gitignore
grep -qxF "private_vault/" .gitignore || echo "private_vault/" >> .gitignore
grep -qxF "dump.rdb" .gitignore || echo "dump.rdb" >> .gitignore
grep -qxF "__pycache__/" .gitignore || echo "__pycache__/" >> .gitignore
grep -qxF "ai_network/" .gitignore || echo "ai_network/" >> .gitignore
grep -qxF "recovery/" .gitignore || echo "recovery/" >> .gitignore
grep -qxF "token/runtime/rpc.env" .gitignore || echo "token/runtime/rpc.env" >> .gitignore

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

# Зовнішній видимий ключ спадкоємності
if [ ! -f private_vault/succession/succession_external_visible.token ]; then
  openssl rand -hex 24 > private_vault/succession/succession_external_visible.token
fi

# Внутрішній закритий ключ печатки Кіберапарламенту
if [ ! -f private_vault/succession/succession_internal_seal.token ]; then
  openssl rand -hex 48 > private_vault/succession/succession_internal_seal.token
fi

chmod 600 private_vault/succession/*.token

EXTERNAL_TOKEN="$(cat private_vault/succession/succession_external_visible.token)"
EXTERNAL_SHA="$(sha256sum private_vault/succession/succession_external_visible.token | awk '{print $1}')"
INTERNAL_SHA="$(sha256sum private_vault/succession/succession_internal_seal.token | awk '{print $1}')"

cat > parliament/succession/biometric_succession_policy.json <<JSON
{
  "name": "CYBRA Biometric Succession Guard",
  "status": "active",
  "mode": "notary_and_consent_required",
  "purpose": "Захистити спадкоємність CYBRA Platform без публікації сирих біометричних даних.",
  "keys": {
    "external_visible_token": "$EXTERNAL_TOKEN",
    "external_visible_sha256": "$EXTERNAL_SHA",
    "internal_parliament_seal_sha256_only": "$INTERNAL_SHA",
    "internal_key_visible": false,
    "internal_key_git_allowed": false
  },
  "rules": {
    "raw_biometrics_in_git": false,
    "children_personal_data_in_git": false,
    "notary_verification_required": true,
    "legal_documents_required": true,
    "minor_child_guardian_consent_required": true,
    "automatic_transfer_without_legal_confirmation": false,
    "evolution_principle_required": true,
    "degradation_blocked": true
  },
  "allowed": [
    "encrypted local vault",
    "hash of notarized attestation",
    "hash of biometric attestation",
    "legal heir registry by alias",
    "notary verification status",
    "succession hold mode",
    "evolution-only access policy"
  ],
  "blocked": [
    "raw face images",
    "raw fingerprints",
    "raw DNA data",
    "public child identity data",
    "automatic biological-child determination",
    "transfer without legal confirmation",
    "private keys in GitHub"
  ]
}
JSON

cat > cybra_biometric_succession_guard.py <<'PY'
#!/usr/bin/env python3
import json
import time
import hmac
import hashlib
import subprocess
from pathlib import Path

import redis

r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

INTERNAL = Path("private_vault/succession/succession_internal_seal.token")
EXTERNAL = Path("private_vault/succession/succession_external_visible.token")

def sha256_text(x: str) -> str:
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def double_sha(x: str) -> str:
    return sha256_text(sha256_text(x))

def hmac_sha(secret: bytes, text: str) -> str:
    return hmac.new(secret, text.encode("utf-8"), hashlib.sha256).hexdigest()

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def write_outputs():
    r.ping()

    if not INTERNAL.exists():
        raise SystemExit("internal seal token missing")
    if not EXTERNAL.exists():
        raise SystemExit("external visible token missing")

    internal_secret = INTERNAL.read_text().strip().encode("utf-8")
    external_token = EXTERNAL.read_text().strip()

    policy = json.loads(Path("parliament/succession/biometric_succession_policy.json").read_text())

    state = {
        "module": "CYBRA Biometric Succession Guard",
        "status": "active",
        "mode": "hold_until_notary_and_legal_verification",
        "time": time.time(),
        "time_iso": now_iso(),
        "external_visible_token": external_token,
        "external_visible_sha256": policy["keys"]["external_visible_sha256"],
        "internal_parliament_seal_sha256_only": policy["keys"]["internal_parliament_seal_sha256_only"],
        "internal_key_revealed": False,
        "raw_biometrics_stored": False,
        "raw_children_data_stored": False,
        "inheritance_activation": {
            "automatic_transfer": False,
            "requires_notary": True,
            "requires_legal_documents": True,
            "requires_consent_if_minor": True,
            "requires_evolution_compliance": True
        },
        "successor_policy": {
            "successors": "only legally confirmed children/heirs",
            "biometric_role": "only as optional encrypted/notarized attestation hash, not as sole proof",
            "platform_mode_after_owner_death": "sealed_hold_until_notary_verification",
            "ownership_mode": "legal_successor_confirmation_required"
        },
        "evolution_rules": {
            "accept_development": True,
            "block_degradation": True,
            "audit_required": True,
            "proof_required": True,
            "education_revision_analytics_required": True
        }
    }

    raw = json.dumps(state, ensure_ascii=False, sort_keys=True)
    state["parliament_internal_seal"] = hmac_sha(internal_secret, raw)
    state["double_sha"] = double_sha(json.dumps(state, ensure_ascii=False, sort_keys=True))

    Path("feeds/biometric_succession_guard.json").write_text(
        json.dumps(state, ensure_ascii=False, indent=2)
    )

    md = f"""# CYBRA Biometric Succession Guard

Status: **active**  
Mode: **hold_until_notary_and_legal_verification**

External visible token:
`{state["external_visible_token"]}`

External visible SHA256:
`{state["external_visible_sha256"]}`

Internal parliament seal SHA256 only:
`{state["internal_parliament_seal_sha256_only"]}`

Internal key revealed:
`false`

Parliament internal seal:
`{state["parliament_internal_seal"]}`

Double SHA:
`{state["double_sha"]}`

## Головне правило

CYBRA не визначає дітей автоматично по біометрії і не передає платформу без юридичного підтвердження.

## Дозволена схема

- законні діти / законні спадкоємці;
- нотаріальна перевірка;
- документи;
- згода законних представників, якщо дитина неповнолітня;
- encrypted local vault;
- hashes / attestations замість сирих біометричних даних;
- режим `sealed_hold_until_notary_verification`.

## Заборонено

- сирі фото обличчя в GitHub;
- відбитки пальців у GitHub;
- DNA/raw genetic data у GitHub;
- публічні дані дітей;
- автоматична передача без нотаріального/правового підтвердження;
- private keys у GitHub.

## Після смерті власника

Платформа не передається автоматично. Вона переходить у режим:

`sealed_hold_until_notary_verification`

Після офіційного підтвердження спадкоємців — Кіберапарламент може відкрити режим спадкового управління за принципами еволюції.
"""

    Path("posts/biometric_succession_guard.md").write_text(md)

    with open("proofs/biometric_succession_guard.sha256", "w") as f:
        subprocess.run(
            [
                "sha256sum",
                "parliament/succession/biometric_succession_policy.json",
                "feeds/biometric_succession_guard.json",
                "posts/biometric_succession_guard.md"
            ],
            stdout=f,
            stderr=subprocess.DEVNULL
        )

    r.lpush("cybra:succession:audit", json.dumps({
        "status": "succession_guard_generated",
        "time": state["time"],
        "double_sha": state["double_sha"],
        "mode": state["mode"],
        "internal_key_revealed": False
    }, ensure_ascii=False))

    print("✅ CYBRA biometric succession guard generated")
    print("Report: posts/biometric_succession_guard.md")
    print("Feed: feeds/biometric_succession_guard.json")
    print("Proof: proofs/biometric_succession_guard.sha256")

if __name__ == "__main__":
    write_outputs()
PY

chmod +x cybra_biometric_succession_guard.py

cat > biometric_succession_handler.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"
python3 cybra_biometric_succession_guard.py
EOF2

chmod +x biometric_succession_handler.sh

cat > cybra_succession.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

CMD="${1:-status}"

case "$CMD" in
  generate)
    python3 cybra_biometric_succession_guard.py
    ;;
  task)
    cybra parliament '{"topic":"CYBRA Biometric Succession Guard","type":"biometric_succession_task","priority":"critical","payload":{"mode":"notary_legal_successor_guard"}}'
    ;;
  status)
    redis-cli ping
    echo "SUCCESSION_AUDIT: $(redis-cli LLEN cybra:succession:audit)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    test -f posts/biometric_succession_guard.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  report)
    cat posts/biometric_succession_guard.md
    ;;
  feed)
    cat feeds/biometric_succession_guard.json
    ;;
  proof)
    cat proofs/biometric_succession_guard.sha256
    ;;
  audit)
    redis-cli LRANGE cybra:succession:audit 0 20
    ;;
  *)
    echo "Usage: bash cybra_succession.sh generate|task|status|report|feed|proof|audit"
    ;;
esac
EOF2

chmod +x cybra_succession.sh

redis-cli HSET cybra:executor:mapping biometric_succession_task biometric_succession_handler.sh >/dev/null

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
s = p.read_text()

if 'r.hget("cybra:executor:mapping", task_type)' not in s:
    old = "script_name = SCRIPT_MAP.get(task_type)"
    new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
    if old in s:
        s = s.replace(old, new, 1)

if '"biometric_succession_task"' not in s:
    i = s.find("SCRIPT_MAP")
    j = s.find("{", i)
    if i >= 0 and j >= 0:
        s = s[:j+1] + '\n    "biometric_succession_task": "biometric_succession_handler.sh",' + s[j+1:]

p.write_text(s)
print("✅ biometric_succession_task mapping ready")
PY

rm -rf __pycache__
python3 -m py_compile parliament_executor_v6.py
rm -rf __pycache__

bash cybra_succession.sh generate

sha256sum \
  parliament/succession/biometric_succession_policy.json \
  cybra_biometric_succession_guard.py \
  biometric_succession_handler.sh \
  cybra_succession.sh \
  feeds/biometric_succession_guard.json \
  posts/biometric_succession_guard.md \
  > proofs/biometric_succession_guard_install.sha256

echo
echo "=== SUCCESSION STATUS ==="
bash cybra_succession.sh status

echo
echo "=== SUCCESSION REPORT PREVIEW ==="
head -100 posts/biometric_succession_guard.md

echo
echo "=== SUCCESSION MODULE INSTALLED ==="
