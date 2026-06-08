import os
from dotenv import load_dotenv

load_dotenv()

from agent.config import load_secrets
from strands import Agent
from strands.models import BedrockModel

from agent.prompts import get_system_prompt, get_report_prompt
from tools.news_fetcher import fetch_economic_news
from tools.slack_notifier import send_slack_report
from tools.email_sender import send_email_report


def run():
    load_secrets()
    model = BedrockModel(
        model_id=os.environ.get("AWS_BEDROCK_MODEL_ID", "global.anthropic.claude-sonnet-4-6"),
        region_name=os.environ.get("AWS_REGION", "ap-northeast-2"),
    )

    agent = Agent(
        model=model,
        system_prompt=get_system_prompt(),
        tools=[fetch_economic_news, send_slack_report, send_email_report],
    )

    agent(get_report_prompt(), max_iterations=30)


# AgentCore Runtime 엔트리포인트
try:
    from bedrock_agentcore.runtime import BedrockAgentCoreApp
    import logging
    from typing import Generator

    app = BedrockAgentCoreApp()

    @app.entrypoint
    def run_report(payload: dict) -> Generator[str, None, None]:
        """스트리밍 응답으로 AgentCore keepalive 유지 (작업 중 ping timeout 방지)"""
        logger = logging.getLogger(__name__)
        logger.info("AgentCore: starting economic report")
        yield "starting"
        run()
        yield "completed"

except ImportError:
    pass  # 로컬 실행 시 bedrock_agentcore 미설치 환경 대응


if __name__ == "__main__":
    run()
