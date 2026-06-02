#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

CMD="${1:-status}"

case "$CMD" in
  report)
    python3 cybra_kibra_market_exchange.py report
    cat posts/kibra_market_exchange_plan.md
    ;;
  submit)
    python3 cybra_kibra_market_exchange.py submit
    ;;
  cycle)
    python3 cybra_kibra_market_exchange.py cycle

    for i in $(seq 1 40); do
      echo "round=$i queue=$(redis-cli LLEN cybra:parliament:queue)"
      python3 parliament_executor_v6.py || true
      sleep 1
      [ "$(redis-cli LLEN cybra:parliament:queue)" = "0" ] && break
    done

    python3 cybra_kibra_market_exchange.py report
    cat posts/kibra_market_exchange_plan.md
    ;;
  task)
    cybra parliament '{"topic":"KIBRA Market Exchange Master Plan","type":"kibra_market_exchange_task","priority":"critical","payload":{"real_mint_readiness":true,"real_liquidity_pool_readiness":true,"market_price_engine":true,"buyers_volume_strategy":true,"sell_without_crash_model":true,"manual_OWNER_approval_required":true,"own_exchange":true,"real_execution":false}}'
    ;;
  status)
    redis-cli ping
    echo "KIBRA_MARKET_AUDIT: $(redis-cli LLEN cybra:kibra_market:audit)"
    echo "KIBRA_MARKET_TASKS: $(redis-cli LLEN cybra:kibra_market:ai_tasks)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    echo "PARLIAMENT_FAILED: $(redis-cli LLEN cybra:parliament:failed)"
    test -f posts/kibra_market_exchange_plan.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  feed)
    cat feeds/kibra_market_exchange_plan.json
    ;;
  proof)
    cat proofs/kibra_market_exchange_plan.sha256
    ;;
  architecture)
    cat data/exchange/cybra_exchange_architecture.json
    ;;
  readiness)
    cat data/kibra_market/market_readiness_plan.json
    ;;
  *)
    echo "Usage: bash cybra_kibra_market.sh report|submit|cycle|task|status|feed|proof|architecture|readiness"
    ;;
esac
