# ---------- KB Agent Outputs ----------

output "kb_agent_id" {
  description = "KB agent ID"
  value       = module.kb_agent.agent_id
}

output "kb_agent_alias_id" {
  description = "KB agent alias ID"
  value       = module.kb_agent.agent_alias_id
}

output "kb_guardrail_id" {
  description = "KB agent guardrail ID"
  value       = module.kb_agent.guardrail_id
}

output "knowledge_base_id" {
  description = "Knowledge base ID"
  value       = module.kb_agent.knowledge_base_id
}

output "kb_docs_bucket" {
  description = "S3 bucket for KB documents"
  value       = module.kb_agent.kb_docs_bucket
}

output "data_source_id" {
  description = "KB data source ID"
  value       = module.kb_agent.data_source_id
}

output "kb_scorer_function_name" {
  description = "KB confidence scorer Lambda name"
  value       = module.kb_agent.scorer_function_name
}

# ---------- Inline Agent Outputs ----------

output "inline_agent_id" {
  description = "Inline file agent ID"
  value       = module.inline_agent.agent_id
}

output "inline_agent_alias_id" {
  description = "Inline file agent alias ID"
  value       = module.inline_agent.agent_alias_id
}

output "inline_guardrail_id" {
  description = "Inline agent guardrail ID"
  value       = module.inline_agent.guardrail_id
}

output "inline_scorer_function_name" {
  description = "Inline confidence scorer Lambda name"
  value       = module.inline_agent.scorer_function_name
}

output "kb_doc_s3_uris" {
  description = "S3 URIs of uploaded KB documents"
  value       = module.kb_agent.kb_doc_s3_uris
}
