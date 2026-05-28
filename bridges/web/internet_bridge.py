import json, time, urllib.request
from pathlib import Path

targets = [
    "https://github.com",
    "https://api.github.com",
    "https://wikipedia.org"
]

results = {}

for url in targets:
    try:
        r = urllib.request.urlopen(url, timeout=10)
        results[url] = {
            "ok": True,
            "code": r.status
        }
    except Exception as e:
        results[url] = {
            "ok": False,
            "error": str(e)
        }

Path("feeds/internet_status.json").write_text(
    json.dumps({
        "time": time.time(),
        "internet": results
    }, ensure_ascii=False, indent=2),
    encoding="utf-8"
)

print(json.dumps(results, ensure_ascii=False, indent=2))
