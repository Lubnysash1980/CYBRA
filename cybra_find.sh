#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/CYBRA" || exit 1

QUERY="$1"

if [ -z "$QUERY" ]; then
  echo "Usage: bash cybra_find.sh keyword"
  exit 1
fi

find . -type f \
  ! -path "./.git/*" \
  ! -path "./logs/*" \
  | grep -i "$QUERY" || true
