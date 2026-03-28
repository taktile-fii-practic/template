resource "aws_sns_topic" "notifications" {
  name = "DeadDropNotifications-${var.environment}"
}
