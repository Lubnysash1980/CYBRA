#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

case "${1:-status}" in
  status|run|lite|test|queue)
    python3 cybra_task_execution_tester.py "$1"
    ;;
  one)
    python3 cybra_task_execution_tester.py one "${2:-menubar}"
    ;;
  report)
    cat posts/cybra_task_execution_test_report.md
    ;;
  proof)
    cat proofs/cybra_task_execution_test.sha256
    ;;
  *)
    echo "Usage:"
    echo "  cybra-task-test status"
    echo "  cybra-task-test run"
    echo "  cybra-task-test queue"
    echo "  cybra-task-test one menubar"
    echo "  cybra-task-test one it"
    echo "  cybra-task-test report"
    ;;
esac
