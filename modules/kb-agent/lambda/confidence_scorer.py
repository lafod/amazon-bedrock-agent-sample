"""
Lambda that invokes a Bedrock agent, extracts KB citations from the trace,
then calls ApplyGuardrail to get grounding and relevance confidence scores.
"""

import json
import os
import uuid

import boto3

bedrock_agent = boto3.client("bedrock-agent-runtime")
bedrock_runtime = boto3.client("bedrock-runtime")

AGENT_ID = os.environ["AGENT_ID"]
AGENT_ALIAS_ID = os.environ["AGENT_ALIAS_ID"]
GUARDRAIL_ID = os.environ["GUARDRAIL_ID"]
GUARDRAIL_VERSION = os.environ.get("GUARDRAIL_VERSION", "1")


def handler(event, context):
    user_query = event.get("query", "")
    session_id = event.get("session_id", str(uuid.uuid4()))

    if not user_query:
        return {"statusCode": 400, "body": {"error": "query is required"}}

    agent_response = _invoke_agent(user_query, session_id)

    guardrail_result = _apply_guardrail(
        user_query,
        agent_response["grounding_sources"],
        agent_response["response_text"],
    )

    return {
        "statusCode": 200,
        "body": {
            "query": user_query,
            "session_id": session_id,
            "response": agent_response["response_text"],
            "citations": agent_response["citations"],
            "confidence": guardrail_result,
        },
    }


def _invoke_agent(query, session_id):
    response = bedrock_agent.invoke_agent(
        agentId=AGENT_ID,
        agentAliasId=AGENT_ALIAS_ID,
        sessionId=session_id,
        inputText=query,
        enableTrace=True,
    )

    response_text = ""
    grounding_sources = []
    citations = []

    for event in response["completion"]:
        if "chunk" in event:
            chunk = event["chunk"]
            if "bytes" in chunk:
                response_text += chunk["bytes"].decode("utf-8")
            if "attribution" in chunk:
                for citation in chunk["attribution"].get("citations", []):
                    for ref in citation.get("retrievedReferences", []):
                        source_text = ref.get("content", {}).get("text", "")
                        source_uri = (
                            ref.get("location", {})
                            .get("s3Location", {})
                            .get("uri", "unknown")
                        )
                        if source_text:
                            grounding_sources.append(source_text)
                            citations.append({"text": source_text[:200], "source": source_uri})

        if "trace" in event:
            trace = event["trace"].get("trace", {})
            orchestration = trace.get("orchestrationTrace", {})
            observation = orchestration.get("observation", {})
            kb_lookup = observation.get("knowledgeBaseLookupOutput", {})
            for ref in kb_lookup.get("retrievedReferences", []):
                source_text = ref.get("content", {}).get("text", "")
                if source_text and source_text not in grounding_sources:
                    grounding_sources.append(source_text)

    return {
        "response_text": response_text,
        "grounding_sources": grounding_sources,
        "citations": citations,
    }


def _apply_guardrail(query, grounding_sources, response_text):
    if not grounding_sources or not response_text:
        return {
            "grounding_score": None, "relevance_score": None,
            "action": "SKIPPED", "reason": "No grounding sources or response to evaluate",
        }

    combined_source = "\n\n".join(grounding_sources)
    content = [
        {"text": {"text": combined_source, "qualifiers": ["grounding_source"]}},
        {"text": {"text": query, "qualifiers": ["query"]}},
        {"text": {"text": response_text}},
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
