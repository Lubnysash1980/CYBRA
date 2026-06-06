#!/data/data/com.termux/files/usr/bin/bash
set -e

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

for i in $(seq 1 100); do
  cybra parliament "{\"topic\":\"AI QUESTION $i / 100 complexity\",\"type\":\"test_basic_task\",\"payload\":{\"question_id\":$i,\"complexity\":100,\"goal\":\"перевірити чи Parliament приймає, виконує, логує і повертає відповідь на складне AI питання\"},\"priority\":\"high\"}"
done

echo "✅ 100 AI questions submitted"
cybra status
