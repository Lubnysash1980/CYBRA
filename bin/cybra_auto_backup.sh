#!/data/data/com.termux/files/usr/bin/bash
# CYBRA AUTO BACKUP
ROOT="$HOME/CYBRA"
BK_DIR="$ROOT/backups"
mkdir -p "$BK_DIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
ARCHIVE="$BK_DIR/cybra_${STAMP}.tar.gz"
tar -czf "$ARCHIVE" \
    -C "$(dirname "$ROOT")" \
    --exclude='*/node_modules' \
    --exclude='*/backups' \
    --exclude='*/.git' \
    "$(basename "$ROOT")" 2>/dev/null
sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"
# Ротація: залишаємо 30 останніх
ls -t "$BK_DIR"/cybra_*.tar.gz 2>/dev/null | tail -n +31 | xargs -r rm -f
ls -t "$BK_DIR"/cybra_*.tar.gz.sha256 2>/dev/null | tail -n +31 | xargs -r rm -f
printf 'Backup: %s\n' "$ARCHIVE"
printf 'Size:   %s\n' "$(du -h "$ARCHIVE" | cut -f1)"
printf 'Hash:   %s\n' "$(cat "$ARCHIVE.sha256" | awk '{print $1}' | head -c 16)..."
