#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-run}" in
  run)
    python3 cybra_hash_module_test.py
    ;;
  task)
    cybra parliament '{"topic":"CYBRA Hash Module Test","type":"hash_module_test_task","priority":"high","payload":{"mode":"double_sha_root_hash_proof_test"}}'
    ;;
  status)
    redis-cli ping
    echo "HASH_AUDIT: $(redis-cli LLEN cybra:hash:audit)"
    test -f posts/hash_module_test.md && echo "REPORT: exists" || echo "REPORT: missing"
    test -f feeds/hash_module_test.json && echo "FEED: exists" || echo "FEED: missing"
    test -f proofs/hash_module_test.sha256 && echo "PROOF: exists" || echo "PROOF: missing"
    ;;
  report)
    cat posts/hash_module_test.md
    ;;
  feed)
    cat feeds/hash_module_test.json
    ;;
  proof)
    cat proofs/hash_module_test.sha256
    ;;
  *)
    echo "Usage: bash cybra_hash_test.sh run|task|status|report|feed|proof"
    ;;
esac
