#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
D="$HOME/CYBRA/modules/module_200_network"
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; B=$'\e[36m'; DIM=$'\e[2m'; N=$'\e[0m'

menu(){
  while :; do
    clear
    CUR=$(python3 "$D/net.py" show 2>&1)
    echo "${B}═══ Network & Options ═══${N}"
    echo "$CUR"
    echo
    echo "  ${B}─── МЕРЕЖА ───${N}"
    echo "  ${G}1${N})  Список мереж"
    echo "  ${G}2${N})  Переключити мережу"
    echo "  ${G}3${N})  ➜ ${G}Testnet${N} (BSC)"
    echo "  ${G}4${N})  ➜ ${R}Mainnet${N} (BSC)"
    echo "  ${G}5${N})  ➜ Sepolia / Amoy (testnets)"
    echo "  ${G}6${N})  Faucet URL (для testnet)"
    echo "  ${G}7${N})  Перевірка RPC (живий?)"
    echo
    echo "  ${B}─── ОПЦІЇ ───${N}"
    echo "  ${G}10${N}) Всі опції"
    echo "  ${G}11${N}) Змінити опцію"
    echo "  ${G}12${N}) Опції мережі"
    echo "  ${G}13${N}) Опції підпису"
    echo "  ${G}14${N}) Опції парламенту"
    echo "  ${G}15${N}) Опції Guardian"
    echo "  ${G}16${N}) Скинути до defaults"
    echo "  ${G}17${N}) Експорт як ENV"
    echo
    echo "  ${G}0${N})  Назад"
    echo
    read -rp "  Вибір: " c
    case "$c" in
      1) python3 "$D/net.py" list; read -rp "Enter…" _ ;;
      2) read -rp "  Назва мережі: " n; python3 "$D/net.py" set "$n"; read -rp "Enter…" _ ;;
      3) python3 "$D/net.py" set bsc_testnet; read -rp "Enter…" _ ;;
      4)
        python3 "$D/options.py" get mode.safe | grep -q True && {
          echo "  ${R}⚠ mode.safe = True${N}"
          echo "  ${Y}Це реальний mainnet — гроші реальні${N}"
          read -rp "  Точно переключити? (yes/no): " a
          [ "$a" != "yes" ] && continue
        }
        python3 "$D/net.py" set bsc_mainnet; read -rp "Enter…" _ ;;
      5)
        echo "  1) eth_sepolia  2) polygon_amoy"
        read -rp "  Вибір: " t
        case "$t" in
          1) python3 "$D/net.py" set eth_sepolia ;;
          2) python3 "$D/net.py" set polygon_amoy ;;
        esac
        read -rp "Enter…" _ ;;
      6)
        python3 -c "
import sys; sys.path.insert(0,'$D'); import net
f = net.faucet()
print(f'  {f}' if f else '  (ця мережа не має faucet — mainnet)')
"
        read -rp "Enter…" _ ;;
      7)
        python3 -c "
import sys, json, urllib.request
sys.path.insert(0,'$D'); import net
url = net.rpc()
print(f'  RPC: {url}')
try:
    data = json.dumps({'jsonrpc':'2.0','id':1,'method':'eth_blockNumber','params':[]}).encode()
    req = urllib.request.Request(url, data=data, headers={'Content-Type':'application/json'})
    with urllib.request.urlopen(req, timeout=8) as r:
        d = json.loads(r.read())
    block = int(d['result'], 16)
    print(f'  \033[32m✓ живий\033[0m · блок {block}')
except Exception as e:
    print(f'  \033[31m✗ не відповідає:\033[0m {e}')
"
        read -rp "Enter…" _ ;;
      10) python3 "$D/options.py" show; read -rp "Enter…" _ ;;
      11) read -rp "  Ключ: " k; read -rp "  Значення: " v
          python3 "$D/options.py" set "$k" "$v"; read -rp "Enter…" _ ;;
      12) python3 "$D/options.py" prefix network.; read -rp "Enter…" _ ;;
      13) python3 "$D/options.py" prefix sign.; read -rp "Enter…" _ ;;
      14) python3 "$D/options.py" prefix parliament.; read -rp "Enter…" _ ;;
      15) python3 "$D/options.py" prefix guardian.; read -rp "Enter…" _ ;;
      16) read -rp "  Точно скинути? (yes): " a; [ "$a" = "yes" ] && python3 "$D/options.py" reset; read -rp "Enter…" _ ;;
      17) python3 "$D/options.py" env; read -rp "Enter…" _ ;;
      0) return ;;
    esac
  done
}
menu
