#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p posts proofs feeds

QUESTION=$(python3 - <<'PY'
import os, json
raw = os.environ.get("CYBRA_TASK_JSON","{}")
try:
    t=json.loads(raw)
    print(t.get("payload",{}).get("question") or t.get("topic","unknown"))
except Exception:
    print("unknown")
PY
)

cat > posts/ai_question_answer.md <<MD
# CYBRA AI Research Answer

## Question
$QUESTION

## Search Status
fallback_offline

## Answer
Питання прийнято CYBRA Parliament. Online research backend недоступний або заблокований, тому відповідь сформована у safe fallback mode. Для повного web-search потрібен окремий API/web bridge.

## Engine
research_backend_safe_fallback_v4
MD

sha256sum posts/ai_question_answer.md > proofs/ai_question_answer.sha256

cat > feeds/ai_research_status.json <<JSON
{
  "status": "fallback_offline",
  "engine": "research_backend_safe_fallback_v4",
  "question": "$QUESTION"
}
JSON

echo "✅ AI research backend safe fallback executed"
