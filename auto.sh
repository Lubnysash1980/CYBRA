#!/data/data/com.termux/files/usr/bin/bash
# auto.sh — ставить себе сам, запускає себе сам.
# Все: remote + чистка + pull + npm + autosave + pomodoro.
set -uo pipefail
cd "$(dirname "$0")" || exit 1
ROOT="$(pwd)"

# ============ НАЛАШТУВАННЯ ============
REPO_URL="${REPO_URL:-git@github.com:Lubnysash1980/repo.git}"
BRANCH="${BRANCH:-main}"
INTERVAL=30              # сек між автосейвами
PUSH=true                # пушити
WORK=25; BREAK=5; LONG_BREAK=15; CYCLES=4
# =====================================

[ -d .git ] || { git init -q; git symbolic-ref HEAD "refs/heads/$BRANCH"; }
LOG="$ROOT/.git/auto.log"; LOCK="$ROOT/.git/auto.lock"
GITID=(-c user.name="$(git config user.name || echo auto)" \
       -c user.email="$(git config user.email || echo auto@local)")

log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
notify(){ termux-notification -t "$1" -c "$2" 2>/dev/null || true; }

[ -e "$LOCK" ] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null && { echo "вже працює: $(cat $LOCK)"; exit 1; }
echo $$ > "$LOCK"

cleanup(){ pkill -P $$ 2>/dev/null; rm -f "$LOCK"; log "stop"; exit 0; }
trap cleanup INT TERM

# ---------- 1. REMOTE ----------
if [ -n "$REPO_URL" ]; then
  if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "$REPO_URL"; log "remote updated"
  else
    git remote add origin "$REPO_URL"; log "remote added"
  fi
fi

# ---------- 2. .gitignore ----------
cat > .gitignore <<'IG'
node_modules/
dist/
build/
.cache/
.next/
.nuxt/
coverage/
.env
.env.*
!.env.example
.DS_Store
Thumbs.db
.idea/
.vscode/
*.swp
*.swo
*.log
logs/
tmp/
temp/
*.bak
*.old
*.orig
*~
IG
log ".gitignore ok"

# ---------- 3. ЧИСТКА (рекурсивно, тільки файли-сміття, папки НЕ чіпаю) ----------
find . -path ./.git -prune -o -type f \
  \( -name '.DS_Store' -o -name 'Thumbs.db' -o -name '*.bak' -o -name '*.old' \
     -o -name '*.orig' -o -name '*.swp' -o -name '*.swo' -o -name '*~' -o -name '*.tmp' \) \
  -delete 2>/dev/null || true
git ls-files -z 2>/dev/null | tr '\0' '\n' | grep -E '(^|/)(\.DS_Store|Thumbs\.db)$|\.(bak|old|orig|swp|swo|tmp)$|~$' \
  | while IFS= read -r f; do git rm --cached --ignore-unmatch -q "$f" 2>/dev/null; done || true
log "cleanup done"

# ---------- 4. ПЕРШИЙ КОМІТ ----------
if [ -z "$(git log --oneline -1 2>/dev/null)" ]; then
  git add -A 2>/dev/null
  git "${GITID[@]}" commit -m "init: auto-managed" -q 2>/dev/null && log "init commit"
fi

# ---------- 5. PULL ----------
if git remote get-url origin >/dev/null 2>&1; then
  git fetch --all --prune -q 2>>"$LOG" || log "fetch fail"
  git pull --rebase origin "$BRANCH" -q 2>>"$LOG" || log "pull fail (ok if empty)"
  git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1 \
    || git push -u origin "$BRANCH" -q 2>>"$LOG" || true
fi

# ---------- 6. NODE ----------
if [ -f package.json ] && [ ! -d node_modules ]; then
  log "npm install"
  npm install --silent 2>>"$LOG" || log "npm fail"
fi

# ---------- 7. AUTOSAVE ----------
commit_push(){
  [ -n "$(git status --porcelain)" ] || return
  git add -A
  git "${GITID[@]}" commit -m "autosave($1): $(date '+%F %H:%M:%S')" -q 2>>"$LOG" \
    && log "💾 $1"
  if [ "$PUSH" = true ] && git remote get-url origin >/dev/null 2>&1; then
    git push -q 2>>"$LOG" && log "🚀 push $1" || log "push fail"
  fi
}

# фоновий тік кожні INTERVAL сек
( while true; do
    sleep "$INTERVAL"
    [ -z "$(git status --porcelain 2>/dev/null)" ] && continue
    { [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ] || [ -f .git/MERGE_HEAD ]; } && continue
    git add -A 2>/dev/null || continue
    git "${GITID[@]}" commit -m "tick $(date '+%H:%M:%S')" -q 2>>"$LOG" && log "⏱ tick"
    [ "$PUSH" = true ] && git push -q 2>>"$LOG" && log "🚀 push tick" || true
  done ) &
SAVER=$!
trap 'kill $SAVER 2>/dev/null; rm -f "$LOCK"; exit 0' INT TERM

# ---------- 8. POMODORO ----------
log "🍅 start $WORK/$BREAK (long $LONG_BREAK every $CYCLES)"
c=0
while true; do
  c=$((c+1))
  log "🍅 pomodoro #$c — $WORK хв"
  notify "Pomodoro #$c" "Work $WORK min"
  sleep $((WORK*60))
  commit_push "p$c"
  if [ $((c % CYCLES)) -eq 0 ]; then
    log "☕ long break $LONG_BREAK"
    notify "Long break" "$LONG_BREAK min"
    sleep $((LONG_BREAK*60))
  else
    log "☕ break $BREAK"
    notify "Break" "$BREAK min"
    sleep $((BREAK*60))
  fi
don
