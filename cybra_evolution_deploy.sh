#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

CMD="${1:-status}"
shift || true

case "$CMD" in
  report)
    python3 cybra_evolution_deployment.py report
    cat posts/evolution_deployment_report.md
    ;;
  develop)
    python3 cybra_evolution_deployment.py develop
    ;;
  cycle)
    python3 cybra_evolution_deployment.py develop

    for i in $(seq 1 30); do
      echo "round=$i queue=$(redis-cli LLEN cybra:parliament:queue)"
      python3 parliament_executor_v6.py || true
      sleep 1
      [ "$(redis-cli LLEN cybra:parliament:queue)" = "0" ] && break
    done

    bash cybra_monetization.sh report >/dev/null 2>&1 || true
    bash cybra_kibra_chain.sh verify >/dev/null 2>&1 || true
    bash cybra_kibra_chain.sh report >/dev/null 2>&1 || true
    bash cybra_finance.sh report >/dev/null 2>&1 || true
    bash cybra_hash_test.sh run >/dev/null 2>&1 || true
    bash cybra_institution.sh check >/dev/null 2>&1 || true
    bash review_kibra_parliament_response.sh >/dev/null 2>&1 || true

    python3 cybra_evolution_deployment.py report
    cat posts/evolution_deployment_report.md
    ;;
  loop)
    N="${1:-3}"
    for i in $(seq 1 "$N"); do
      echo "=== EVOLUTION CYCLE $i/$N ==="
      bash cybra_evolution_deploy.sh cycle
      sleep 2
    done
    ;;
  task)
    cybra parliament '{"topic":"CYBRA Evolution Deployment Cycle","type":"evolution_deployment_task","priority":"critical","payload":{"mode":"safe_growth_orchestrator","real_payment_execution":false,"automatic_external_tx":false,"manual_owner_approval_required":true}}'
    ;;
  status)
    redis-cli ping
    echo "EVOLUTION_DEPLOYMENT_AUDIT: $(redis-cli LLEN cybra:evolution_deployment:audit)"
    echo "EVOLUTION_DEPLOYMENT_ROADMAP: $(redis-cli LLEN cybra:evolution_deployment:roadmap)"
    echo "EVOLUTION_DEPLOYMENT_TASKS: $(redis-cli LLEN cybra:evolution_deployment:tasks)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    echo "PARLIAMENT_FAILED: $(redis-cli LLEN cybra:parliament:failed)"
    test -f posts/evolution_deployment_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  audit)
    redis-cli LRANGE cybra:evolution_deployment:audit 0 20
    ;;
  roadmap)
    redis-cli LRANGE cybra:evolution_deployment:roadmap 0 10
    ;;
  proof)
    cat proofs/evolution_deployment.sha256
    ;;
  feed)
    cat feeds/evolution_deployment_report.json
    ;;
  *)
    echo "Usage: bash cybra_evolution_deploy.sh report|develop|cycle|loop [n]|task|status|audit|roadmap|feed|proof"
    ;;
esac
