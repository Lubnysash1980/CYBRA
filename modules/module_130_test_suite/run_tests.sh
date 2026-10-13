#!/data/data/com.termux/files/usr/bin/bash
H="$HOME/CYBRA"; M="$H/modules"
G=$'\e[32m'; R=$'\e[31m'; Y=$'\e[33m'; B=$'\e[36m'; N=$'\e[0m'
PASS=0; FAIL=0; SKIP=0
t(){ printf "  %-55s " "$1"; }
ok_(){ echo "${G}✓${N}"; PASS=$((PASS+1)); }
no(){ echo "${R}✗ $1${N}"; FAIL=$((FAIL+1)); }
sk(){ echo "${Y}skip${N}"; SKIP=$((SKIP+1)); }

echo "${B}═══ CYBRA Test Suite ═══${N}"

# syntax of all main.sh
echo; echo "${B}▸ Синтаксис${N}"
for f in "$M"/module_*/main.sh "$M"/module_*/bin/*.sh; do
  [ -f "$f" ] || continue
  name="$(basename $(dirname "$f"))/$(basename "$f")"
  t "$name"
  if bash -n "$f" 2>/dev/null; then ok_; else no "syntax"; fi
done

# Python parse
echo; echo "${B}▸ Python${N}"
for f in "$M"/module_*/*.py; do
  [ -f "$f" ] || continue
  name="$(basename $(dirname "$f"))/$(basename "$f")"
  t "$name"
  if python3 -c "import ast;ast.parse(open('$f').read())" 2>/dev/null; then ok_; else no "parse"; fi
done

# dependencies
echo; echo "${B}▸ Залежності${N}"
t "python3"; python3 --version >/dev/null 2>&1 && ok_ || no ""
t "eth_account"; python3 -c "import eth_account" 2>/dev/null && ok_ || sk
t "qrcode"; python3 -c "import qrcode" 2>/dev/null && ok_ || sk
t "nacl"; python3 -c "import nacl" 2>/dev/null && ok_ || sk
t "cloudflared"; command -v cloudflared >/dev/null && ok_ || sk
t "termux-api"; command -v termux-notification >/dev/null && ok_ || sk

# critical files
echo; echo "${B}▸ Критичні файли${N}"
for f in \
  "$M/module_108_metamask_sign/main.sh" \
  "$M/module_121_parlament/parliament.py" \
  "$M/module_120_ai_guardian/guardian.py" \
  "$H/config/metamask.env"; do
  name="$(basename $(dirname "$f"))/$(basename "$f")"
  t "$name"
  [ -e "$f" ] && ok_ || no "missing"
done

# hash chain
echo; echo "${B}▸ Hash-chain парламенту${N}"
t "verify_chain"
if python3 -c "
import sys
sys.path.insert(0,'$M/module_121_parlament')
import parliament as P
r = P.verify_chain()
broken = sum(x['broken'] for x in r.values())
sys.exit(1 if broken else 0)
" 2>/dev/null; then ok_; else no "broken chain"; fi

# TUI syntax
echo; echo "${B}▸ TUI${N}"
t "cybra_menu.sh"
bash -n "$M/module_19_contract_tui_menu/bin/cybra_menu.sh" 2>/dev/null && ok_ || no "syntax"

# Result
echo
echo "${B}═══════════════════════════════════════${N}"
echo "  ${G}PASS: $PASS${N}  ${R}FAIL: $FAIL${N}  ${Y}SKIP: $SKIP${N}"
echo "${B}═══════════════════════════════════════${N}"
[ $FAIL -eq 0 ] && exit 0 || exit 1
