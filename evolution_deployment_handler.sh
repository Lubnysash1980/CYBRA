#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_evolution_deployment.py develop

for i in $(seq 1 20); do
  python3 parliament_executor_v6.py || true
  sleep 1
  [ "$(redis-cli LLEN cybra:parliament:queue)" = "0" ] && break
done

python3 cybra_evolution_deployment.py report
