#!/data/data/com.termux/files/usr/bin/bash
H="$HOME/CYBRA"
B=$'\e[36m'; R=$'\e[31m'; N=$'\e[0m'
URL="$1"
if [ -z "$URL" ]; then
  for f in "$H"/public/sign/tunnel_*.log "$H"/backups/latest/tunnel_*.log; do
    [ -f "$f" ] || continue
    u=$(grep -oE 'https://[a-z0-9][a-z0-9-]+\.(trycloudflare\.com|lhr\.life|serveo\.net)' "$f" 2>/dev/null \
        | grep -v '^https://api\.' | grep -v console | sort -u | head -1)
    [ -n "$u" ] && { URL="$u"; break; }
  done
fi
[ -z "$URL" ] && { echo "${R}✗${N} URL не знайдено — вкажи: 112 <url>"; exit 1; }
DL="https://metamask.app.link/dapp/${URL#https://}"
echo "${B}URL:${N} $URL"; echo "${B}Deep:${N} $DL"
if command -v termux-open-url >/dev/null; then termux-open-url "$DL" && echo "✓ відкрито"
elif command -v am >/dev/null; then am start -a android.intent.action.VIEW -d "$DL" >/dev/null 2>&1 && echo "✓ відкрито"
else echo "Скопіюй: $DL"; fi
