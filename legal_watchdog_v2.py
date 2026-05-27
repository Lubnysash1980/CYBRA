import json, hashlib, time
from pathlib import Path

BASE = Path.home() / "CYBRA"
REQ = BASE / "legal" / "requests"
RESP = BASE / "legal" / "responses"
POSTS = BASE / "posts"
PROOFS = BASE / "proofs"
WATCH = BASE / "legal" / "watchdog"

POSTS.mkdir(exist_ok=True)
PROOFS.mkdir(exist_ok=True)
WATCH.mkdir(parents=True, exist_ok=True)

bad_phrases = [
    "не належить до компетенції",
    "розглянуто в межах компетенції",
    "підстав не встановлено",
    "інформація відсутня",
    "звертайтесь до іншого органу",
    "не вбачається можливим",
    "залишено без розгляду"
]

requests = list(REQ.glob("*/*.md"))
responses = list(RESP.glob("*.md"))

pending = []
approved = []
submitted = []
offtopic_replies = []

for f in requests:
    txt = f.read_text(encoding="utf-8", errors="ignore")
    if "approved_ready_for_manual_submission" in txt:
        approved.append(str(f))
        pending.append(str(f))
    if "submitted" in txt:
        submitted.append(str(f))

for r in responses:
    txt = r.read_text(encoding="utf-8", errors="ignore").lower()
    score = sum(1 for p in bad_phrases if p in txt)
    if score > 0:
        offtopic_replies.append({
            "file": str(r),
            "risk": "possible_formal_reply/відписка",
            "score": score
        })

report = {
    "time": time.time(),
    "total_requests": len(requests),
    "approved_ready_for_manual_submission": len(approved),
    "submitted": len(submitted),
    "pending_send": len(pending),
    "responses": len(responses),
    "possible_formal_replies": offtopic_replies,
    "logic": {
        "if_pending_send": "prepare/send reminder after owner approval",
        "if_formal_reply": "prepare objection/escalation",
        "if_no_response": "prepare second/third request"
    }
}

raw = json.dumps(report, ensure_ascii=False, indent=2)
(WATCH / "legal_watchdog_report.json").write_text(raw, encoding="utf-8")
(PROOFS / "legal_watchdog_v2.sha256").write_text(hashlib.sha256(raw.encode()).hexdigest(), encoding="utf-8")

md = f"""# Legal Watchdog V2

Total requests: {len(requests)}
Approved / ready: {len(approved)}
Submitted: {len(submitted)}
Pending send: {len(pending)}
Responses archived: {len(responses)}
Possible відписки: {len(offtopic_replies)}

## Action
- Якщо pending send > 0: треба подати запити вручну або через затверджений канал.
- Якщо є відписка: підготувати заперечення/скаргу.
- Якщо немає відповіді: готувати наступний запит.
"""
(POSTS / "legal_watchdog_v2_status.md").write_text(md, encoding="utf-8")

print(raw)
