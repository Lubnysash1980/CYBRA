# CYBRA API Key / Secret Vault Policy

Status: ACTIVE_POLICY_DRAFT

Rules:
- Never store real API credentials in GitHub
- Never paste seed phrases, signing material, passwords, or live secrets into chat
- Use local `.env.private` or server secret manager
- chmod 600 for secret files
- Sandbox keys first
- Live credentials only after OWNER approval
- Read-only keys preferred for monitoring
- Withdrawal permissions disabled by default
