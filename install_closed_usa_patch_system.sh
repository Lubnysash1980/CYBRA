#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p private_patches/usa_patch vault/usa_patch posts proofs feeds

cat > private_patches/usa_patch/README.md <<'MD'
# CLOSED USA PATCH

Status: closed/private

Purpose:
Закритий patch-контур для USA Double Backend, recovery, audit, protected tasks.

Rules:
- no secrets in git
- no private keys
- no account access without owner approval
- proof required
- audit required
- owner approval required
MD

cat > private_patches/usa_patch/usa_patch.json <<'JSON'
{
  "patch_id": "closed_usa_patch",
  "status": "private_initialized",
  "visibility": "closed",
  "scope": [
    "usa_double_backend",
    "protected_recovery",
    "audit",
    "watchdog",
    "autoheal",
    "autofix",
    "double_sha_backend"
  ],
  "rules": [
    "no_secrets_in_git",
    "owner_approval_required",
    "double_sha_required",
    "audit_required"
  ]
}
JSON

cat > posts/closed_usa_patch_status.md <<'MD'
# Closed USA Patch

Status: initialized

Visibility:
closed/private

Created:
- private_patches/usa_patch/usa_patch.json
- private_patches/usa_patch/README.md

Security:
- no secrets committed
- owner approval required
- double SHA proof required
MD

sha256sum \
  private_patches/usa_patch/README.md \
  private_patches/usa_patch/usa_patch.json \
  posts/closed_usa_patch_status.md \
  > proofs/closed_usa_patch.sha256

echo "✅ Closed USA Patch installed"
