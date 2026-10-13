#!/data/data/com.termux/files/usr/bin/bash
# Голосові команди через Termux:API speech-to-text + TTS
H="$HOME/CYBRA"; M="$H/modules"
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; B=$'\e[36m'; N=$'\e[0m'

speak(){ termux-tts-speak "$1" 2>/dev/null & }
listen(){
  # Termux:API STT
  termux-speech-to-text 2>/dev/null
}

handle(){
  local cmd="$1"
  cmd=$(echo "$cmd" | tr 'А-Я' 'а-я')
  case "$cmd" in
    *"статус"*|*"status"*)       python3 "$H/modules/module_121_parlament/executor.py" run 2>&1 | tail -5 ;;
    *"підпис"*|*"sign"*)         speak "відкриваю підпис"; bash "$M/module_108_metamask_sign/main.sh" ;;
    *"парламент"*|*"parliament"*) bash "$M/module_121_parlament/main.sh" ;;
    *"авто нода"*|*"autonode"*)  bash "$M/module_114_autonode/main.sh" status ;;
    *"перевір"*|*"validate"*)    bash "$M/module_122_contract_validator/main.sh" ;;
    *"дашборд"*|*"dashboard"*)   bash "$M/module_128_dashboard/main.sh" start ;;
    *"тест"*|*"test"*)           bash "$M/module_130_test_suite/run_tests.sh" | tail -5 ;;
    *"допомога"*|*"help"*)       speak "Доступні команди: статус, підпис, парламент, авто нода, перевір, дашборд, тест" ;;
    *)                            speak "Не зрозумів команду" ;;
  esac
}

if [ "${1:-menu}" = "ask" ]; then
  speak "Слухаю"
  txt=$(listen)
  echo "  ${B}Розпізнано:${N} $txt"
  [ -n "$txt" ] && handle "$txt"
elif [ "${1:-menu}" = "say" ]; then
  shift; speak "$*"
else
  echo "${B}Voice Interface${N}"
  echo "  1) Одне питання  2) Тест TTS  3) Список команд"
  read -rp "  Вибір: " c
  case "$c" in
    1) bash "$0" ask ;;
    2) speak "CYBRA працює" ;;
    3) echo "Команди: статус, підпис, парламент, авто нода, перевір, дашборд, тест, допомога" ;;
  esac
  read -rp "Enter…" _
fi
