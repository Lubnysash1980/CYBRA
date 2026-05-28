#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p posts proofs tests

cat > tests/full_task_test_v2.jsonl <<'EOF'
{"topic":"TESTV2 1 basic","type":"test_basic_task","payload":{"goal":"basic execution"},"priority":"normal"}
{"topic":"TESTV2 2 AI question","type":"ai_question_task","payload":{"question":"Скільки буде 2+2?"},"priority":"normal"}
{"topic":"TESTV2 3 GitHub Pages","type":"github_pages_task","payload":{"goal":"check pages root index"},"priority":"critical"}
{"topic":"TESTV2 4 worker resilience","type":"workers_task","payload":{"goal":"check worker autoheal"},"priority":"critical"}
{"topic":"TESTV2 5 token evolution","type":"native_token_evolution_task","payload":{"goal":"verify token layer"},"priority":"critical"}
EOF

while read -r T; do
  cybra parliament "$T"
done < tests/full_task_test_v2.jsonl

sleep 10

cybra results | grep "TESTV2 " > posts/full_task_test_v2_raw.md || true

cat > posts/full_task_test_v2_report.md <<EOF
# CYBRA Full Task Test V2 Report

$(cat posts/full_task_test_v2_raw.md)
EOF

cat posts/full_task_test_v2_report.md
