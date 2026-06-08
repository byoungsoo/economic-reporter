import os
import re
import requests
from strands import tool


@tool
def send_slack_report(report: str) -> str:
    """
    완성된 경제 보고서를 Slack 채널로 전송합니다.

    Args:
        report: 전송할 보고서 전문 (마크다운 형식)

    Returns:
        전송 결과 메시지
    """
    webhook_url = os.environ.get("SLACK_WEBHOOK_URL", "")
    if not webhook_url:
        return "SLACK_WEBHOOK_URL이 설정되지 않았습니다."

    blocks = _markdown_to_slack_blocks(report)

    # Slack 메시지당 최대 50블록 제한
    for i in range(0, len(blocks), 50):
        payload = {"blocks": blocks[i:i + 50]}
        try:
            response = requests.post(webhook_url, json=payload, timeout=10)
            response.raise_for_status()
        except Exception as e:
            return f"Slack 전송 실패: {e}"

    return "Slack 전송 완료"


def send_slack_error(message: str) -> None:
    """에러 알림을 Slack으로 전송합니다 (tool 아님)."""
    webhook_url = os.environ.get("SLACK_WEBHOOK_URL", "")
    if not webhook_url:
        return
    try:
        requests.post(
            webhook_url,
            json={"blocks": [{"type": "section", "text": {"type": "mrkdwn", "text": f":warning: {message}"}}]},
            timeout=10,
        )
    except Exception:
        pass


def _convert_tables_to_codeblock(text: str) -> str:
    """Markdown 테이블을 Slack 코드 블록(모노스페이스)으로 변환."""
    def replace(m):
        table = m.group(0).rstrip("\n")
        return f"```\n{table}\n```"
    return re.sub(r"(?m)(?:^\|[^\n]*\n?)+", replace, text)


def _markdown_to_slack_blocks(report: str) -> list:
    """Markdown 보고서를 Slack Block Kit 형식으로 변환."""
    report = _convert_tables_to_codeblock(report)
    blocks = []
    pending: list[str] = []

    def flush():
        text = "\n".join(pending).strip()
        pending.clear()
        if not text:
            return
        text = _md_to_mrkdwn(text)
        for chunk in _split_text(text, 3000):
            blocks.append({"type": "section", "text": {"type": "mrkdwn", "text": chunk}})

    for raw in report.split("\n"):
        line = raw.strip()

        # 메인 타이틀: # 📊 경제 보고서 ...
        if re.match(r"^#\s+[^#]", line):
            flush()
            title = line[2:].strip()
            blocks.append({
                "type": "header",
                "text": {"type": "plain_text", "text": title[:150], "emoji": True},
            })

        # 섹션 헤더: ## 1. 🗞️ ...
        elif re.match(r"^##\s+", line):
            flush()
            blocks.append({"type": "divider"})
            section_title = _md_to_mrkdwn(re.sub(r"^##\s+", "", line))
            blocks.append({
                "type": "section",
                "text": {"type": "mrkdwn", "text": f"*{section_title}*"},
            })

        # 수평선 --- 은 섹션 divider로 이미 처리하므로 건너뜀
        elif line == "---":
            flush()

        else:
            pending.append(raw)

    flush()
    return blocks


def _md_to_mrkdwn(text: str) -> str:
    """기본 Markdown → Slack mrkdwn 변환."""
    # **bold** → *bold*
    text = re.sub(r"\*\*(.*?)\*\*", r"*\1*", text)
    # [text](url) → <url|text>
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"<\2|\1>", text)
    return text


def _split_text(text: str, max_length: int) -> list[str]:
    if len(text) <= max_length:
        return [text]
    chunks = []
    while text:
        chunks.append(text[:max_length])
        text = text[max_length:]
    return chunks
