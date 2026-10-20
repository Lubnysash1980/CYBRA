#!/data/data/com.termux/files/usr/bin/bash
# Запуск команди з обмеженнями: 200 МБ RAM, 65 МБ sandbox
ulimit -v 204800      # 200 МБ віртуальної пам'яті
ulimit -f 65536       # 64 МБ на файл
exec "$@"
