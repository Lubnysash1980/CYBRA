#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== SAFE GIT RECOVER FINANCE PUSH ==="

TS="$(date +%Y%m%d_%H%M%S)"
RESCUE="rescue_finance_${TS}"

echo "Current state:"
git status --short --branch

echo
echo "1) Save current HEAD to branch: $RESCUE"
git branch "$RESCUE" HEAD 2>/dev/null || true

echo
echo "2) Add latest finance fixes"
git add \
  fix_finance_it_creation_test_v2.sh \
  test_finance_it_bank_psp_creation.sh \
  data/cybra_finance/reports/finance_it_bank_psp_creation_test_latest.json \
  data/cybra_finance/keys/policy/api_key_vault_policy.md \
  posts/cybra_finance_it_bank_psp_creation_test.md \
  feeds/cybra_finance_it_bank_psp_creation_test.json \
  proofs/cybra_finance_it_bank_psp_creation_test.sha256

git commit -m "fix finance IT bank PSP creation test" || true

git branch "${RESCUE}_after_fix" HEAD 2>/dev/null || true

echo
echo "3) Abort broken rebase if exists"
git rebase --abort 2>/dev/null || true
rm -rf .git/rebase-merge .git/rebase-apply 2>/dev/null || true

echo
echo "4) Fetch origin main"
git fetch origin main || exit 1

BASE="$(git merge-base origin/main ${RESCUE}_after_fix 2>/dev/null)"
echo "BASE=$BASE"

if [ -z "$BASE" ]; then
  echo "❌ Cannot find merge-base. Rescue branch saved: ${RESCUE}_after_fix"
  exit 1
fi

echo
echo "5) Switch to main"
git switch main 2>/dev/null || git checkout main || exit 1

echo
echo "6) Update main"
git pull --rebase origin main || exit 1

echo
echo "7) Cherry-pick rescued commits onto main"
git cherry-pick "$BASE"..${RESCUE}_after_fix
CP_CODE="$?"

if [ "$CP_CODE" != "0" ]; then
  echo
  echo "❌ Cherry-pick conflict."
  echo "Run:"
  echo "  git status"
  echo "  fix conflicts"
  echo "  git add ."
  echo "  git cherry-pick --continue"
  echo "  git push origin main"
  echo
  echo "Rescue branch saved: ${RESCUE}_after_fix"
  exit 2
fi

echo
echo "8) Push main"
git push origin main

echo
echo "✅ DONE"
echo "Rescue branch kept: ${RESCUE}_after_fix"
