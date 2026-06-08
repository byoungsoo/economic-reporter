import json
import os
import time


def handler(event, context):
    headers = {k.lower(): v for k, v in event.get("headers", {}).items()}
    timestamp = headers.get("x-slack-request-timestamp", "")
    slack_signature = headers.get("x-slack-signature", "")

    # 헤더 존재 여부 확인
    if not timestamp or not slack_signature:
        return _policy("Deny", event["methodArn"])

    # Replay attack 방지 (5분 이내 요청만 허용)
    if abs(time.time() - int(timestamp)) > 300:
        return _policy("Deny", event["methodArn"])

    # HMAC 서명 검증은 body가 필요하므로 Trigger Lambda에서 수행
    return _policy("Allow", event["methodArn"])


def _policy(effect, resource):
    return {
        "principalId": "slack",
        "policyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {"Action": "execute-api:Invoke", "Effect": effect, "Resource": resource}
            ],
        },
    }
