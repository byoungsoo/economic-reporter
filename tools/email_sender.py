import os
import re
import boto3
from strands import tool


@tool
def send_email_report(report: str, subject: str = "경제 보고서") -> str:
    """
    완성된 경제 보고서를 이메일(AWS SNS)로 전송합니다.

    Args:
        report: 전송할 보고서 전문
        subject: 이메일 제목 (기본값: "경제 보고서")

    Returns:
        전송 결과 메시지
    """
    sns_topic_arn = os.environ.get("SNS_TOPIC_ARN", "")
    if not sns_topic_arn:
        return "SNS_TOPIC_ARN이 설정되지 않았습니다."

    client = boto3.client("sns", region_name=os.environ.get("AWS_REGION", "ap-northeast-2"))

    try:
        client.publish(
            TopicArn=sns_topic_arn,
            Subject=subject,
            Message=_markdown_to_plaintext(report),
        )
        return "이메일 전송 완료"
    except Exception as e:
        return f"이메일 전송 실패: {e}"


def _table_to_bullets(match: re.Match) -> str:
    """Markdown 테이블을 불릿 리스트로 변환."""
    rows = [r for r in match.group(0).strip().splitlines() if not re.match(r"^\|[-| ]+\|$", r)]
    bullets = []
    for row in rows:
        cells = [c.strip() for c in row.strip("|").split("|")]
        bullets.append("• " + " | ".join(c for c in cells if c))
    return "\n".join(bullets)


def _markdown_to_plaintext(text: str) -> str:
    """Markdown 기호를 제거하고 이메일용 plain text로 변환."""
    text = re.sub(r"(?m)(?:^\|[^\n]*\n?)+", _table_to_bullets, text)
    lines = []
    for raw in text.split("\n"):
        line = raw.strip()

        # # 메인 타이틀
        if re.match(r"^#\s+[^#]", line):
            title = re.sub(r"^#\s+", "", line)
            lines.append("=" * 60)
            lines.append(title)
            lines.append("=" * 60)

        # ## 섹션 헤더
        elif re.match(r"^##\s+", line):
            section = re.sub(r"^##\s+", "", line)
            lines.append("")
            lines.append(section)
            lines.append("-" * 40)

        # ### 소제목
        elif re.match(r"^###\s+", line):
            sub = re.sub(r"^###\s+", "", line)
            lines.append(f"[ {sub} ]")

        # 수평선
        elif re.match(r"^---+$", line):
            pass  # 섹션 구분은 ## 헤더로 이미 처리

        else:
            # **bold** 제거
            clean = re.sub(r"\*\*(.*?)\*\*", r"\1", raw)
            # *italic* 제거
            clean = re.sub(r"\*(.*?)\*", r"\1", clean)
            # [text](url) → text
            clean = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", clean)
            # 인라인 코드 `code` 제거
            clean = re.sub(r"`([^`]+)`", r"\1", clean)
            lines.append(clean)

    return "\n".join(lines)
