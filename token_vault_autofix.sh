#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p vault/tokens vault/audit vault/policy posts proofs

cat > vault/policy/token_policy.json <<'JSON'
{
  "system": "CYBRA Secure Token Vault",
  "storage": "local_encrypted_or_manual_placeholder",
  "rules": [
    "never_commit_real_tokens",
    "never_print_tokens",
    "fingerprint_or_manual_approval_required",
    "workers_use_only_approved_tokens",
    "rotate_tokens_if_leaked"
  ],
  "supported_integrations": [
    "email",
    "diia_sign_placeholder",
    "github",
    "api_backend"
  ],
  "status": "initialized"
}
JSON

cat > vault/tokens/README.md <<'MD'
# CYBRA Token Vault

Do NOT store real tokens in git.

Recommended:
- keep real secrets in local-only files;
- add vault/tokens/*.secret to .gitignore;
- use fingerprint/manual approval before use.
MD

cat > vault/audit/token_vault_audit.md <<MD
# Token Vault Audit

Created: $(date -Iseconds)

Status:
initialized

No real tokens stored.
MD

cat >> .gitignore <<'GI'
vault/tokens/*.secret
vault/tokens/*.key
vault/tokens/*.env
GI

sha256sum vault/policy/token_policy.json vault/tokens/README.md vault/audit/token_vault_audit.md > proofs/token_vault.sha256

cat > posts/token_vault_status.md <<'MD'
# CYBRA Secure Token Vault

Status: initialized

Created:
- vault/tokens/
- vault/audit/
- vault/policy/token_policy.json
- proofs/token_vault.sha256

Security:
- real tokens are ignored by git
- no plaintext secrets in logs
- approval required before worker use
MD

git add vault/policy vault/tokens/README.md vault/audit posts/token_vault_status.md proofs/token_vault.sha256 .gitignore token_vault_autofix.sh
git commit -m "add secure token vault system" || true

echo "✅ Secure token vault initialized"
