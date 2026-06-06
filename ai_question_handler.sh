#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p posts proofs registry

QUESTION="$(cat registry/last_ai_question.txt 2>/dev/null || echo "unknown question")"

cat > posts/ai_question_answer.md <<MD
# CYBRA AI Question Answer

## Question
$QUESTION

## Answer
Питання прийнято AI Parliament. Для реальної автоматичної відповіді потрібен підключений research backend або LLM/API. Зараз створено routing, post і proof.

## Status
handled_by_ai_question_handler
MD

sha256sum posts/ai_question_answer.md > proofs/ai_question_answer.sha256

echo "✅ AI question handler executed"
