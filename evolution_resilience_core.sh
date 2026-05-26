#!/data/data/com.termux/files/usr/bin/bash
set -e

BASE="$HOME/CYBRA"
mkdir -p modules/evolution posts proofs backups/evolution quarantine/evolution logs/evolution registry/evolution

cat > registry/evolution/resilience_policy.json <<'JSON'
{
  "mode": "evolution_resilience",
  "rules": [
    "never_delete_without_backup",
    "double_sha_every_change",
    "quarantine_broken_files",
    "rollback_on_failure",
    "preserve_working_state",
    "no_degradation",
    "audit_required"
  ],
  "status": "active"
}
JSON

cat > modules/evolution/resilience_core.py <<'PY'
import hashlib, json, shutil, time
from pathlib import Path

BASE = Path.home() / "CYBRA"
WATCH = ["parliament_executor_v6.py", "cybra_autofix.sh", "ai_research_backend.sh", "cybra_mining_autofix.sh"]

def dsha(p):
    raw = p.read_bytes()
    return hashlib.sha256(hashlib.sha256(raw).digest()).hexdigest()

report = {"time": time.time(), "checked": {}, "status": "ok"}

for name in WATCH:
    p = BASE / name
    if not p.exists():
        report["checked"][name] = "missing"
        continue

    h = dsha(p)
    b = BASE / "backups/evolution" / f"{name}.{h}.bak"
    b.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(p, b)
    report["checked"][name] = {"double_sha": h, "backup": str(b)}

raw = json.dumps(report, ensure_ascii=False, indent=2)
(BASE / "logs/evolution/resilience_report.json").write_text(raw, encoding="utf-8")
(BASE / "proofs/evolution_resilience.sha256").write_text(hashlib.sha256(raw.encode()).hexdigest(), encoding="utf-8")
(BASE / "posts/evolution_resilience_status.md").write_text("# CYBRA Evolution Resilience\n\nStatus: active\n", encoding="utf-8")
print(raw)
PY

python3 modules/evolution/resilience_core.py

git add modules registry posts proofs backups/evolution logs/evolution evolution_resilience_core.sh
git commit -m "add evolution resilience core" || true

echo "✅ Evolution resilience core active"
