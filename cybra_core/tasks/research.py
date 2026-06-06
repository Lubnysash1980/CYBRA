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
