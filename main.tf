resource "aws_api_gateway_rest_api" "mapping_demo" {
  name = "mapping-demo"
}

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.mapping_demo.id
  triggers = {
    redeployment = sha256(jsonencode(aws_api_gateway_rest_api.mapping_demo))
  }

  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_method.transform_method
  ]
}

resource "aws_api_gateway_stage" "api_stage" {
  rest_api_id   = aws_api_gateway_rest_api.mapping_demo.id
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  stage_name    = "prod" # You can use "prod" or any name you prefer
}

resource "aws_api_gateway_model" "json_model" {
  rest_api_id  = aws_api_gateway_rest_api.mapping_demo.id
  name         = "JsonModel"
  content_type = "application/json"
  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    "title"   = "JsonModel"
    "type"    = "object"
    "properties" = {
      "message" = {
        "type" = "string"
      }
    },
    "required" = ["message"]
  })
}

resource "aws_api_gateway_request_validator" "body_validator" {
  rest_api_id                 = aws_api_gateway_rest_api.mapping_demo.id
  name                        = "BodyValidator"
  validate_request_body       = true
  validate_request_parameters = false
}

resource "aws_api_gateway_resource" "transform_resource" {
  rest_api_id = aws_api_gateway_rest_api.mapping_demo.id
  parent_id   = aws_api_gateway_rest_api.mapping_demo.root_resource_id
  path_part   = "transform"
}

resource "aws_api_gateway_method" "transform_method" {
  rest_api_id   = aws_api_gateway_rest_api.mapping_demo.id
  resource_id   = aws_api_gateway_resource.transform_resource.id
  http_method   = "POST"
  authorization = "NONE"

  request_models = {
    "application/json" = aws_api_gateway_model.json_model.name
  }

  request_validator_id = aws_api_gateway_request_validator.body_validator.id
}

data "archive_file" "echo_function" {
  type        = "zip"
  source_file = "index.js"
  output_path = "index.zip"
}

resource "aws_lambda_function" "echo_function" {
  function_name    = "echo_function"
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  role             = aws_iam_role.lambda_exec_role.arn
  filename         = "index.zip"
  source_code_hash = data.archive_file.echo_function.output_base64sha256
}


resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_policy"
  description = "Policy for Lambda execution"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.mapping_demo.id
  resource_id             = aws_api_gateway_resource.transform_resource.id
  http_method             = aws_api_gateway_method.transform_method.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.echo_function.invoke_arn

  request_templates = {
    "application/json" = <<TEMPLATE
{
  "originalCurlPayload": $input.json('$'),
  "requestTransformPayload": {
    "message": "How many fingers Winston?"
  }
}
TEMPLATE
  }

  passthrough_behavior = "WHEN_NO_MATCH"

}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.echo_function.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.mapping_demo.execution_arn}/*/*"
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.mapping_demo.id
  resource_id = aws_api_gateway_resource.transform_resource.id
  http_method = aws_api_gateway_method.transform_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "integration_response_200" {
  rest_api_id = aws_api_gateway_rest_api.mapping_demo.id
  resource_id = aws_api_gateway_resource.transform_resource.id
  http_method = aws_api_gateway_method.transform_method.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code
  depends_on  = [aws_api_gateway_integration.lambda_integration]
  response_templates = {
    "application/json" = <<TEMPLATE
#set($inputRoot = $input.path('$'))
{
    "originalCurlPayload": $input.json('$.body.originalCurlPayload'),
    "requestTransformPayload": $input.json('$.body.requestTransformPayload'),
    "lambdaTransformPayload": $input.json('$.body.lambdaTransformPayload'),
    "responseTransformPayload": { "message": "All pigs are created equal, but some pigs are more equal than others" }
}
TEMPLATE
  }
}

output "url" {
  value = "https://${aws_api_gateway_rest_api.mapping_demo.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/prod/transform"
}

output "res-res-rest_api_id" {
  value = aws_api_gateway_resource.transform_resource.rest_api_id
}

output "gw-demo-res-root_resource_id" {
  value = aws_api_gateway_rest_api.mapping_demo.id
}
