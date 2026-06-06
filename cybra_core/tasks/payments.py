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
