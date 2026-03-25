# ---------- S3 Bucket for KB Documents ----------

resource "aws_s3_bucket" "kb_docs" {
  bucket_prefix = "${var.agent_name}-kb-docs-"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "kb_docs" {
  bucket = aws_s3_bucket.kb_docs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ---------- S3 Vectors for Knowledge Base Storage ----------

resource "aws_s3vectors_vector_bucket" "kb" {
  vector_bucket_name = "${var.agent_name}-kb-vectors"
}

resource "aws_s3vectors_index" "kb" {
  index_name         = "${var.agent_name}-kb-index"
  vector_bucket_name = aws_s3vectors_vector_bucket.kb.vector_bucket_name
  data_type          = "float32"
  dimension          = 1024
  distance_metric    = "cosine"
}

# ---------- IAM Role for Knowledge Base ----------

data "aws_iam_policy_document" "kb_trust" {
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
  }
}

data "aws_iam_policy_document" "kb_permissions" {
  statement {
    sid     = "AllowEmbeddingModel"
    actions = ["bedrock:InvokeModel"]
    resources = [
      "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.id}::foundation-model/amazon.titan-embed-text-v2:0"
    ]
  }

  statement {
    sid     = "AllowS3Access"
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.kb_docs.arn,
      "${aws_s3_bucket.kb_docs.arn}/*",
    ]
  }

  statement {
    sid       = "AllowS3VectorsAccess"
    actions   = ["s3vectors:*"]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3vectors:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:bucket/${var.agent_name}-kb-vectors",
      "arn:${data.aws_partition.current.partition}:s3vectors:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:bucket/${var.agent_name}-kb-vectors/*",
    ]
  }
}

resource "aws_iam_role" "kb" {
  name_prefix        = "AmazonBedrockExecutionRoleForKB_"
  assume_role_policy = data.aws_iam_policy_document.kb_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "kb" {
  name   = "BedrockKBAccess"
  role   = aws_iam_role.kb.id
  policy = data.aws_iam_policy_document.kb_permissions.json
}

# ---------- Knowledge Base ----------

resource "aws_bedrockagent_knowledge_base" "this" {
  name     = "${var.agent_name}-kb"
  role_arn = aws_iam_role.kb.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.id}::foundation-model/amazon.titan-embed-text-v2:0"
      embedding_model_configuration {
        bedrock_embedding_model_configuration {
          dimensions          = 1024
          embedding_data_type = "FLOAT32"
        }
      }
    }
  }

  storage_configuration {
    type = "S3_VECTORS"
    s3_vectors_configuration {
      index_arn = aws_s3vectors_index.kb.index_arn
    }
  }

  tags = var.tags
}

resource "aws_bedrockagent_data_source" "this" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.this.id
  name              = "${var.agent_name}-s3-source"
  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = aws_s3_bucket.kb_docs.arn
    }
  }
}

resource "aws_bedrockagent_agent_knowledge_base_association" "this" {
  agent_id             = aws_bedrockagent_agent.this.agent_id
  description          = "Knowledge base for ${var.agent_name}"
  knowledge_base_id    = aws_bedrockagent_knowledge_base.this.id
  knowledge_base_state = "ENABLED"
}

resource "aws_s3_object" "kb_docs" {
  for_each = var.kb_doc_files

  bucket = aws_s3_bucket.kb_docs.id
  key    = each.key
  source = each.value
  etag   = filemd5(each.value)
}
