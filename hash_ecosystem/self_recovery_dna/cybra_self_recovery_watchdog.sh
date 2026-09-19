#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOT="$HOME/CYBRA"

NODE_START="$ROOT/node_cybra/bin/cybra_node_start.sh"
STATE_DIR="$ROOT/node_cybra/state"

IT_PID="$STATE_DIR/it_analysis_worker.pid"
RECOVERY_PID="$STATE_DIR/recovery.pid"

LOG_DIR="$ROOT/node_cybra/logs"
WATCHDOG_LOG="$LOG_DIR/self_recovery_watchdog.log"
STATUS="$ROOT/hash_ecosystem/self_recovery_dna/watchdog_status.json"

mkdir -p "$LOG_DIR"

log(){
    printf '[%s] %s\n' "$(date -Iseconds)" "$*" >> "$WATCHDOG_LOG"
}

pid_alive(){
    local f="$1"

    [ -f "$f" ] || return 1

    local pid
    pid="$(cat "$f" 2>/dev/null || true)"

    [ -n "$pid" ] || return 1

    kill -0 "$pid" 2>/dev/null
}

redis_ok(){
    redis-cli PING 2>/dev/null | grep -q '^PONG$'
}

write_status(){
    local node="$1"
    local redis="$2"
    local recovery="$3"
    local worker="$4"

    cat > "$STATUS" <<JSON
{
  "component": "CYBRA_SELF_RECOVERY_WATCHDOG",
  "timestamp": "$(date -Iseconds)",
  "watchdog": "ONLINE",
  "node": "$node",
  "redis": "$redis",
  "it_analysis_worker": "$worker",
  "recovery": "$recovery",
  "physical_manufacturing": false,
  "manufacturing_execution_enabled": false,
  "rule": "TRUE_ONLY_AT_100_PERCENT_REQUIRED_CONFIRMATION"
}
JSON
}

repair_redis(){
    if redis_ok; then
        return 0
    fi

    log "REDIS_OFFLINE attempting restart"

    pkill -f 'redis-server.*127.0.0.1.*6379' 2>/dev/null || true

    redis-server \
        --bind 127.0.0.1 \
        --port 6379 \
        --daemonize yes \
        >>"$LOG_DIR/redis_watchdog.log" 2>&1 || true

    sleep 2

    if redis_ok; then
        log "REDIS_RECOVERED"
        return 0
    fi

    log "REDIS_RECOVERY_FAILED"
    return 1
}

start_node(){
    if [ ! -x "$NODE_START" ]; then
        log "NODE_START_SCRIPT_MISSING"
        return 1
    fi

    log "NODE_REPAIR_START"

    "$NODE_START" >>"$LOG_DIR/node_start.log" 2>&1 || true

    sleep 2
}

check_and_repair(){

    repair_redis || true

    local worker="OFFLINE"
    local recovery="OFFLINE"

    if pid_alive "$IT_PID"; then
        worker="ONLINE"
    fi

    if pid_alive "$RECOVERY_PID"; then
        recovery="ONLINE"
    fi

    if [ "$worker" != "ONLINE" ] || [ "$recovery" != "ONLINE" ]; then
        log "NODE_DRIFT worker=$worker recovery=$recovery"
        start_node
    fi

    sleep 1

    if pid_alive "$IT_PID"; then
        worker="ONLINE"
    else
        worker="OFFLINE"
    fi

    if pid_alive "$RECOVERY_PID"; then
        recovery="ONLINE"
    else
        recovery="OFFLINE"
    fi

    local redis="OFFLINE"

    if redis_ok; then
        redis="ONLINE"
    fi

    local node="OFFLINE"

    if [ "$worker" = "ONLINE" ] && [ "$recovery" = "ONLINE" ]; then
        node="ONLINE"
    fi

    write_status "$node" "$redis" "$recovery" "$worker"

    log "STATUS node=$node redis=$redis worker=$worker recovery=$recovery"

    if [ "$node" != "ONLINE" ] || [ "$redis" != "ONLINE" ]; then
        return 1
    fi

    return 0
}

log "WATCHDOG_START"

while true; do
    check_and_repair || true
    sleep 60
done
