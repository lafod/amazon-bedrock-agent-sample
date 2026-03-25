variable "agent_name" {
  description = "Name of the inline file agent"
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
  default     = <<-EOT
    You are a document analysis assistant. Users will send you files as attachments.
    Analyze the file content and answer questions based strictly on the information
    provided in the file. If the answer is not in the file, say so clearly.
    Do not make up information that is not in the provided document.
  EOT
}

variable "idle_session_ttl_in_seconds" {
  description = "Idle session timeout in seconds"
  type        = number
  default     = 600
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

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
