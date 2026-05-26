#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p posts proofs registry logs/research

QUESTION="$(cat registry/last_ai_question.txt 2>/dev/null || echo "unknown question")"

python3 - "$QUESTION" <<'PY'
import sys
import json
import hashlib
import urllib.parse
import urllib.request
from pathlib import Path

question = sys.argv[1]

def wiki_search(q):
    try:
        url = (
            "https://uk.wikipedia.org/w/api.php?"
            "action=query&list=search&format=json&srsearch="
            + urllib.parse.quote(q)
        )

        data = json.loads(
            urllib.request.urlopen(url, timeout=15).read().decode()
        )

        hits = data.get("query", {}).get("search", [])

        if not hits:
            return {
                "status": "not_found",
                "answer": "Нічого не знайдено."
            }

        title = hits[0]["title"]

        summary_url = (
            "https://uk.wikipedia.org/api/rest_v1/page/summary/"
            + urllib.parse.quote(title)
        )

        summary = json.loads(
            urllib.request.urlopen(summary_url, timeout=15).read().decode()
        )

        return {
            "status": "ok",
            "title": title,
            "answer": summary.get("extract", "Короткий опис відсутній.")
        }

    except Exception as e:
        return {
            "status": "error",
            "answer": str(e)
        }

result = wiki_search(question)

post = f"""# CYBRA AI Research Answer

## Question
{question}

## Search Status
{result.get("status")}

## Title
{result.get("title", "unknown")}

## Answer
{result.get("answer")}

## Engine
research_backend_v2
"""

Path("posts/ai_question_answer.md").write_text(
    post,
    encoding="utf-8"
)

raw = json.dumps(result, ensure_ascii=False, indent=2)

Path("logs/research/latest_answer.json").write_text(
    raw,
    encoding="utf-8"
)

sha = hashlib.sha256(post.encode()).hexdigest()

Path("proofs/ai_question_answer.sha256").write_text(
    sha,
    encoding="utf-8"
)

print(post)
PY

echo "✅ AI research backend v2 executed"
