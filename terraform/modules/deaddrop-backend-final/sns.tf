resource "aws_sns_topic" "notifications" {
  name = "DeadDropNotifications-${var.environment}"
}

# ── Escalation (optional) ───────────────────────────────────
resource "aws_sns_topic" "escalation" {
  count = var.enable_escalation ? 1 : 0
  name  = "DeadDropEscalation-${var.environment}"
}

resource "aws_sns_topic_subscription" "escalation_webhook" {
  count     = var.enable_escalation ? 1 : 0
  topic_arn = aws_sns_topic.escalation[0].arn
  protocol  = "https"
  endpoint  = var.incident_io_webhook_endpoint
}
