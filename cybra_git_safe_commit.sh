#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

FILE="${1:-hash_storage/root_hash.json}"
MSG="${2:-Update root_hash}"

wait_lock(){
  i=0
  while [ -f .git/index.lock ] && [ "$i" -lt 30 ]; do
    echo "Waiting for git lock... $i"
    sleep 2
    i=$((i+1))
  done

  if [ -f .git/index.lock ]; then
    if ps -A 2>/dev/null | grep -E "git[[:space:]]" | grep -v grep >/dev/null 2>&1; then
      echo "Active git process exists. Abort safe commit."
      exit 1
    else
      echo "Removing stale git lock."
      rm -f .git/index.lock
    fi
  fi
}

wait_lock

git add "$FILE" 2>/dev/null || {
  echo "git add failed for $FILE"
  exit 1
}

if git diff --cached --quiet; then
  echo "No staged changes."
  exit 0
fi

git commit -m "$MSG" || exit 1
git push origin main || git push
