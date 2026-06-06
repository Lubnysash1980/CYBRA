#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p recovery/git_paths posts proofs

git status --short > recovery/git_paths/status.txt || true
git log --oneline -50 > recovery/git_paths/last_commits.txt || true
find . -maxdepth 3 -type f \
  ! -path "./.git/*" \
  ! -path "./logs/*" \
  > recovery/git_paths/file_index.txt

sha256sum recovery/git_paths/*.txt > proofs/git_path_recovery.sha256

cat > posts/git_path_recovery_status.md <<'MD'
# Git Path Recovery

Status: indexed

Created:
- recovery/git_paths/status.txt
- recovery/git_paths/last_commits.txt
- recovery/git_paths/file_index.txt
- proofs/git_path_recovery.sha256
MD

echo "✅ Git path recovery index created"
