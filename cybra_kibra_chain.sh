#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

CMD="${1:-status}"
shift || true

case "$CMD" in
  init)
    python3 cybra_kibra_token_chain.py init
    ;;
  mine)
    python3 cybra_kibra_token_chain.py mine "${1:-1}"
    ;;
  verify)
    python3 cybra_kibra_token_chain.py verify
    ;;
  report)
    python3 cybra_kibra_token_chain.py report
    cat posts/kibra_token_chain_status.md
    ;;
  status)
    redis-cli ping
    echo "KIBRA_AUDIT: $(redis-cli LLEN cybra:kibra_chain:audit)"
    echo "FINANCE_LEDGER: $(redis-cli LLEN cybra:finance:ledger)"
    echo "ANCHOR_QUEUE: $(redis-cli LLEN cybra:blockchain:anchor:queue)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    test -f blockchain/kibra_chain/latest.block.hash && echo "LATEST_HASH: $(cat blockchain/kibra_chain/latest.block.hash)" || echo "LATEST_HASH: missing"
    test -f posts/kibra_token_chain_status.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  task)
    python3 cybra_kibra_token_chain.py task
    ;;
  block)
    cat blockchain/kibra_chain/latest.block.json
    ;;
  hash)
    cat blockchain/kibra_chain/latest.block.hash
    ;;
  difficulty)
    tail -30 blockchain/kibra_chain/difficulty_stream.jsonl
    ;;
  anchor-queue)
    redis-cli LRANGE cybra:blockchain:anchor:queue 0 20
    ;;
  proof)
    cat proofs/kibra_token_chain.sha256
    ;;
  *)
    echo "Usage: bash cybra_kibra_chain.sh init|mine [n]|verify|report|status|task|block|hash|difficulty|anchor-queue|proof"
    ;;
esac
