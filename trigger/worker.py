import logging
import os
import sys

# Lambda Layer에서 agent/tools 패키지를 import하려면 /var/task가 sys.path에 있어야 함
sys.path.insert(0, "/var/task")

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def handler(event, context):
    """Worker Lambda: 에이전트를 직접 실행하여 경제 보고서를 생성·발송합니다."""
    logger.info("Worker Lambda started")

    try:
        from agent.config import load_secrets
        from agent.main import run

        load_secrets()
        run()

        logger.info("Worker Lambda completed successfully")
        return {"status": "completed"}

    except Exception as e:
        logger.error("Worker Lambda failed: %s", e)
        _send_slack_error(f"보고서 생성 중 오류가 발생했습니다.\n```{e}```")
        return {"status": "error", "message": str(e)}


def _send_slack_error(message: str):
    """에러 발생 시 Slack으로 알림을 전송합니다."""
    import requests as req

    webhook_url = os.environ.get("SLACK_WEBHOOK_URL", "")
    if not webhook_url:
        return
    try:
        req.post(
            webhook_url,
            json={"blocks": [{"type": "section", "text": {"type": "mrkdwn", "text": f":warning: {message}"}}]},
            timeout=10,
        )
    except Exception as e:
        logger.error("Failed to send Slack error notification: %s", e)
