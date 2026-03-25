data "archive_file" "confidence_scorer" {
  type        = "zip"
  source_file = "${path.module}/lambda/confidence_scorer.py"
  output_path = "${path.module}/lambda/confidence_scorer.zip"
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_permissions" {
  statement {
    sid     = "AllowBedrockAgent"
    actions = ["bedrock:InvokeAgent"]
    resources = [
      "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:agent-alias/*",
    ]
  }

  statement {
    sid     = "AllowApplyGuardrail"
    actions = ["bedrock:ApplyGuardrail"]
    resources = [
      "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:guardrail/*",
    ]
  }

  statement {
    sid     = "AllowLogs"
    actions = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "lambda_scorer" {
  name_prefix        = "${var.agent_name}-scorer-"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "lambda_scorer" {
  name   = "ScorerAccess"
  role   = aws_iam_role.lambda_scorer.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

resource "aws_lambda_function" "confidence_scorer" {
  function_name    = "${var.agent_name}-confidence-scorer"
  role             = aws_iam_role.lambda_scorer.arn
  handler          = "confidence_scorer.handler"
  runtime          = "python3.12"
  timeout          = 120
  filename         = data.archive_file.confidence_scorer.output_path
  source_code_hash = data.archive_file.confidence_scorer.output_base64sha256

  environment {
    variables = {
      AGENT_ID          = aws_bedrockagent_agent.this.agent_id
      AGENT_ALIAS_ID    = aws_bedrockagent_agent_alias.this.agent_alias_id
      GUARDRAIL_ID      = aws_bedrock_guardrail.this.guardrail_id
      GUARDRAIL_VERSION = aws_bedrock_guardrail_version.this.version
    }
  }

  tags = var.tags
}

resource "aws_lambda_function_url" "confidence_scorer" {
  function_name      = aws_lambda_function.confidence_scorer.function_name
  authorization_type = "AWS_IAM"
}
