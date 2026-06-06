#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p cybra_core/tasks cybra_core/registry posts proofs

touch cybra_core/__init__.py
touch cybra_core/tasks/__init__.py

cat > cybra_core/tasks/legal.py <<'PY'
class LegalTask:
    name = "legal"

    def handle(self, task):
        return {
            "class": self.name,
            "status": "routed",
            "domain": "laws/legal requests",
            "next": [
                "legal_watchdog",
                "response_archive",
                "anti_formal_reply",
                "court_package"
            ]
        }
PY

cat > cybra_core/tasks/real_estate.py <<'PY'
class RealEstateTask:
    name = "real_estate"

    def handle(self, task):
        return {
            "class": self.name,
            "status": "routed",
            "domain": "нерухомість / незавершене право власності",
            "next": [
                "registry_check",
                "council_request",
                "ownership_watchdog",
                "evidence_graph"
            ]
        }
PY

cat > cybra_core/tasks/payments.py <<'PY'
class PaymentsTask:
    name = "payments"

    def handle(self, task):
        return {
            "class": self.name,
            "status": "routed",
            "domain": "оплати / чеки / транзакції",
            "next": [
                "payment_evidence",
                "invoice_check",
                "refund_claim",
                "proof_hash"
            ]
        }
PY

cat > cybra_core/tasks/token.py <<'PY'
class TokenTask:
    name = "token"

    def handle(self, task):
        return {
            "class": self.name,
            "status": "routed",
            "domain": "CYBRA token / native / SPL / wallet visible",
            "next": [
                "native_token",
                "wallet_visible_token",
                "mainnet_guardian",
                "proof_ledger"
            ]
        }
PY

cat > cybra_core/tasks/workers.py <<'PY'
class WorkersTask:
    name = "workers"

    def handle(self, task):
        return {
            "class": self.name,
            "status": "routed",
            "domain": "workers / executor / scaling",
            "next": [
                "restart_worker",
                "scale_workers",
                "retry_failed",
                "self_healing"
            ]
        }
PY

cat > cybra_core/tasks/watchdog.py <<'PY'
class WatchdogTask:
    name = "watchdog"

    def handle(self, task):
        return {
            "class": self.name,
            "status": "routed",
            "domain": "watchdog / supervisor / deadlines",
            "next": [
                "deadline_check",
                "failure_detect",
                "autofix",
                "escalation"
            ]
        }
PY

cat > cybra_core/tasks/github_pages.py <<'PY'
class GitHubPagesTask:
    name = "github_pages"

    def handle(self, task):
        return {
            "class": self.name,
            "status": "routed",
            "domain": "GitHub Pages / web portal",
            "next": [
                "pages_build_check",
                "root_index_check",
                "actions_check",
                "redeploy"
            ]
        }
PY

cat > cybra_core/tasks/research.py <<'PY'
class ResearchTask:
    name = "research"

    def handle(self, task):
        return {
            "class": self.name,
            "status": "routed",
            "domain": "AI research / no hallucination",
            "next": [
                "source_search",
                "confidence_score",
                "unknown_if_no_source",
                "proof"
            ]
        }
PY

cat > cybra_core/router.py <<'PY'
from cybra_core.tasks.legal import LegalTask
from cybra_core.tasks.real_estate import RealEstateTask
from cybra_core.tasks.payments import PaymentsTask
from cybra_core.tasks.token import TokenTask
from cybra_core.tasks.workers import WorkersTask
from cybra_core.tasks.watchdog import WatchdogTask
from cybra_core.tasks.github_pages import GitHubPagesTask
from cybra_core.tasks.research import ResearchTask

ROUTES = {
    "law": LegalTask(),
    "legal": LegalTask(),
    "real_estate": RealEstateTask(),
    "нерухомість": RealEstateTask(),
    "payments": PaymentsTask(),
    "оплата": PaymentsTask(),
    "token": TokenTask(),
    "workers": WorkersTask(),
    "watchdog": WatchdogTask(),
    "github_pages": GitHubPagesTask(),
    "pages": GitHubPagesTask(),
    "research": ResearchTask(),
    "ai_question": ResearchTask()
}

def route_task(task):
    text = (
        str(task.get("type", "")) + " " +
        str(task.get("topic", "")) + " " +
        str(task.get("payload", ""))
    ).lower()

    for key, handler in ROUTES.items():
        if key.lower() in text:
            return handler.handle(task)

    return {
        "class": "unknown",
        "status": "needs_decomposition",
        "next": ["create_new_class", "create_mapping", "retry"]
    }
PY

cat > cybra_core/registry/task_classes.json <<'JSON'
{
  "classes": [
    "legal",
    "real_estate",
    "payments",
    "token",
    "workers",
    "watchdog",
    "github_pages",
    "research"
  ],
  "status": "initialized"
}
JSON

cat > test_cybra_router.py <<'PY'
from cybra_core.router import route_task

tests = [
    {"topic": "робота з законами", "type": "law_task"},
    {"topic": "пошук нерухомості", "type": "real_estate_task"},
    {"topic": "оплата за авто", "type": "payments_task"},
    {"topic": "native token", "type": "token_task"},
    {"topic": "GitHub Pages не відкривається", "type": "github_pages_task"}
]

for t in tests:
    print(route_task(t))
PY

python3 test_cybra_router.py > posts/cybra_import_classes_status.md

find cybra_core -type f -exec sha256sum {} \; > proofs/cybra_import_classes.sha256

git add cybra_core test_cybra_router.py posts/cybra_import_classes_status.md proofs/cybra_import_classes.sha256 install_cybra_import_classes.sh
git commit -m "add CYBRA import class routing system" || true

echo "✅ CYBRA import/class system installed"
