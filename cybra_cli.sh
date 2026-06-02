#!/data/data/com.termux/files/usr/bin/bash

ensure_redis() {
  redis-cli ping >/dev/null 2>&1 || {
    redis-server --daemonize yes >/dev/null 2>&1
    sleep 1
  }
}

cd "$HOME/CYBRA" || exit 1

case "$1" in
  parliament|task)
    ensure_redis
    shift
    redis-cli lpush cybra:parliament:submissions "$*"
    echo "✅ Parliament task submitted"
    ;;

  status)
    ensure_redis
    echo "QUEUE: $(redis-cli llen cybra:parliament:submissions)"
    echo "RESULTS: $(redis-cli llen cybra:parliament:results)"
    echo "AUDIT: $(redis-cli llen cybra:audit)"
    ;;

  submissions)
    ensure_redis
    redis-cli --raw lrange cybra:parliament:submissions 0 -1
    ;;

  results)
    ensure_redis
    redis-cli --raw lrange cybra:parliament:results 0 -1
    ;;

  *)
    echo "cybra parliament '{...}'"
    echo "cybra status"
    echo "cybra submissions"
    echo "cybra results"
    ;;
esac
