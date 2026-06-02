#!/data/data/com.termux/files/usr/bin/bash

while true
do
    if ! pgrep -f "device_sync_android_autofix.sh" >/dev/null
    then
        echo "[WATCHDOG] restarting device sync..."
        bash "$HOME/CYBRA/device_sync_android_autofix.sh" >/dev/null 2>&1 &
    fi

    sleep 300
done
