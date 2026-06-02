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
