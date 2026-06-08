import boto3
import json
import logging
import os
import requests
import uuid
from botocore.config import Config

logger = logging.getLogger(__name__)

# AgentCore 호출은 3~5분 소요 → read_timeout을 Lambda timeout(600s)보다 충분히 크게 설정
_AGENTCORE_CONFIG = Config(
    read_timeout=590,   # Lambda timeout(600s)보다 약간 작게 — cold start + 실행 전체 커버
    connect_timeout=10,
    retries={"max_attempts": 0},
)


def handler(event, context):
    agent_arn = os.environ.get("AGENTCORE_AGENT_ARN")
    region = os.environ.get("AWS_REGION", "ap-northeast-2")

    logger.info("Invoking AgentCore: %s", agent_arn)

    try:
        client = boto3.client("bedrock-agentcore", region_name=region, config=_AGENTCORE_CONFIG)
        session_id = str(uuid.uuid4())
        response = client.invoke_agent_runtime(
            agentRuntimeArn=agent_arn,
            runtimeSessionId=session_id,
            payload=json.dumps({"prompt": "경제 보고서 생성"}).encode(),
        )
        # EventStream 소비 — cold start 포함 전체 실행 동안 스트림 유지
        stream = response.get("response")
        if stream is not None:
            try:
                for event in stream:
                    # chunk 수신 시마다 로그로 heartbeat 확인
                    chunk = event.get("chunk", {})
                    if chunk:
                        logger.info("AgentCore stream chunk: %s", chunk.get("bytes", b"")[:80])
            except Exception as stream_err:
                # 스트림 읽기 오류는 에이전트 실행 완료 후 발생할 수 있으므로 warn 처리
                logger.warning("AgentCore stream read warning: %s", stream_err)
        logger.info("AgentCore invocation completed: session=%s status=%s",
                    session_id,
                    response.get("ResponseMetadata", {}).get("HTTPStatusCode"))
        return {"status": "completed"}
    except Exception as e:
        logger.error("AgentCore invocation failed: %s", e)
        _send_slack_error(f"보고서 생성 중 오류가 발생했습니다.\n```{e}```")
        # raise 하지 않음 — Lambda async 재시도를 유발하지 않기 위해 정상 종료
        return {"status": "error", "message": str(e)}


def _send_slack_error(message: str):
    webhook_url = os.environ.get("SLACK_WEBHOOK_URL", "")
    if not webhook_url:
        return
    try:
        requests.post(
            webhook_url,
            json={"blocks": [{"type": "section", "text": {"type": "mrkdwn", "text": f":warning: {message}"}}]},
            timeout=10,
        )
    except Exception as e:
        logger.error("Failed to send Slack error notification: %s", e)
