# Economic Reporter

EventBridge 스케줄 또는 Slack `/report` 명령으로 트리거되는 AI 에이전트 배치 잡. 최근 24시간 경제·금융 뉴스를 수집·분석해 Slack과 이메일로 보고서를 자동 발송합니다.

---

## 주요 기능

- **뉴스 수집** — SerpAPI(Google News)로 최근 24시간 경제·금융 뉴스 자동 수집
- **AI 분석** — AWS Bedrock Claude가 뉴스를 요약·분석하고 핵심 인사이트 도출
- **보고서 생성** — 시장 동향, 주요 이슈, 리스크 요인을 포함한 구조화된 경제 보고서 생성
- **멀티채널 발송** — Slack Block Kit 형식 + 이메일(AWS SNS) 동시 발송

## 보고서 섹션

1. 중요 경제 뉴스
2. 미국 증시 동향
3. 글로벌 증시 동향 (유럽·중국·일본)
4. 한국 증시 동향
5. 환율 / 금리 / 원자재
6. 채권 시장
7. 섹터 & 테마 동향
8. 주요 경제 이벤트 예고
9. 주요 기업 이슈 _(해당 이슈 없을 경우 생략)_
10. 요약 및 전략적 시사점

---

## 아키텍처

```
                        ┌──────────────────────────────────────────────────────────────────────┐
                        │                        AWS dev 계정 (558846430793)                    │
                        │                                                                      │
  ┌──────────┐          │  ┌────────────────────────────────────────────────────────────────┐  │
  │EventBridge│─ cron ──│─▶│          Worker Lambda (timeout 15min, 512MB)                  │  │
  │  Rule     │ KST 6AM │  │                                                                │  │
  └──────────┘          │  │   ┌─────────────┐    ┌─────────────────┐    ┌──────────────┐  │  │
                        │  │   │ Strands Agent│───▶│ Bedrock Claude  │    │Secrets Manager│  │  │
                        │  │   └──────┬───┬──┘    │ Sonnet 4        │    │              │  │  │
                        │  │          │   │       └─────────────────┘    └──────────────┘  │  │
                        │  │          │   │                                                 │  │
                        │  │    ┌─────┘   └──────┐                                         │  │
                        │  │    ▼                 ▼                                         │  │
                        │  │ ┌────────┐    ┌───────────┐    ┌──────────┐                   │  │
                        │  │ │SerpAPI │    │   Slack    │    │ AWS SNS  │                   │  │
                        │  │ │(News)  │    │ (Webhook)  │    │ (Email)  │                   │  │
                        │  │ └────────┘    └───────────┘    └──────────┘                   │  │
                        │  └────────────────────────────────────────────────────────────────┘  │
                        │                              ▲                                       │
                        │                              │ async invoke                          │
                        │                                                                      │
  ┌──────────┐          │  ┌──────────────┐    ┌────────────────────────────────────────────┐  │
  │  Slack   │─ /report─│─▶│ API Gateway  │───▶│  Trigger Lambda (timeout 10s)              │  │
  │  User    │          │  │ HTTP API     │    │  - HMAC-SHA256 서명 검증                    │  │
  │          │◀─ 200 ───│──│ (throttle)   │◀───│  - 즉시 응답 → Worker 비동기 호출           │  │
  └──────────┘          │  └──────────────┘    └────────────────────────────────────────────┘  │
                        │                                                                      │
                        └──────────────────────────────────────────────────────────────────────┘
```

**리소스 요약:**

| 리소스 | 이름 | 설명 |
|--------|------|------|
| Worker Lambda | `bys-dev-apne2-lambda-economic-reporter-worker` | 에이전트 실행 (15분, 512MB, concurrency=1) |
| Trigger Lambda | `bys-dev-apne2-lambda-economic-reporter-trigger` | Slack 수신 + HMAC 검증 (10초) |
| API Gateway | `bys-dev-apne2-apigw-economic-reporter` | HTTP API (throttle: 5 req/s, burst 10) |
| EventBridge Rule | `bys-dev-apne2-evb-economic-reporter-schedule` | `cron(0 21 * * ? *)` = KST 06:00 |
| Lambda Layer | `bys-dev-apne2-layer-economic-reporter-deps` | strands-agents, requests 등 |
| IAM Role | `bys-dev-apne2-role-economic-reporter-lambda` | Bedrock, Secrets Manager, SNS, Lambda |

---

## 기술 스택

