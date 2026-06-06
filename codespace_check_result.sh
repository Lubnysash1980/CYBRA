#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"
ID="$1"

git pull || true

if [ -f "remote_results/$ID.result" ]; then
  echo "✅ Codespaces is working"
  cat "remote_results/$ID.result"
else
  echo "⚠️ Result not found yet"
  echo "Possible:"
  echo "- Codespaces listener is not running"
  echo "- git push/pull not synced"
  echo "- task not executed yet"
  echo
  echo "Start listener in Codespaces:"
  echo "  bash start_codespace_listener.sh"
fi
