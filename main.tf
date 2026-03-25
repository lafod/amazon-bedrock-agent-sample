terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------- KB Agent: Agent with Knowledge Base + Confidence Scorer ----------

module "kb_agent" {
  source = "./modules/kb-agent"

  agent_name          = "${var.project_name}-kb-agent"
  foundation_model    = var.foundation_model
  instruction         = "You are a helpful assistant. Answer user questions based on the knowledge base. Be accurate and cite your sources."
  description         = "Bedrock agent with knowledge base and contextual grounding"
  agent_alias_name    = "live"
  grounding_threshold = var.grounding_threshold
  relevance_threshold = var.relevance_threshold

  kb_doc_files = {
    "company-policies.txt"          = "${path.module}/kb-docs/company-policies.txt"
    "african-countries-capitals.txt" = "${path.module}/kb-docs/african-countries-capitals.txt"
  }

  tags = var.tags
}

# ---------- Inline Agent: Agent with File Attachments + Confidence Scorer ----------

module "inline_agent" {
  source = "./modules/inline-agent"

  agent_name          = "${var.project_name}-inline-agent"
  foundation_model    = var.foundation_model
  grounding_threshold = var.grounding_threshold
  relevance_threshold = var.relevance_threshold
  tags                = var.tags
}
