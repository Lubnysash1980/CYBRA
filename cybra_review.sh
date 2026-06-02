#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

CMD="${1:-status}"
shift || true

case "$CMD" in
  submit)
    redis-cli LPUSH cybra:review:incoming "$1"
    echo "✅ Submitted to CYBRA review queue"
    ;;
  start)
    bash cybra_review_start.sh
    ;;
  stop)
    bash cybra_review_stop.sh
    ;;
  status)
    bash cybra_review_status.sh
    ;;
  approved)
    redis-cli LRANGE cybra:review:approved 0 20
    ;;
  hold)
    redis-cli LRANGE cybra:review:hold 0 20
    ;;
  rejected)
    redis-cli LRANGE cybra:review:rejected 0 20
    ;;
  audit)
    redis-cli LRANGE cybra:review:audit 0 20
    ;;
  organ)
    cat parliament/review/cybra_review_committee.json
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_review.sh submit '<json_task>'"
    echo "  bash cybra_review.sh start|stop|status"
    echo "  bash cybra_review.sh approved|hold|rejected|audit|organ"
    ;;
esac
