#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"
python3 cybra_existing_tasks_evolution_activation.py repair
python3 cybra_existing_tasks_evolution_activation.py report
