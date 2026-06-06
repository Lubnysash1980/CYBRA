#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p registry/evolution posts proofs

cat > registry/evolution/evolution_lock.json <<'JSON'
{
  "evolution": "protected",
  "liquidation": "blocked",
  "rules": [
    "do_not_delete_working_modules",
    "backup_before_change",
    "quarantine_instead_delete",
    "rollback_if_failed",
    "only_upgrade",
    "no_degradation"
  ],
  "status": "locked"
}
JSON

sha256sum registry/evolution/evolution_lock.json > proofs/evolution_lock.sha256

cat > posts/evolution_lock_status.md <<'MD'
# CYBRA Evolution Lock

Evolution protected.

Liquidation: blocked.  
Mode: upgrade only.  
Delete: forbidden without backup/quarantine.
MD

git add registry/evolution/evolution_lock.json proofs/evolution_lock.sha256 posts/evolution_lock_status.md
git commit -m "protect evolution from liquidation" || true

echo "✅ Evolution protected from liquidation"
