output "agent_id" {
  value = aws_bedrockagent_agent.this.agent_id
}

output "agent_arn" {
  value = aws_bedrockagent_agent.this.agent_arn
}

output "agent_alias_id" {
  value = aws_bedrockagent_agent_alias.this.agent_alias_id
}

output "guardrail_id" {
  value = aws_bedrock_guardrail.this.guardrail_id
}

output "guardrail_arn" {
  value = aws_bedrock_guardrail.this.guardrail_arn
}

output "knowledge_base_id" {
  value = aws_bedrockagent_knowledge_base.this.id
}

output "kb_docs_bucket" {
  value = aws_s3_bucket.kb_docs.id
}

output "data_source_id" {
  value = aws_bedrockagent_data_source.this.data_source_id
}

output "scorer_function_name" {
  value = aws_lambda_function.confidence_scorer.function_name
}

output "scorer_url" {
  value = aws_lambda_function_url.confidence_scorer.function_url
}

output "kb_doc_s3_uris" {
  description = "S3 URIs of uploaded KB documents"
  value = {
    for key, obj in aws_s3_object.kb_docs : key => "s3://${obj.bucket}/${obj.key}"
  }
}
