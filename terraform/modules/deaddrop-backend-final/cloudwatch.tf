# ── Log Groups ───────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/lambda/${var.project_name}-api"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "delete_worker" {
  name              = "/aws/lambda/${var.project_name}-delete-worker"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "stream_processor" {
  name              = "/aws/lambda/${var.project_name}-stream-processor"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "notification" {
  name              = "/aws/lambda/${var.project_name}-notification"
  retention_in_days = 14
}

# ── Alarms ──────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "DeadDrop-5xx-OnCall-${var.environment}"
  alarm_description   = "API 5xx error rate spike — escalates to incident.io on-call"
  namespace           = "AWS/ApiGateway"
  metric_name         = "5xx"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = aws_apigatewayv2_api.http.id
  }

  alarm_actions = var.enable_escalation ? [aws_sns_topic.escalation[0].arn] : []
}

resource "aws_cloudwatch_metric_alarm" "api_latency" {
  alarm_name          = "DeadDrop-HighLatency-${var.environment}"
  alarm_description   = "API p99 latency exceeds 5s"
  namespace           = "AWS/ApiGateway"
  metric_name         = "Latency"
  extended_statistic  = "p99"
  period              = 300
  evaluation_periods  = 3
  threshold           = 5000
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = aws_apigatewayv2_api.http.id
  }
}

resource "aws_cloudwatch_metric_alarm" "dynamo_throttle" {
  alarm_name          = "DeadDrop-DynamoDB-Throttle-${var.environment}"
  alarm_description   = "DynamoDB read/write throttling detected"
  namespace           = "AWS/DynamoDB"
  metric_name         = "ThrottledRequests"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = aws_dynamodb_table.secrets.name
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "DeadDrop-LambdaErrors-${var.environment}"
  alarm_description   = "Lambda invocation errors across API function"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 10
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.api.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "dlq_depth" {
  alarm_name          = "DeadDrop-DLQ-Depth-${var.environment}"
  alarm_description   = "Messages accumulating in Dead Letter Queue"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.delete_dlq.name
  }
}

# ── Dashboard ───────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "operational" {
  dashboard_name = "DeadDrop-${var.environment}"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "# Dead Drop — Operational Dashboard (${var.environment})"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 12
        height = 6
        properties = {
          title  = "API Requests (2xx / 4xx / 5xx)"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ApiGateway", "2xx", "ApiId", aws_apigatewayv2_api.http.id, { stat = "Sum", color = "#00ff41" }],
            [".", "4xx", ".", ".", { stat = "Sum", color = "#ffd93d" }],
            [".", "5xx", ".", ".", { stat = "Sum", color = "#ff6b6b" }],
          ]
          period  = 60
          view    = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 1
        width  = 12
        height = 6
        properties = {
          title  = "API Latency (p50 / p90 / p99)"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiId", aws_apigatewayv2_api.http.id, { stat = "p50", label = "p50", color = "#00ff41" }],
            ["...", { stat = "p90", label = "p90", color = "#ffd93d" }],
            ["...", { stat = "p99", label = "p99", color = "#ff6b6b" }],
          ]
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 7
        width  = 8
        height = 6
        properties = {
          title  = "API Lambda — Invocations & Errors"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.api.function_name, { stat = "Sum", color = "#00ff41" }],
            [".", "Errors", ".", ".", { stat = "Sum", color = "#ff6b6b" }],
            [".", "Throttles", ".", ".", { stat = "Sum", color = "#ffd93d" }],
          ]
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 7
        width  = 8
        height = 6
        properties = {
          title  = "API Lambda — Duration"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.api.function_name, { stat = "Average", label = "avg", color = "#00ff41" }],
            ["...", { stat = "p99", label = "p99", color = "#ff6b6b" }],
          ]
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 7
        width  = 8
        height = 6
        properties = {
          title  = "Worker Lambdas — Errors"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.delete_worker.function_name, { stat = "Sum", label = "DeleteWorker", color = "#ff6b6b" }],
            [".", "Errors", "FunctionName", aws_lambda_function.stream_processor.function_name, { stat = "Sum", label = "StreamProcessor", color = "#ffd93d" }],
            [".", "Errors", "FunctionName", aws_lambda_function.notification.function_name, { stat = "Sum", label = "Notification", color = "#00ff41" }],
          ]
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 13
        width  = 8
        height = 6
        properties = {
          title  = "DynamoDB — Read/Write Capacity"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", aws_dynamodb_table.secrets.name, { stat = "Sum", color = "#00ff41" }],
            [".", "ConsumedWriteCapacityUnits", ".", ".", { stat = "Sum", color = "#ffd93d" }],
          ]
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 13
        width  = 8
        height = 6
        properties = {
          title  = "SQS — Delete Queue"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/SQS", "NumberOfMessagesSent", "QueueName", aws_sqs_queue.delete_queue.name, { stat = "Sum", label = "Sent", color = "#00ff41" }],
            [".", "NumberOfMessagesReceived", ".", ".", { stat = "Sum", label = "Received", color = "#ffd93d" }],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.delete_dlq.name, { stat = "Sum", label = "DLQ Depth", color = "#ff6b6b" }],
          ]
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 13
        width  = 8
        height = 6
        properties = {
          title  = "SNS — Notifications Published"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/SNS", "NumberOfMessagesPublished", "TopicName", aws_sns_topic.notifications.name, { stat = "Sum", color = "#00ff41" }],
            [".", "NumberOfNotificationsFailed", ".", ".", { stat = "Sum", color = "#ff6b6b" }],
          ]
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "alarm"
        x      = 0
        y      = 19
        width  = 24
        height = 3
        properties = {
          title = "Alarm Status"
          alarms = [
            aws_cloudwatch_metric_alarm.api_5xx.arn,
            aws_cloudwatch_metric_alarm.api_latency.arn,
            aws_cloudwatch_metric_alarm.dynamo_throttle.arn,
            aws_cloudwatch_metric_alarm.lambda_errors.arn,
            aws_cloudwatch_metric_alarm.dlq_depth.arn,
          ]
        }
      },
    ]
  })
}

