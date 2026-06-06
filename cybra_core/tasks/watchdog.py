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
