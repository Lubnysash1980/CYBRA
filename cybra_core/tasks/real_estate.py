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
