# Terraform code to zip the python code from ../python folder and deploy it to AWS Lambda
resource "aws_iam_role" "lambda_execution_role" {
  name = "MyLambdaHandlerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_execution_kms_decrypt" {
  name        = "lambda_execution_kms_decrypt_policy"
  description = "IAM policy for decrypting with KMS in Lambda"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Decrypt"
        ]
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_execution_kms_decrypt_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_execution_kms_decrypt.arn
}

resource "aws_iam_role_policy_attachment" "lambda_execution_role_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_execution_role.name
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
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "hello.lambda_handler"

  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "python3.8"

  environment {
    variables = {
      foo = "bar"
    }
  }
}
