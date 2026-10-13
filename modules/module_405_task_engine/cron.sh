#!/data/data/com.termux/files/usr/bin/bash
# Task engine — рідкісний цикл (1 раз на 30 хв) щоб не жерти
while :; do
  sleep 1800
  pgrep -f "task_engine" >/dev/null || \
    python3 "$HOME/CYBRA/modules/module_405_task_engine/engine.py" cycle 3 \
    >/dev/null 2>&1
done
