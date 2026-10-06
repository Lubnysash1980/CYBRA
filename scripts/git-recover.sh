#!/usr/bin/env bash
# CYBRA git recovery helper.
# Usage:
#   bash scripts/git-recover.sh status
#   bash scripts/git-recover.sh backup
#   bash scripts/git-recover.sh list-backups
#   bash scripts/git-recover.sh rollback HEAD~1
#   bash scripts/git-recover.sh restore .backup/git-recover/20261006-120000

set -u
cd "$(dirname "$0")/.."
BK_ROOT=".backup/git-recover"
mkdir -p "$BK_ROOT"

CMD="${1:-status}"

case "$CMD" in
  status)
    echo "=== git status (short) ==="
    git status --short | head -40
    echo
    echo "=== last 5 commits ==="
    git log --oneline -5
    echo
    echo "=== tags ==="
    git tag -l | sort -V
    echo
    echo "=== remote ==="
    git remote -v
    ;;

  backup)
    TS=$(date +%Y%m%d-%H%M%S)
    D="$BK_ROOT/$TS"
    mkdir -p "$D"
    cp -r .git "$D/git-dir"
    cp -r src test "$D/" 2>/dev/null || true
    [ -f foundry.toml ]    && cp foundry.toml    "$D/"
    [ -f remappings.txt ]  && cp remappings.txt  "$D/"
    [ -f README.md ]       && cp README.md       "$D/"
    [ -f THREAT_MODEL.md ] && cp THREAT_MODEL.md "$D/"
    echo "backup -> $D"
    du -sh "$D"
    ;;

  list-backups)
    ls -1 "$BK_ROOT" 2>/dev/null | sort -r
    ;;

  rollback)
    REF="${2:-}"
    if [ -z "$REF" ]; then
      echo "usage: bash scripts/git-recover.sh rollback HEAD~1"
      exit 1
    fi
    bash scripts/git-recover.sh backup
    echo "resetting main to $REF"
    git reset --hard "$REF"
    git log --oneline -1
    ;;

  restore)
    D="${2:-}"
    if [ -z "$D" ]; then
      echo "usage: bash scripts/git-recover.sh restore .backup/git-recover/<timestamp>"
      echo "available:"
      ls -1 "$BK_ROOT" 2>/dev/null | tail -5
      exit 1
    fi
    if [ ! -d "$D" ]; then
      echo "not found: $D"
      exit 1
    fi
    echo "restoring .git from $D/git-dir"
    rm -rf .git
    cp -r "$D/git-dir" .git
    [ -d "$D/src" ]  && rm -rf src  && cp -r "$D/src"  src
    [ -d "$D/test" ] && rm -rf test && cp -r "$D/test" test
    [ -f "$D/foundry.toml" ]    && cp "$D/foundry.toml"    foundry.toml
    [ -f "$D/remappings.txt" ]  && cp "$D/remappings.txt"  remappings.txt
    [ -f "$D/README.md" ]       && cp "$D/README.md"       README.md
    [ -f "$D/THREAT_MODEL.md" ] && cp "$D/THREAT_MODEL.md" THREAT_MODEL.md
    echo "restored from $D"
    git log --oneline -3
    ;;

  *)
    echo "unknown command: $CMD"
    echo "usage: bash scripts/git-recover.sh {status|backup|list-backups|rollback <ref>|restore <dir>}"
    exit 1
    ;;
esac