# ── Logs Insights Queries ───────────────────────────────────
locals {
  all_log_group_names = [
    aws_cloudwatch_log_group.api.name,
    aws_cloudwatch_log_group.delete_worker.name,
    aws_cloudwatch_log_group.stream_processor.name,
    aws_cloudwatch_log_group.notification.name,
  ]
}

resource "aws_cloudwatch_query_definition" "all_errors" {
  name            = "DeadDrop/All Errors"
  log_group_names = local.all_log_group_names

  query_string = <<-EOT
    fields @timestamp, @log, @message
    | filter @message like /(?i)error|exception|fail/
    | sort @timestamp desc
    | limit 100
  EOT
}

resource "aws_cloudwatch_query_definition" "api_5xx" {
  name            = "DeadDrop/API 5xx Responses"
  log_group_names = [aws_cloudwatch_log_group.api.name]

  query_string = <<-EOT
    fields @timestamp, @message
    | filter @message like /INTERNAL_ERROR|BEDROCK_ERROR|Unhandled error|statusCode.*5\d\d/
    | sort @timestamp desc
    | limit 50
  EOT
}

resource "aws_cloudwatch_query_definition" "cold_starts" {
  name            = "DeadDrop/Cold Starts"
  log_group_names = local.all_log_group_names

  query_string = <<-EOT
    filter @type = "REPORT"
    | fields @log, @duration, @initDuration, @maxMemoryUsed / 1048576 as memoryUsedMB
    | filter ispresent(@initDuration)
    | sort @initDuration desc
    | limit 50
  EOT
}

resource "aws_cloudwatch_query_definition" "slow_requests" {
  name            = "DeadDrop/Slow API Requests (>3s)"
  log_group_names = [aws_cloudwatch_log_group.api.name]

  query_string = <<-EOT
    filter @type = "REPORT"
    | fields @requestId, @duration, @billedDuration, @maxMemoryUsed / 1048576 as memoryUsedMB
    | filter @duration > 3000
    | sort @duration desc
    | limit 50
  EOT
}

resource "aws_cloudwatch_query_definition" "lambda_stats" {
  name            = "DeadDrop/Lambda Performance Stats"
  log_group_names = local.all_log_group_names

  query_string = <<-EOT
    filter @type = "REPORT"
    | stats count() as invocations,
            avg(@duration) as avgDuration,
            max(@duration) as maxDuration,
            percentile(@duration, 99) as p99Duration,
            avg(@maxMemoryUsed / 1048576) as avgMemoryMB
      by @log
  EOT
}
