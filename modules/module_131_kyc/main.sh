#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
D="$HOME/CYBRA/modules/module_131_kyc"
CFG="$HOME/CYBRA/config/metamask.env"; [ -f "$CFG" ] && . "$CFG"
MY="${BUYER_ADDR:-}"
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; B=$'\e[36m'; DIM=$'\e[2m'; N=$'\e[0m'

menu(){
  while :; do
    clear
    echo "${B}═══ KYC · sanctions check (OFAC + EU) ═══${N}"
    echo
    # статус списків
    if [ -f "$D/data/lists/crypto_addresses.json" ]; then
      AGE=$(python3 -c "
import json,time,sys
d=json.load(open('$D/data/lists/crypto_addresses.json'))
t=d.get('_meta',{}).get('fetched_at','')
try:
    u=time.mktime(time.strptime(t,'%Y-%m-%dT%H:%M:%SZ'))
    print(f'{int((time.time()-u)/3600)}г')
except: print('?')
" 2>/dev/null)
      echo "  ${G}✓${N} списки завантажено (${AGE} тому)"
    else
      echo "  ${Y}!${N} списки не завантажено — спочатку пункт 1"
    fi
    echo
    echo "  ${G}1${N}) Оновити списки санкцій (OFAC + EU, ~5 MB)"
    echo "  ${G}2${N}) Перевірити адресу"
    echo "  ${G}3${N}) Перевірити мій гаманець"
    echo "  ${G}4${N}) Перевірити всі з address book"
    echo "  ${G}5${N}) Статистика списків"
    echo "  ${G}6${N}) Визначити chain за адресою"
    echo "  ${G}7${N}) Кеш перевірок"
    echo
    echo "  ${G}0${N}) Назад"
    echo
    read -rp "  Вибір: " c
    case "$c" in
      1)
        echo
        echo "  ${DIM}Завантажую з treasury.gov і europa.eu...${N}"
        echo
        python3 "$D/fetch.py"
        echo
        read -rp "  Enter…" _
        ;;
      2)
        read -rp "  Адреса: " a
        [ -n "$a" ] && python3 "$D/kyc.py" check "$a"
        read -rp "Enter…" _
        ;;
      3)
        if [ -z "$MY" ]; then
          echo "  немає BUYER_ADDR у config/metamask.env"
        else
          python3 "$D/kyc.py" check "$MY"
        fi
        read -rp "Enter…" _
        ;;
      4)
        echo "  ${DIM}Шукаю адреси у 50/52 (address book)...${N}"
        for f in "$HOME/CYBRA/modules/module_50_address_book/data/addresses.json" \
                 "$HOME/CYBRA/modules/module_51_address_book/data/addresses.json" \
                 "$HOME/CYBRA/config/addresses.json"; do
          [ -f "$f" ] || continue
          echo "  файл: $f"
          python3 -c "
import json,sys
d=json.load(open('$f'))
addrs = d if isinstance(d,list) else d.get('addresses',[])
for a in addrs:
    addr = a.get('addr') if isinstance(a,dict) else a
    if addr: print(addr)
" 2>/dev/null | while read a; do
            python3 "$D/kyc.py" check "$a" 2>&1 | grep -E "Addr|Verdict"
          done
        done
        read -rp "Enter…" _
        ;;
      5)
        python3 "$D/kyc.py" stats
        read -rp "Enter…" _
        ;;
      6)
        read -rp "  Адреса: " a
        python3 "$D/kyc.py" detect "$a"
        read -rp "Enter…" _
        ;;
      7)
        python3 -c "
import json,os
p='$D/data/checked.json'
if not os.path.exists(p): print('  порожньо'); exit()
d=json.load(open(p))
G='\033[32m'; R='\033[31m'; N='\033[0m'
print(f'  {len(d)} перевірок')
for addr, r in list(d.items())[-15:]:
    col = R if r.get('sanctions') else G
    v = 'SANCTIONED' if r.get('sanctions') else 'clean'
    print(f'  {col}{v:11s}{N} {addr[:20]}…  {r.get(\"chain\")}')
"
        read -rp "Enter…" _
        ;;
      0) return ;;
    esac
  done
}
menu
