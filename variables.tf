variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "bedrock-grounding"
}

variable "foundation_model" {
  description = "Foundation model or inference profile ID"
  type        = string
  default     = "us.anthropic.claude-sonnet-4-20250514-v1:0"
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
