#!/data/data/com.termux/files/usr/bin/bash
set +e

ROOT="$HOME/CYBRA"
cd "$ROOT" || exit 1

NAME="$1"
INTERVAL="$2"
shift 2
CMD="$*"

PID_DIR="$ROOT/runtime/cybra_bg/pids"
LOCK_DIR="$ROOT/runtime/cybra_bg/locks"
LOG_DIR="$ROOT/logs/background"

mkdir -p "$PID_DIR" "$LOCK_DIR" "$LOG_DIR"

echo $$ > "$PID_DIR/$NAME.pid"

export CYBRA_BACKGROUND=1
export REAL_PAYMENT_NOW=false
export AUTOMATIC_SWIFT=false
export AUTOMATIC_EXTERNAL_TX=false
export CYBRA_MAINNET_DEPLOY_ALLOWED=false
export CYBRA_SAFE_MODE=true

echo "[$(date)] worker=$NAME started interval=$INTERVAL"
echo "CMD=$CMD"

while true; do
  if mkdir "$LOCK_DIR/$NAME.lock" 2>/dev/null; then
    echo
    echo "[$(date)] worker=$NAME cycle start"

    bash -lc "$CMD"
    CODE=$?

    echo "[$(date)] worker=$NAME cycle end code=$CODE"
    rmdir "$LOCK_DIR/$NAME.lock" 2>/dev/null || true
  else
    echo "[$(date)] worker=$NAME previous cycle still running, skip"
  fi

  sleep "$INTERVAL"
done
