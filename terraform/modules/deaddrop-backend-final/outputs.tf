output "api_url" {
  description = "Custom domain API URL"
  value       = "https://${var.domain_name}"
}

output "api_gateway_url" {
  description = "Default API Gateway endpoint URL"
  value       = aws_apigatewayv2_api.http.api_endpoint
}

output "table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.secrets.name
}

output "api_id" {
  description = "API Gateway HTTP API ID"
  value       = aws_apigatewayv2_api.http.id
}

output "api_function_name" {
  description = "API Lambda function name"
  value       = aws_lambda_function.api.function_name
}
