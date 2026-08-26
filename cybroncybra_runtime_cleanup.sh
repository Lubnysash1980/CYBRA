#!/data/data/com.termux/files/usr/bin/bash

set -u

ROOT="$HOME/CYBRA"
RUNTIME="$ROOT/runtime"
KEEP=1

echo "=============================================="
echo " CYBRONCYBRA RUNTIME CLEANUP"
echo "=============================================="
echo

echo "[BEFORE]"
du -sh "$RUNTIME" 2>/dev/null || true
df -h "$HOME"

echo
echo "[CLEAN] Removing generated runtime history..."

for d in \
  "$RUNTIME/backup" \
  "$RUNTIME/cybroncybra_autopilot" \
  "$RUNTIME/cybroncybra_auto" \
  "$RUNTIME/cybroncybra_autofix" \
  "$RUNTIME/cybroncybra_oracle" \
  "$RUNTIME/cybroncybra_integration"
do
    if [ -d "$d" ]; then
        echo "[REMOVE] $d"
        rm -rf "$d"
    fi
done

echo
echo "[CLEAN] Removing temporary archive/cache files..."

find "$RUNTIME" -type f \
  \( -name '*.tar' -o -name '*.tar.gz' -o -name '*.zip' -o -name '*.tmp' \) \
  -delete 2>/dev/null || true

echo
echo "[AFTER]"
du -sh "$RUNTIME" 2>/dev/null || true
df -h "$HOME"

echo
echo "=============================================="
echo " CLEANUP COMPLETE"
echo "=============================================="
