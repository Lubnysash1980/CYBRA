#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  report)
    python3 cybra_kibra_difficulty_classes.py report
    cat posts/kibra_difficulty_classes_report.md
    ;;
  submit-ai)
    python3 cybra_kibra_difficulty_classes.py submit-ai
    ;;
  status)
    redis-cli ping
    echo "DIFFICULTY_CLASS_AUDIT: $(redis-cli LLEN cybra:kibra:difficulty_classes:audit)"
    echo "AI_QUEUE: $(redis-cli LLEN cybra:ai:tasks:kibra_difficulty_classes)"
    test -f posts/kibra_difficulty_classes_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  classes)
    cat data/kibra_difficulty_classes/classes.json
    ;;
  proof)
    cat proofs/kibra_difficulty_classes.sha256
    ;;
  *)
    echo "Usage: bash cybra_kibra_difficulty.sh report|submit-ai|status|classes|proof"
    ;;
esac
