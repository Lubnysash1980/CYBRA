#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="$HOME/CYBRA"; cd "$ROOT"
GEN="cybra_disaster_recovery_test.sh"
REG="cybra_register_disaster_recovery_100.sh"
GEN_NEW="$GEN.hardened"
REG_NEW="$REG.hardened"

for f in "$GEN_NEW" "$REG_NEW"; do
    [ -f "$f" ] || { echo "missing: $f"; exit 1; }
done

if ! git diff --quiet -- "$GEN" "$REG"; then
    echo "REFUSE: originals have unstaged edits"
    git status --short -- "$GEN" "$REG"
    exit 1
fi

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
echo "============================================================"
echo " CYBRA DR HARDENING — APPLY"
echo "============================================================"

cp -a "$GEN" "$GEN.bak_$STAMP"
cp -a "$REG" "$REG.bak_$STAMP"
mv "$GEN_NEW" "$GEN"
mv "$REG_NEW" "$REG"
chmod +x "$GEN" "$REG"

echo "backups:"
echo "  $GEN.bak_$STAMP"
echo "  $REG.bak_$STAMP"
echo
git status --short
