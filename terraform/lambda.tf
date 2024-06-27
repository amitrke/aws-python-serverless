# Terraform code to zip the python code from ../python folder and deploy it to AWS Lambda
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_role_hello1" {
  name               = "lambda_role_hello1"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "../python/hello.py"
  output_path = "lambda_function_payload.zip"
}

resource "aws_lambda_function" "lambda_hello1" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "lambda_function_payload.zip"
  function_name = "lambda_hello1"
  role          = aws_iam_role.lambda_role_hello1.arn
  handler       = "hello.lambda_handler"

  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "python3.8"

  environment {
    variables = {
      foo = "bar"
    }
  }
}

#API Gateway

resource "aws_iam_role_policy_attachment" "lambda-iam-role-policy-attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role_hello1.name
}

resource "aws_api_gateway_rest_api" "hello1_api" {
  name        = "hello1_api"
  description = "API Gateway for lambda"
}

resource "aws_api_gateway_resource" "hello1_api_root" {
  rest_api_id = aws_api_gateway_rest_api.hello1_api.id
  parent_id   = aws_api_gateway_rest_api.hello1_api.root_resource_id
  path_part   = "hello1"
}

resource "aws_api_gateway_method" "hello1_api_method" {
  rest_api_id   = aws_api_gateway_rest_api.hello1_api.id
  resource_id   = aws_api_gateway_resource.hello1_api_root.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "hello1_api_method_response" {
  rest_api_id = aws_api_gateway_rest_api.hello1_api.id
  resource_id = aws_api_gateway_resource.hello1_api_root.id
  http_method = aws_api_gateway_method.hello1_api_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Content-Type" = true
  }

  response_models = {
    "application/json" = "Empty"
  }

  depends_on = [aws_api_gateway_method.hello1_api_method]
}

resource "aws_api_gateway_integration" "hello1_api_integration" {
  rest_api_id = aws_api_gateway_rest_api.hello1_api.id
  resource_id = aws_api_gateway_resource.hello1_api_root.id
  http_method = aws_api_gateway_method.hello1_api_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_hello1.invoke_arn

  depends_on = [aws_api_gateway_method.hello1_api_method]
}

resource "aws_api_gateway_integration_response" "hello1_api_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.hello1_api.id
  resource_id = aws_api_gateway_resource.hello1_api_root.id
  http_method = aws_api_gateway_method.hello1_api_method.http_method
  status_code = aws_api_gateway_method_response.hello1_api_method_response.status_code

  response_parameters = {
    "method.response.header.Content-Type" = "'application/json'"
  }

  response_templates = {
    "application/json" = ""
  }

  depends_on = [aws_api_gateway_integration.hello1_api_integration]
}

resource "aws_api_gateway_deployment" "hello1_api_deployment" {
  depends_on = [aws_api_gateway_integration.hello1_api_integration]
  rest_api_id = aws_api_gateway_rest_api.hello1_api.id
  stage_name  = "test"
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_hello1.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_deployment.hello1_api_deployment.execution_arn}/*/*"
}


