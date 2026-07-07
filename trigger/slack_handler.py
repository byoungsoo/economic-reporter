import base64
import boto3
import hashlib
import hmac
import json
import logging
import os
import time

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

_lambda_client = boto3.client("lambda", region_name=os.environ.get("AWS_REGION", "ap-northeast-2"))


def handler(event, context):
    """Slack 이벤트 수신 → HMAC 검증 → Worker Lambda 비동기 호출.

    Lambda Function URL로 직접 Slack Slash Command를 수신합니다.
    """
    # Slack 재시도 요청은 즉시 200 반환 (Worker 호출 안 함)
    headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
    retry_num = headers.get("x-slack-retry-num")
    logger.info("Request headers: retry_num=%s", retry_num)
    if retry_num:
        logger.info("Slack retry ignored: retry_num=%s reason=%s", retry_num, headers.get("x-slack-retry-reason"))
        return {"statusCode": 200, "body": ""}

    # body 처리 (Function URL도 base64 인코딩할 수 있음)
    body = event.get("body", "") or ""
    if event.get("isBase64Encoded"):
        body = base64.b64decode(body).decode("utf-8")

    # Slack Signing Secret HMAC 검증
    if not _verify_slack_signature(body, headers):
        return {"statusCode": 401, "body": json.dumps({"error": "Unauthorized"})}

    # Slack url_verification challenge 응답
    content_type = headers.get("content-type", "")
    if "application/json" in content_type:
        try:
            payload = json.loads(body)
            if payload.get("type") == "url_verification":
                return {"statusCode": 200, "body": json.dumps({"challenge": payload["challenge"]})}
        except Exception:
            pass

    # Worker Lambda 비동기 호출 (Slack 3초 제한 준수)
    worker_arn = os.environ.get("WORKER_LAMBDA_ARN")
    if worker_arn:
        _lambda_client.invoke(
            FunctionName=worker_arn,
            InvocationType="Event",
            Payload=b"{}",
        )

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({
            "response_type": "in_channel",
            "text": "경제 보고서 생성을 시작합니다. 잠시 후 보고서가 발송됩니다.",
        }),
    }


def _verify_slack_signature(body: str, headers: dict) -> bool:
    """Slack Signing Secret을 사용한 HMAC-SHA256 서명 검증."""
    timestamp = headers.get("x-slack-request-timestamp", "")
    slack_signature = headers.get("x-slack-signature", "")

    if not timestamp or not slack_signature:
        return False
    if abs(time.time() - int(timestamp)) > 300:
        return False

    signing_secret = os.environ.get("SLACK_SIGNING_SECRET", "")
    if not signing_secret:
        logger.error("SLACK_SIGNING_SECRET 환경변수가 설정되지 않았습니다.")
        return False

    sig_basestring = f"v0:{timestamp}:{body}"
    expected = "v0=" + hmac.new(
        signing_secret.encode(),
        sig_basestring.encode(),
        hashlib.sha256,
    ).hexdigest()

    return hmac.compare_digest(expected, slack_signature)
