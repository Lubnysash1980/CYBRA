#!/data/data/com.termux/files/usr/bin/bash

BASE="$HOME/CYBRA"
cd "$BASE" || exit 1

while true; do
  echo "=== CYBRA SYNC $(date) ==="

  git pull --rebase || true

  git add remote_queue remote_results remote_logs proofs token_files site native_tokens posts registry 2>/dev/null || true

  if ! git diff --cached --quiet; then
    git commit -m "CYBRA auto sync $(date -Iseconds)" || true
    git push || true
  fi

  sleep 60
done
