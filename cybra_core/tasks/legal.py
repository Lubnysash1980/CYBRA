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
