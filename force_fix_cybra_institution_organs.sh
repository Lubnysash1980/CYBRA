#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

echo "=== FORCE FIX CYBRA INSTITUTION ORGANS ==="

mkdir -p \
  parliament/institution \
  parliament/review \
  parliament/revision \
  parliament/analytics \
  parliament/education \
  parliament/evo \
  parliament/evolution \
  parliament/audit \
  parliament/protection \
  parliament/departments \
  parliament/committees \
  posts feeds proofs logs/institution

python3 - <<'PY'
import json, time, hashlib, subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"

ORGANS = {
    "institution": "Головний інституційний контроль Кіберапарламенту",
    "review": "Перевірка задач перед виконанням",
    "revision": "Ревізія задач, результатів, audit, mapping, proof",
    "analytics": "Аналітика роботи Кіберапарламенту",
    "education": "Освіта, інструкції, документація",
    "evo": "Створення нових комітетів і розвиток",
    "evolution": "Фільтр розвитку проти деградації",
    "audit": "Audit, dedupe, tag logging, fingerprints",
    "protection": "Захист Git, runtime, secrets, private vault",
    "departments": "Департаменти підтримки платформи",
    "committees": "Комітети під типи задач"
}

def dsha(x):
    h1 = hashlib.sha256(x.encode("utf-8")).hexdigest()
    return hashlib.sha256(h1.encode("utf-8")).hexdigest()

created = []

for name, purpose in ORGANS.items():
    base = ROOT / "parliament" / name
    base.mkdir(parents=True, exist_ok=True)

    obj = {
        "organ": name,
        "status": "active",
        "purpose": purpose,
        "created_or_checked_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "rules": [
            "audit_required",
            "proof_required",
            "evolution_only",
            "block_degradation",
            "no_private_keys",
            "no_secret_dump",
            "no_uncontrolled_payments"
        ]
    }

    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))

    (base / "organ.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
    (base / "README.md").write_text(
        f"# CYBRA Parliament Organ: {name}\n\n"
        f"Status: active\n\n"
        f"Purpose:\n{purpose}\n\n"
        f"Double SHA:\n`{obj['double_sha']}`\n",
        encoding="utf-8"
    )

    created.append(obj)

report = {
    "status": "force_institution_organs_created",
    "time": time.time(),
    "organs": created
}

report["double_sha"] = dsha(json.dumps(report, ensure_ascii=False, sort_keys=True))

(ROOT / "feeds/force_institution_organs.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2),
    encoding="utf-8"
)

(ROOT / "posts/force_institution_organs.md").write_text(
    "# CYBRA Force Institution Organs\n\n"
    f"Status: force_institution_organs_created\n\n"
    f"Organs created/checked: {len(created)}\n\n"
    f"Double SHA: `{report['double_sha']}`\n",
    encoding="utf-8"
)

with (ROOT / "proofs/force_institution_organs.sha256").open("w") as f:
    subprocess.run(
        [
            "sha256sum",
            "feeds/force_institution_organs.json",
            "posts/force_institution_organs.md"
        ],
        cwd=ROOT,
        stdout=f,
        stderr=subprocess.DEVNULL
    )

print("✅ base organs created/checked:", len(created))
PY

if [ -f cybra_institution.sh ]; then
  bash cybra_institution.sh repair || true
  bash cybra_institution.sh check || true
else
  echo "⚠ cybra_institution.sh not found"
fi

echo
echo "=== CHECK ORGANS ==="
for d in institution review revision analytics education evo evolution audit protection departments committees; do
  if [ -d "parliament/$d" ]; then
    echo "✅ parliament/$d"
  else
    echo "❌ parliament/$d"
  fi
done

echo
echo "=== REPORT CHECK ==="
grep -n "Missing organs\|Task types without committee\|critical\|Recommendations" posts/institution_audit_report.md 2>/dev/null || true

echo
echo "=== DONE ==="
