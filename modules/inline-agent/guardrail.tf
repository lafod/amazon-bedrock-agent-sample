resource "aws_bedrock_guardrail" "this" {
  name                      = "${var.agent_name}-guardrail"
  description               = "Contextual grounding guardrail for inline file analysis"
  blocked_input_messaging   = "Your request could not be processed. Please rephrase."
  blocked_outputs_messaging = "The response was blocked because it could not be verified against the provided document."

  contextual_grounding_policy_config {
    filters_config {
      type      = "GROUNDING"
      threshold = var.grounding_threshold
    }
    filters_config {
      type      = "RELEVANCE"
      threshold = var.relevance_threshold
    }
  }

  tags = var.tags
}

resource "aws_bedrock_guardrail_version" "this" {
  guardrail_arn = aws_bedrock_guardrail.this.guardrail_arn
  description   = "Published version"
}
