#!/data/data/com.termux/files/usr/bin/bash
# CYBRA NEURO evidence loop. Creates a branch + evidence commit per round.
# It never applies patches, invokes Task Engine 405, starts PM2, or edits ~/CYBRA.
set -Eeuo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "ERROR: run inside a Git clone of CYBRA_NEURO"; exit 2;
}
cd "$ROOT"
BASE_BRANCH="${BASE_BRANCH:-neuro-500-menu}"
MAX_ROUNDS="${MAX_ROUNDS:-10}"
PAUSE_SECONDS="${PAUSE_SECONDS:-2}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$ROOT/neuro/evidence"
mkdir -p "$EVIDENCE_DIR"

command -v python3 >/dev/null || { echo "ERROR: python3 missing"; exit 2; }
command -v git >/dev/null || { echo "ERROR: git missing"; exit 2; }
[ -f neuro/menu500.py ] || { echo "ERROR: neuro/menu500.py missing"; exit 2; }

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "STOP: working tree has uncommitted changes. Save them first."
  exit 3
fi
if [ -n "$(git ls-files --others --exclude-standard)" ]; then
  echo "STOP: untracked files exist. Review and commit them first."
  exit 3
fi

git fetch origin
git switch "$BASE_BRANCH" 2>/dev/null || git switch -c "$BASE_BRANCH" "origin/$BASE_BRANCH"

previous_score="-1"
for ((round=1; round<=MAX_ROUNDS; round++)); do
  branch="neuro-evo/$STAMP-round-$round"
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    branch="${branch}-$(date -u +%s)"
  fi
  git switch -c "$branch"

  python3 neuro/menu500.py catalog
  python3 neuro/menu500.py auto-create
  python3 -m unittest neuro.test_menu500 -v
  python3 -m py_compile neuro/menu500.py neuro/test_menu500.py
  bash -n neuro/menu500.sh
  bash -n neuro/evo_loop.sh
  export NEURO_UNIT_TESTS_PASSED=1
  export NEURO_PYTHON_COMPILE_PASSED=1
  export NEURO_BASH_SYNTAX_PASSED=1

  python3 neuro/menu500.py evo > "$EVIDENCE_DIR/latest-evo.json"
  score="$(python3 -c 'import json; print(json.load(open("neuro/state/evolution_report.json"))["score_percent"])')"
  passed="$(python3 -c 'import json; d=json.load(open("neuro/state/evolution_report.json")); print(str(d["passed"])+"/"+str(d["total"]))')"

  cat > "$EVIDENCE_DIR/round-$STAMP-$round.md" <<EOF
# NEURO EVO evidence — round $round

- UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Branch: $branch
- Base: $BASE_BRANCH
- EVO score: $score%
- Passed checks: $passed
- Python unit tests: PASS
- Python compile: PASS
- Bash syntax: PASS
- Scope: repository-local checks only; not a claim about live Termux, PM2, wallet, network, or whole-node health.
- Safety: no APPLY, no Task Engine 405 execution, no PM2 operation.
EOF

  git add neuro/menu500_catalog.json neuro/state neuro/evidence
  git commit -m "evo: evidence round $round ($score percent)"
  git push -u origin "$branch"

  echo "ROUND=$round BRANCH=$branch SCORE=$score% CHECKS=$passed"
  [ "$score" = "100" ] && { echo "SCOPED_EVO_100_PERCENT=YES"; exit 0; }

  if [ "$score" = "$previous_score" ]; then
    echo "STOP: score did not improve. Review failed checks before another round."
    exit 4
  fi
  previous_score="$score"
  sleep "$PAUSE_SECONDS"
done

echo "STOP: reached MAX_ROUNDS=$MAX_ROUNDS before scoped 100%."
exit 5