| 구분 | 기술 |
|------|------|
| Agent Framework | [Strands SDK](https://github.com/strands-agents/sdk-python) |
| LLM | AWS Bedrock — Claude Sonnet (`global.anthropic.claude-sonnet-4-6`) |
| 스케줄 트리거 | AWS EventBridge cron → Worker Lambda |
| 온디맨드 트리거 | Slack Slash Command → API Gateway HTTP API → Trigger Lambda |
| 뉴스 수집 | [SerpAPI](https://serpapi.com/) (Google News) |
| 시크릿 관리 | AWS Secrets Manager (`economic-reporter`) |
| 인프라 | Terraform (단일 계정) |
| 알림 | Slack Block Kit Webhook, AWS SNS Email |
| 언어 | Python 3.11 |

---

## 프로젝트 구조

```
economic-reporter/
├── agent/
│   ├── main.py                # 에이전트 실행 진입점
│   ├── config.py              # Secrets Manager → os.environ 주입
│   └── prompts.py             # 시스템 프롬프트 · 보고서 템플릿
├── tools/
│   ├── news_fetcher.py        # 뉴스 수집 Tool (SerpAPI)
│   ├── slack_notifier.py      # Slack Block Kit 발송 Tool
│   └── email_sender.py        # 이메일 발송 Tool (AWS SNS)
├── trigger/
│   ├── slack_handler.py       # Slack 이벤트 수신 (API Gateway) → Worker 비동기 호출
│   └── worker.py              # Worker Lambda — 에이전트 직접 실행
├── terraform/
│   └── account/
│       └── aws-dev-apne2/
│           ├── lambda/        # Trigger + Worker Lambda + IAM + Layer
│           ├── apigateway/    # API Gateway HTTP API (Slack 엔드포인트)
│           └── eventbridge/   # EventBridge cron 스케줄 규칙
├── pyproject.toml
└── README.md
```

---

## Getting Started

### 사전 요구사항

- Python 3.11+ / [uv](https://github.com/astral-sh/uv)
- AWS 계정 및 Bedrock Claude 모델 접근 권한
- Slack App (Slash Command 설정)
- SerpAPI 키

### 설치

```bash
git clone <repo-url>
cd economic-reporter
uv sync
```

### 환경 변수 (로컬 실행용)

프로젝트 루트에 `.env` 파일 생성:

```dotenv
AWS_REGION=ap-northeast-2
AWS_BEDROCK_MODEL_ID=global.anthropic.claude-sonnet-4-6

SERPAPI_API_KEY=your_serpapi_key
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
SNS_TOPIC_ARN=arn:aws:sns:ap-northeast-2:...
```

### 로컬 실행

```bash
uv run python agent/main.py
```

---

## 배포

### Terraform (인프라)

```bash
# Lambda 컴포넌트 (먼저 apply — EventBridge에서 Worker ARN 참조)
cd terraform/account/aws-dev-apne2/lambda
terraform init
terraform apply

# EventBridge 컴포넌트
cd ../eventbridge
terraform init
terraform apply -var="worker_lambda_arn=<위 output의 worker_function_arn>"
```

> `slack_signing_secret`과 `slack_webhook_url`은 sensitive 변수이므로 `-var` 플래그 또는 환경변수(`TF_VAR_*`)로 전달합니다.

### Lambda Layer 빌드

Worker Lambda는 `strands-agents`, `requests` 등 외부 의존성이 필요합니다. Lambda Layer로 패키징:

```bash
pip install strands-agents strands-agents-tools requests python-dotenv -t python/
zip -r python-requests-layer.zip python/
# terraform/modules/lambda-layer/ 에 배치
```

---

## 설정

### 실행 스케줄

`terraform/account/dev/environments/dev.tfvars`의 `schedule` 변수로 변경합니다.

```hcl
schedule = "cron(0 21 * * ? *)"  # UTC 21:00 = KST 06:00
```

### Slack Slash Command 설정

1. [api.slack.com/apps](https://api.slack.com/apps)에서 Slack App 생성
2. **Slash Commands** 메뉴에서 `/report` 커맨드 추가
   - Request URL: `terraform output`의 `function_url` 값 사용
3. **Basic Information > Signing Secret**을 Secrets Manager에 저장

### 시크릿 구조 (AWS Secrets Manager)

모든 시크릿은 `economic-reporter` 단일 시크릿 내 키/값으로 관리합니다.

| 키 | 설명 | 사용처 |
|----|------|--------|
| `SERPAPI_API_KEY` | SerpAPI 인증 키 | Worker Lambda (news_fetcher) |
| `SLACK_WEBHOOK_URL` | Slack Incoming Webhook URL | Worker Lambda (slack_notifier) |
| `SNS_TOPIC_ARN` | SNS 토픽 ARN | Worker Lambda (email_sender) |
| `SLACK_SIGNING_SECRET` | Slack Signing Secret | Trigger Lambda (HMAC 검증) |

---

## 로드맵

- [ ] 뉴스 소스 다양화 (RSS, 네이버 뉴스 등)
- [ ] 보고서 섹션 커스터마이징 (관심 종목, 섹터 필터)
- [ ] 주간/월간 요약 보고서 지원
- [ ] 보고서 히스토리 저장 (S3)
