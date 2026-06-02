#!/usr/bin/env python3
import json, time, hashlib, subprocess
from pathlib import Path
from collections import Counter
import redis

r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

def dsha(x):
    h1 = hashlib.sha256(x.encode("utf-8")).hexdigest()
    return hashlib.sha256(h1.encode("utf-8")).hexdigest()

def load_json(x):
    try:
        return json.loads(x)
    except Exception:
        return {"status": "raw", "raw": x}

def cmd(c):
    try:
        return subprocess.check_output(c, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def main():
    r.ping()

    results = [load_json(x) for x in r.lrange("cybra:results", 0, 199)]
    statuses = Counter(str(x.get("status", "unknown")) for x in results)
    types = Counter(str(x.get("type", "unknown")) for x in results)

    report = {
        "committee": "CYBRA Parliament Analytics Committee",
        "status": "generated",
        "time": time.time(),
        "git_branch": cmd(["git", "branch", "--show-current"]),
        "git_commit": cmd(["git", "rev-parse", "--short", "HEAD"]),
        "redis": {
            "results": r.llen("cybra:results"),
            "audit": r.llen("cybra:audit"),
            "parliament_queue": r.llen("cybra:parliament:queue"),
            "review_incoming": r.llen("cybra:review:incoming"),
            "review_hold": r.llen("cybra:review:hold"),
            "review_rejected": r.llen("cybra:review:rejected"),
            "analytics_audit": r.llen("cybra:analytics:audit")
        },
        "summary": {
            "checked_results": len(results),
            "statuses": dict(statuses),
            "types": dict(types),
            "executor_mapping_count": len(r.hgetall("cybra:executor:mapping"))
        },
        "latest_results": results[:10]
    }

    report["double_sha"] = dsha(json.dumps(report, ensure_ascii=False, sort_keys=True))

    Path("feeds/analytics_committee_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2))

    md = "# CYBRA Parliament Analytics Committee\n\n"
    md += f"Status: generated\n\nDouble SHA: `{report['double_sha']}`\n\n"
    md += "## Redis\n\n"
    for k, v in report["redis"].items():
        md += f"- {k}: {v}\n"
    md += "\n## Statuses\n\n"
    for k, v in report["summary"]["statuses"].items():
        md += f"- {k}: {v}\n"
    md += "\n## Task types\n\n"
    for k, v in report["summary"]["types"].items():
        md += f"- {k}: {v}\n"

    Path("posts/analytics_committee_report.md").write_text(md)

    subprocess.run(
        ["sha256sum", "feeds/analytics_committee_report.json", "posts/analytics_committee_report.md"],
        stdout=open("proofs/analytics_committee.sha256", "w")
    )

    r.lpush("cybra:analytics:audit", json.dumps({
        "status": "analytics_generated",
        "time": report["time"],
        "double_sha": report["double_sha"]
    }, ensure_ascii=False))

    print("✅ CYBRA analytics generated")
    print("posts/analytics_committee_report.md")

if __name__ == "__main__":
    main()
