#!/data/data/com.termux/files/usr/bin/bash
set -u

BASE="$(cd "$(dirname "$0")" && pwd)"

"$BASE/cybra_domain_health.sh"
"$BASE/cybra_domain_self_heal.sh"
