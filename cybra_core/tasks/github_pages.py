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
