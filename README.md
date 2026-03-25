
# Bedrock Agent with Contextual Grounding Confidence Scoring

Terraform project that deploys two types of Amazon Bedrock agents, each with a confidence scoring layer powered by guardrail contextual grounding checks.

## Architecture

Two agent patterns, both using a two-step scoring approach:

```
User Query
    │
    ▼
Lambda (Confidence Scorer)
    │
    ├──► Step 1: InvokeAgent (with trace enabled)
    │       └── Agent processes query (via KB or inline file)
    │
    └──► Step 2: ApplyGuardrail
            ├── Grounding source = KB citations or file content
            ├── Query = user question
            ├── Content = agent response
            └── Returns grounding + relevance scores
```

### KB Agent (`modules/kb-agent`)
Agent with an S3-backed knowledge base. Documents are ingested, vectorized (Titan Embed V2), and stored in S3 Vectors. The scorer Lambda extracts KB citations from the agent trace and uses them as the grounding source.

### Inline Agent (`modules/inline-agent`)
Agent with no knowledge base. Users send files as attachments via `sessionState.files`. The scorer Lambda reads the file content and passes it directly as the grounding source to ApplyGuardrail.

## Project Structure

```
├── main.tf                              # Root: calls both modules
├── variables.tf                         # Root: shared variables
├── outputs.tf                           # Root: outputs from both modules
├── README.md
├── kb-docs/
│   └── company-policies.txt             # Sample KB document
└── modules/
    ├── kb-agent/                        # Agent + KB + guardrail + scorer
    │   ├── main.tf                      # Agent, IAM, alias
    │   ├── knowledge_base.tf            # S3 bucket, S3 Vectors, KB, data source
    │   ├── guardrail.tf                 # Contextual grounding guardrail
    │   ├── lambda.tf                    # Confidence scorer Lambda
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── lambda/
    │       └── confidence_scorer.py
    └── inline-agent/                    # Agent (no KB) + guardrail + scorer
        ├── main.tf                      # Agent, IAM, alias
        ├── guardrail.tf                 # Contextual grounding guardrail
        ├── lambda.tf                    # Inline file scorer Lambda
        ├── variables.tf
        ├── outputs.tf
        └── lambda/
            └── inline_scorer.py
```

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI v2 configured
- Foundation model enabled in your account (default: Claude Sonnet 4 via `us.` inference profile)

## Deployment

```bash
terraform init
terraform plan
terraform apply
```

After apply, ingest documents into the KB agent's knowledge base:

```bash
aws bedrock-agent start-ingestion-job \
  --knowledge-base-id $(terraform output -raw knowledge_base_id) \
  --data-source-id $(terraform output -raw data_source_id)
```

## Testing

### KB Agent

```bash
aws lambda invoke \
  --function-name $(terraform output -raw kb_scorer_function_name) \
  --cli-binary-format raw-in-base64-out \
  --payload '{"query": "How many vacation days do employees get?"}' \
  response.json

cat response.json | python3 -m json.tool
```

```bash
aws lambda invoke \
  --function-name $(terraform output -raw kb_scorer_function_name) \
  --cli-binary-format raw-in-base64-out \
  --payload '{"query": "Using information from the knowledge base only , what is the capital of england?"}' \
  response.json

cat response.json | python3 -m json.tool
```

### Inline Agent

With an S3 file:

```bash
aws lambda invoke \
  --function-name $(terraform output -raw inline_scorer_function_name) \
  --cli-binary-format raw-in-base64-out \
  --payload '{
    "query": "What is the 401k employer match?",
    "file": {
      "s3_uri": "'$(terraform output -json kb_doc_s3_uris | python3 -c "import sys,json; print(json.load(sys.stdin)[\"company-policies.txt\"])")'",
      "name": "company-policies.txt"
    }
  }' \
  response.json

cat response.json | python3 -m json.tool
```

With inline base64 content:

```bash
aws lambda invoke \
  --function-name $(terraform output -raw inline_scorer_function_name) \
  --cli-binary-format raw-in-base64-out \
  --payload '{
    "query": "What is the 401k employer match?",
    "file": {
      "base64_content": "'$(base64 < kb-docs/company-policies.txt)'",
      "media_type": "text/plain",
      "name": "policies.txt"
    }
  }' \
  response.json

cat response.json | python3 -m json.tool
```

### Test the guardrail directly

```bash
aws bedrock-runtime apply-guardrail \
  --guardrail-identifier $(terraform output -raw kb_guardrail_id) \
  --guardrail-version 1 \
  --source OUTPUT \
  --content '[
    {"text": {"text": "All full-time employees receive 15 days of paid vacation per year.", "qualifiers": ["grounding_source"]}},
    {"text": {"text": "How many vacation days do employees get?", "qualifiers": ["query"]}},
    {"text": {"text": "Full-time employees receive 15 days of paid vacation per year."}}
  ]'
```

### Example response

```json
{
  "query": "How many vacation days do employees get?",
  "response": "Full-time employees receive 15 days of paid vacation per year.",
  "citations": [
    {
      "text": "All full-time employees receive 15 days of paid...",
      "source": "s3://...-kb-docs-.../company-policies.txt"
    }
  ],
  "confidence": {
    "grounding_score": 0.95,
    "relevance_score": 0.92,
    "action": "NONE",
    "blocked": false
  }
}
```

### Test queries

| Query | Expected Result |
|-------|----------------|
| "How many vacation days do full-time employees get?" | High grounding + relevance |
| "What is the 401k employer match?" | High grounding + relevance |
| "What is the company's stock option plan?" | Low grounding (not in source) |
| "Does the company offer parental leave?" | Low grounding (not in source) |

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-east-1` | AWS region |
| `project_name` | `bedrock-grounding` | Prefix for all resource names |
| `foundation_model` | `us.anthropic.claude-sonnet-4-20250514-v1:0` | Model inference profile ID |
| `grounding_threshold` | `0.7` | Minimum grounding confidence (0-0.99) |
| `relevance_threshold` | `0.7` | Minimum relevance confidence (0-0.99) |

## Adding KB documents

Place files in `kb-docs/` and add them to the module call in `main.tf`:

```hcl
kb_doc_files = {
  "company-policies.txt" = "${path.module}/kb-docs/company-policies.txt"
  "new-document.pdf"     = "${path.module}/kb-docs/new-document.pdf"
}
```

Or upload directly and trigger ingestion:

```bash
aws s3 cp ./my-docs/ s3://$(terraform output -raw kb_docs_bucket)/ --recursive

aws bedrock-agent start-ingestion-job \
  --knowledge-base-id $(terraform output -raw knowledge_base_id) \
  --data-source-id $(terraform output -raw data_source_id)
```

## Cleanup

```bash
terraform destroy
```
