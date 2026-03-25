output "agent_id" {
  value = aws_bedrockagent_agent.this.agent_id
}

output "agent_alias_id" {
  value = aws_bedrockagent_agent_alias.this.agent_alias_id
}

output "guardrail_id" {
  value = aws_bedrock_guardrail.this.guardrail_id
}

output "scorer_function_name" {
  value = aws_lambda_function.inline_scorer.function_name
}

output "scorer_url" {
  value = aws_lambda_function_url.inline_scorer.function_url
}
