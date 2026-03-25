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
    sid = "AllowKnowledgeBaseRetrieval"
    actions = [
      "bedrock:Retrieve",
      "bedrock:RetrieveAndGenerate",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:knowledge-base/*",
    ]
  }

  statement {
    sid = "AllowGuardrails"
    actions = [
      "bedrock:ApplyGuardrail",
      "bedrock:GetGuardrail",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:guardrail/*",
    ]
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

# ---------- Bedrock Agent ----------

resource "aws_bedrockagent_agent" "this" {
  agent_name                  = var.agent_name
  agent_resource_role_arn     = aws_iam_role.bedrock_agent.arn
  foundation_model            = var.foundation_model
  instruction                 = var.instruction
  description                 = var.description
  idle_session_ttl_in_seconds = var.idle_session_ttl_in_seconds
  prepare_agent               = true
  tags                        = var.tags
}

resource "terraform_data" "prepare_agent" {
  triggers_replace = [
    aws_bedrockagent_agent.this.agent_id,
    aws_bedrockagent_agent_knowledge_base_association.this.knowledge_base_id,
  ]

  provisioner "local-exec" {
    command = "aws bedrock-agent prepare-agent --agent-id ${aws_bedrockagent_agent.this.agent_id} --region ${data.aws_region.current.id}"
  }

  depends_on = [aws_bedrockagent_agent_knowledge_base_association.this]
}

resource "time_sleep" "wait_for_prepare" {
  create_duration = "30s"

  depends_on = [terraform_data.prepare_agent]
}

resource "aws_bedrockagent_agent_alias" "this" {
  agent_alias_name = var.agent_alias_name
  agent_id         = aws_bedrockagent_agent.this.agent_id
  description      = "Alias for ${var.agent_name}"
  depends_on       = [time_sleep.wait_for_prepare]
  tags             = var.tags
}
