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
