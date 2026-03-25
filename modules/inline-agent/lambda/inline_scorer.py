"""
Lambda that accepts a user query + file (S3 URI or base64 content),
invokes a Bedrock agent with the file attached, then calls ApplyGuardrail
to score the response for grounding and relevance against the file content.
"""

import base64
import json
import logging
import os
import uuid

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

bedrock_agent = boto3.client("bedrock-agent-runtime")
bedrock_runtime = boto3.client("bedrock-runtime")
s3 = boto3.client("s3")

AGENT_ID = os.environ["AGENT_ID"]
AGENT_ALIAS_ID = os.environ["AGENT_ALIAS_ID"]
GUARDRAIL_ID = os.environ["GUARDRAIL_ID"]
GUARDRAIL_VERSION = os.environ.get("GUARDRAIL_VERSION", "1")


def handler(event, context):
    user_query = event.get("query", "")
    session_id = event.get("session_id", str(uuid.uuid4()))
    file_config = event.get("file", {})

    logger.info("=== Inline Scorer Invoked ===")
    logger.info(f"User query: {user_query}")
    logger.info(f"Session ID: {session_id}")
    logger.info(f"File config: {json.dumps({k: v for k, v in file_config.items() if k != 'base64_content'})}")

    if not user_query:
        return _error("query is required")
    if not file_config:
        return _error("file is required (provide s3_uri or base64_content + media_type)")

    file_content, agent_file = _prepare_file(file_config)
    if not file_content:
        return _error("Could not read file content")

    logger.info(f"File content length: {len(file_content)} chars")

    agent_result = _invoke_agent(user_query, session_id, agent_file)
    logger.info(f"Agent response: {agent_result['response_text'][:500]}")

    confidence = _apply_guardrail(user_query, file_content, agent_result["response_text"])
    logger.info(f"Confidence result: {json.dumps(confidence, default=str)}")

    result = {
        "statusCode": 200,
        "body": {
            "query": user_query,
            "session_id": session_id,
            "response": agent_result["response_text"],
            "confidence": confidence,
        },
    }

    logger.info("=== Inline Scorer Complete ===")
    return result


def _prepare_file(file_config):
    name = file_config.get("name", "document.txt")

    if "s3_uri" in file_config:
        uri = file_config["s3_uri"]
        logger.info(f"S3 file path: {uri}")
        # Read file content from S3 for grounding
        stripped = uri.replace("s3://", "")
        if "/" not in stripped:
            return None, None
        bucket, key = stripped.split("/", 1)
        obj = s3.get_object(Bucket=bucket, Key=key)
        file_bytes = obj["Body"].read()
        file_content = file_bytes.decode("utf-8", errors="replace")

        agent_file = {
            "name": name,
            "source": {"sourceType": "S3", "s3Location": {"uri": uri}},
            "useCase": "CHAT",
        }
        return file_content, agent_file

    elif "base64_content" in file_config:
        logger.info("File source: base64 inline content")
        file_bytes = base64.b64decode(file_config["base64_content"])
        media_type = file_config.get("media_type", "text/plain")
        file_content = file_bytes.decode("utf-8", errors="replace")

        agent_file = {
            "name": name,
            "source": {
                "sourceType": "BYTE_CONTENT",
                "byteContent": {"data": file_bytes, "mediaType": media_type},
            },
            "useCase": "CHAT",
        }
        return file_content, agent_file

    return None, None


def _invoke_agent(query, session_id, agent_file):
    response = bedrock_agent.invoke_agent(
        agentId=AGENT_ID,
        agentAliasId=AGENT_ALIAS_ID,
        sessionId=session_id,
        inputText=query,
        enableTrace=True,
        sessionState={"files": [agent_file]},
    )

    response_text = ""
    for event in response["completion"]:
        if "chunk" in event:
            chunk = event["chunk"]
            if "bytes" in chunk:
                response_text += chunk["bytes"].decode("utf-8")

    return {"response_text": response_text}


def _apply_guardrail(query, grounding_source, response_text):
    if not grounding_source or not response_text:
        return {
            "grounding_score": None, "relevance_score": None,
            "action": "SKIPPED", "reason": "No grounding source or response to evaluate",
        }

    content = [
        {"text": {"text": grounding_source[:100000], "qualifiers": ["grounding_source"]}},
        {"text": {"text": query[:1000], "qualifiers": ["query"]}},
        {"text": {"text": response_text[:5000]}},
    ]

    result = bedrock_runtime.apply_guardrail(
        guardrailIdentifier=GUARDRAIL_ID,
        guardrailVersion=GUARDRAIL_VERSION,
        source="OUTPUT",
        content=content,
    )

    scores = {"grounding_score": None, "relevance_score": None}
    action = result.get("action", "NONE")

    for assessment in result.get("assessments", []):
        grounding_policy = assessment.get("contextualGroundingPolicy", {})
        for f in grounding_policy.get("filters", []):
            if f["type"] == "GROUNDING":
                scores["grounding_score"] = f.get("score", None)
            elif f["type"] == "RELEVANCE":
                scores["relevance_score"] = f.get("score", None)

    return {**scores, "action": action, "blocked": action == "GUARDRAIL_INTERVENED"}


def _error(message):
    logger.error(f"Error: {message}")
    return {"statusCode": 400, "body": {"error": message}}
