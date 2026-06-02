#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  build)
    python3 cybra_native_kibra_builder.py build
    ;;
  submit-ai-task)
    python3 cybra_native_kibra_builder.py submit
    ;;
  status)
    redis-cli ping
    echo "NATIVE_KIBRA_AI_TASKS: $(redis-cli LLEN cybra:ai:tasks:native_kibra)"
    test -f posts/native_kibra_ai_task_package.md && echo "REPORT: exists" || echo "REPORT: missing"
    test -f token/kibra/native/assets/kibra_token.png && echo "PNG: exists" || echo "PNG: missing"
    test -f website/kibra/index.html && echo "WEBSITE: exists" || echo "WEBSITE: missing"
    ;;
  report)
    cat posts/native_kibra_ai_task_package.md
    ;;
  task)
    cat parliament/native_kibra/tasks/native_kibra_evolution_task.json
    ;;
  proof)
    cat proofs/native_kibra_ai_task_package.sha256
    ;;
  *)
    echo "Usage: bash cybra_native_kibra.sh build|submit-ai-task|status|report|task|proof"
    ;;
esac
