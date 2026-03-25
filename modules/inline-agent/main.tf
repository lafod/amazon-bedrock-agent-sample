# ---------- Data Sources ----------

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

# ---------- IAM Role for the Bedrock Agent ----------

data "aws_iam_policy_document" "agent_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "AWS:SourceArn"
      values = [
        "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:agent/*"
      ]
    }
  }
}

data "aws_iam_policy_document" "agent_permissions" {
  statement {
    sid = "AllowModelInvocation"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*",
      "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/*",
    ]
  }

  statement {
    sid     = "AllowInferenceProfileAccess"
    actions = ["bedrock:GetInferenceProfile"]
    resources = [
      "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/*",
    ]
  }

  statement {
    sid     = "AllowGuardrails"
    actions = ["bedrock:ApplyGuardrail", "bedrock:GetGuardrail"]
    resources = [
      "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:guardrail/*",
    ]
  }

  statement {
    sid     = "AllowS3Read"
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "bedrock_agent" {
  name_prefix        = "AmazonBedrockExecutionRoleForAgents_"
  assume_role_policy = data.aws_iam_policy_document.agent_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "bedrock_agent" {
  name   = "BedrockAgentModelAccess"
  role   = aws_iam_role.bedrock_agent.id
  policy = data.aws_iam_policy_document.agent_permissions.json
}

# ---------- Bedrock Agent (no KB, accepts inline files) ----------

resource "aws_bedrockagent_agent" "this" {
  agent_name                  = var.agent_name
  agent_resource_role_arn     = aws_iam_role.bedrock_agent.arn
  foundation_model            = var.foundation_model
  instruction                 = var.instruction
  idle_session_ttl_in_seconds = var.idle_session_ttl_in_seconds
  prepare_agent               = true
  tags                        = var.tags
}

resource "aws_bedrockagent_agent_alias" "this" {
  agent_alias_name = "live"
  agent_id         = aws_bedrockagent_agent.this.agent_id
  description      = "Alias for ${var.agent_name}"
  tags             = var.tags
}
