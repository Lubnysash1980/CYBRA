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
