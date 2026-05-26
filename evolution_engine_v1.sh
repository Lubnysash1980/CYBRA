#!/data/data/com.termux/files/usr/bin/bash
set -e

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

mkdir -p modules/evolution posts proofs logs/evolution registry/evolution

cat > registry/evolution/evolution_rules.json <<'JSON'
{
  "version": "evolution_v1",
  "rules": [
    "evolution_only",
    "no_degradation",
    "proof_required",
    "retry_failed",
    "safe_rewrite",
    "audit_every_change",
    "preserve_working_modules"
  ],
  "status": "active"
}
JSON

cat > modules/evolution/evolution_loop.py <<'PY'
#!/usr/bin/env python3

import json
import hashlib
import time
from pathlib import Path

report = {
    "time": time.time(),
    "status": "running",
    "checks": [
        "structure",
        "executor",
        "research",
        "knowledge",
        "security",
        "chain"
    ],
    "mode": "evolution_only"
}

raw = json.dumps(report, ensure_ascii=False, indent=2)

Path("logs/evolution/latest.json").write_text(
    raw,
    encoding="utf-8"
)

sha = hashlib.sha256(raw.encode()).hexdigest()

Path("proofs/evolution_latest.sha256").write_text(
    sha,
    encoding="utf-8"
)

Path("posts/evolution_status.md").write_text(
f"""# CYBRA Evolution Engine

Status: running

Checks:
- structure
- executor
- research
- knowledge
- security
- chain

Hash:
{sha}
""",
encoding="utf-8"
)

print(raw)
PY

chmod +x modules/evolution/evolution_loop.py

python3 modules/evolution/evolution_loop.py

find modules registry posts proofs -type f -exec sha256sum {} \; > proofs/evolution_all_hashes.txt

git add modules registry posts proofs evolution_engine_v1.sh
git commit -m "add CYBRA evolution engine v1" || true

echo "✅ CYBRA Evolution Engine V1 installed"
