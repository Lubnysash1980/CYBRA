#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p legal/inbox legal/responses legal/timeline posts proofs

ORG="${1:-unknown}"
TEXT="${2:-}"

if [ -z "$TEXT" ]; then
  echo "Usage:"
  echo "bash legal_response_inbox.sh dbr 'текст відповіді'"
  exit 1
fi

ID="$(date +%Y%m%d_%H%M%S)_$ORG"

echo "$TEXT" > "legal/inbox/$ID.txt"

cat > "legal/responses/$ID.md" <<MD
# Відповідь від $ORG

Дата: $(date -Iseconds)

## Текст відповіді
$TEXT

## Статус
received
MD

echo "- $(date -Iseconds): received response from $ORG → legal/responses/$ID.md" >> legal/timeline/response_timeline.md

sha256sum legal/inbox/$ID.txt legal/responses/$ID.md legal/timeline/response_timeline.md > proofs/legal_response_$ID.sha256

cat > posts/latest_legal_response.md <<MD
# Latest Legal Response

Орган: $ORG  
Дата: $(date -Iseconds)  
Файл: legal/responses/$ID.md  
Proof: proofs/legal_response_$ID.sha256
MD

echo "✅ Response archived: legal/responses/$ID.md"
