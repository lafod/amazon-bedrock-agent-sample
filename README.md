# amazon-bedrock-samples



## Getting started

To make it easy for you to get started with GitLab, here's a list of recommended next steps.

Already a pro? Just edit this README.md and make it your own. Want to make it easy? [Use the template at the bottom](#editing-this-readme)!

## Add your files

- [ ] [Create](https://docs.gitlab.com/ee/user/project/repository/web_editor.html#create-a-file) or [upload](https://docs.gitlab.com/ee/user/project/repository/web_editor.html#upload-a-file) files
- [ ] [Add files using the command line](https://docs.gitlab.com/topics/git/add_files/#add-files-to-a-git-repository) or push an existing Git repository with the following command:

```
cd existing_repo
git remote add origin https://gitlab.aws.dev/afod/amazon-bedrock-samples.git
git branch -M main
git push -uf origin main
```

## Integrate with your tools

- [ ] [Set up project integrations](https://gitlab.aws.dev/afod/amazon-bedrock-samples/-/settings/integrations)

## Collaborate with your team

- [ ] [Invite team members and collaborators](https://docs.gitlab.com/ee/user/project/members/)
- [ ] [Create a new merge request](https://docs.gitlab.com/ee/user/project/merge_requests/creating_merge_requests.html)
- [ ] [Automatically close issues from merge requests](https://docs.gitlab.com/ee/user/project/issues/managing_issues.html#closing-issues-automatically)
- [ ] [Enable merge request approvals](https://docs.gitlab.com/ee/user/project/merge_requests/approvals/)
- [ ] [Set auto-merge](https://docs.gitlab.com/user/project/merge_requests/auto_merge/)

## Test and Deploy

Use the built-in continuous integration in GitLab.

- [ ] [Get started with GitLab CI/CD](https://docs.gitlab.com/ee/ci/quick_start/)
- [ ] [Analyze your code for known vulnerabilities with Static Application Security Testing (SAST)](https://docs.gitlab.com/ee/user/application_security/sast/)
- [ ] [Deploy to Kubernetes, Amazon EC2, or Amazon ECS using Auto Deploy](https://docs.gitlab.com/ee/topics/autodevops/requirements.html)
- [ ] [Use pull-based deployments for improved Kubernetes management](https://docs.gitlab.com/ee/user/clusters/agent/)
- [ ] [Set up protected environments](https://docs.gitlab.com/ee/ci/environments/protected_environments.html)

***

# Editing this README

When you're ready to make this README your own, just edit this file and use the handy template below (or feel free to structure it however you want - this is just a starting point!). Thanks to [makeareadme.com](https://www.makeareadme.com/) for this template.

## Suggestions for a good README

Every project is different, so consider which of these sections apply to yours. The sections used in the template are suggestions for most open source projects. Also keep in mind that while a README can be too long and detailed, too long is better than too short. If you think your README is too long, consider utilizing another form of documentation rather than cutting out information.

## Name
Choose a self-explaining name for your project.

## Description
Let people know what your project can do specifically. Provide context and add a link to any reference visitors might be unfamiliar with. A list of Features or a Background subsection can also be added here. If there are alternatives to your project, this is a good place to list differentiating factors.

## Badges
On some READMEs, you may see small images that convey metadata, such as whether or not all the tests are passing for the project. You can use Shields to add some to your README. Many services also have instructions for adding a badge.

## Visuals
Depending on what you are making, it can be a good idea to include screenshots or even a video (you'll frequently see GIFs rather than actual videos). Tools like ttygif can help, but check out Asciinema for a more sophisticated method.

## Installation
Within a particular ecosystem, there may be a common way of installing things, such as using Yarn, NuGet, or Homebrew. However, consider the possibility that whoever is reading your README is a novice and would like more guidance. Listing specific steps helps remove ambiguity and gets people to using your project as quickly as possible. If it only runs in a specific context like a particular programming language version or operating system or has dependencies that have to be installed manually, also add a Requirements subsection.

## Usage
Use examples liberally, and show the expected output if you can. It's helpful to have inline the smallest example of usage that you can demonstrate, while providing links to more sophisticated examples if they are too long to reasonably include in the README.

## Support
Tell people where they can go to for help. It can be any combination of an issue tracker, a chat room, an email address, etc.

## Roadmap
If you have ideas for releases in the future, it is a good idea to list them in the README.

## Contributing
State if you are open to contributions and what your requirements are for accepting them.

For people who want to make changes to your project, it's helpful to have some documentation on how to get started. Perhaps there is a script that they should run or some environment variables that they need to set. Make these steps explicit. These instructions could also be useful to your future self.

You can also document commands to lint the code or run tests. These steps help to ensure high code quality and reduce the likelihood that the changes inadvertently break something. Having instructions for running tests is especially helpful if it requires external setup, such as starting a Selenium server for testing in a browser.

## Authors and acknowledgment
Show your appreciation to those who have contributed to the project.

## License
For open source projects, say how it is licensed.

## Project status
If you have run out of energy or time for your project, put a note at the top of the README saying that development has slowed down or stopped completely. Someone may choose to fork your project or volunteer to step in as a maintainer or owner, allowing your project to keep going. You can also make an explicit request for maintainers.
=======
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
