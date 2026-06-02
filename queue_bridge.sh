#!/data/data/com.termux/files/usr/bin/bash
set -e

FROM="cybra:parliament:submissions"
TO="cybra:parliament:queue"

COUNT=0

while true; do
  ITEM=$(redis-cli rpop "$FROM")
  [ -z "$ITEM" ] && break
  redis-cli lpush "$TO" "$ITEM" >/dev/null
  COUNT=$((COUNT+1))
done

echo "✅ moved $COUNT tasks from submissions to queue"
