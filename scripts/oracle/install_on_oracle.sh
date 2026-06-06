#!/usr/bin/env bash
set +e

REPO="${REPO:-https://github.com/Lubnysash1980/CYBRA.git}"
DIR="${DIR:-$HOME/CYBRA}"

echo "=== INSTALL CYBRA ON ORACLE VPS ==="

if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update -y || true
  sudo apt-get install -y git python3 python3-pip curl jq nodejs npm redis-server || true
fi

if [ ! -d "$DIR/.git" ]; then
  git clone "$REPO" "$DIR" || exit 1
fi

cd "$DIR" || exit 1
git pull --rebase origin main || true

mkdir -p logs/oracle runtime data/cybra_oracle/reports public/cybra_oracle_dashboard

bash scripts/oracle/cybra_oracle_start.sh

echo "✅ Oracle VPS installed and running"
echo "Dashboard: http://SERVER_IP:8099/"
