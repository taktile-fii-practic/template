# ── Lambda Functions ─────────────────────────────────────────
resource "aws_lambda_function" "api" {
  depends_on = [null_resource.lambda_build, aws_cloudwatch_log_group.api]

  function_name    = "${var.project_name}-api"
  role             = aws_iam_role.api.arn
  handler          = "api.handler"
  runtime          = "nodejs20.x"
  architectures    = ["arm64"]
  memory_size      = 256
  timeout          = 30
  filename         = "${local.build_dir}/api.zip"
  source_code_hash = local.source_hash
  publish          = true
  logging_config {
    log_format = "JSON"
    log_group = aws_cloudwatch_log_group.api.name
  }

  environment {
    variables = {
    #   TABLE_NAME       = aws_dynamodb_table.secrets.name # TODO: Uncomment this when the table is created
    #   QUEUE_URL        = aws_sqs_queue.delete_queue.url # TODO: Uncomment this when the queue is created
    #   KMS_KEY_ID       = aws_kms_key.encryption.id # TODO: Uncomment this when the KMS key is created
      BEDROCK_MODEL_ID = var.bedrock_model_id
    }
  }
}

resource "aws_lambda_alias" "api_live" {
  name             = "live"
  function_name    = aws_lambda_function.api.function_name
  function_version = aws_lambda_function.api.version
}