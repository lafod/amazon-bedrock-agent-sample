variable "agent_name" {
  description = "Name of the Bedrock agent"
  type        = string
}

variable "foundation_model" {
  description = "Foundation model or inference profile ID"
  type        = string
  default     = "us.anthropic.claude-sonnet-4-20250514-v1:0"
}

variable "instruction" {
  description = "Agent instructions"
  type        = string
  default     = "You are a helpful assistant. Answer user questions clearly and concisely."
}

variable "description" {
  description = "Agent description"
  type        = string
  default     = "A Bedrock agent with knowledge base"
}

variable "idle_session_ttl_in_seconds" {
  description = "Idle session timeout in seconds"
  type        = number
  default     = 600
}

variable "agent_alias_name" {
  description = "Name for the agent alias"
  type        = string
  default     = "live"
}

variable "grounding_threshold" {
  description = "Minimum grounding confidence score (0-0.99)"
  type        = number
  default     = 0.7
}

variable "relevance_threshold" {
  description = "Minimum relevance confidence score (0-0.99)"
  type        = number
  default     = 0.7
}

variable "kb_doc_files" {
  description = "Map of S3 key to local file path for KB documents"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
