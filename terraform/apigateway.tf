resource "aws_api_gateway_rest_api" "this {
  name = var.api_name
}

module "hello1" {
  source = "./modules/httpmethod"
  apigw_id = aws_api_gateway_rest_api.this.id
  apigw_resource_id = aws_api_gateway_rest_api.this.root_resource_id
  path = "hello1"
  http_method = "POST"
  lambda_arn = aws_lambda_function.lambda_hello1.invoke_arn
}

resource "aws_lambda_permission" "hello1" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_hello1.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${replace(aws_api_gateway_deployment.this.execution_arn, var.stage_name, "")}*/*"
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(jsonencode(module.hello1))
  }

  depends_on = [
    module.hello1
  ]
}

resource "aws_api_gateway_method_settings" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = var.stage_name
  method_path = "*/*"

  settings {
    logging_level = "INFO"
    data_trace_enabled = true
    metrics_enabled = true
  }

  depends_on = [
    aws_api_gateway_deployment.this
  ]
}

resource "aws_api_gateway_stage" "this" {
  stage_name    = var.stage_name
  rest_api_id   = aws_api_gateway_deployment.this.rest_api_id
  deployment_id = aws_api_gateway_deployment.this.id
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.this.id}/${var.stage_name}"
  retention_in_days = 2
}
