import logging
import os
import re
import requests
from datetime import datetime, timezone, timedelta
from strands import tool

logger = logging.getLogger(__name__)

SERPAPI_URL = "https://serpapi.com/search"


def _parse_article_date(date_str: str) -> datetime | None:
    """SerpAPI date 필드를 UTC datetime으로 변환. 파싱 실패 시 None 반환."""
    if not date_str:
        return None
    now = datetime.now(timezone.utc)
    s = date_str.strip()

    # "X minutes ago"
    m = re.match(r"(\d+)\s+minute", s)
    if m:
        return now - timedelta(minutes=int(m.group(1)))
    # "X hours ago" / "1 hour ago"
    m = re.match(r"(\d+)\s+hour", s)
    if m:
        return now - timedelta(hours=int(m.group(1)))
    # "X days ago" / "1 day ago"
    m = re.match(r"(\d+)\s+day", s)
    if m:
        return now - timedelta(days=int(m.group(1)))
    # "X weeks ago"
    m = re.match(r"(\d+)\s+week", s)
    if m:
        return now - timedelta(weeks=int(m.group(1)))
    # "X months ago"
    m = re.match(r"(\d+)\s+month", s)
    if m:
        return now - timedelta(days=int(m.group(1)) * 30)

    # Standard date formats
    for fmt in ("%b %d, %Y", "%B %d, %Y", "%Y-%m-%d", "%m/%d/%Y", "%Y.%m.%d"):
        try:
            return datetime.strptime(s, fmt).replace(tzinfo=timezone.utc)
        except ValueError:
            continue

    # "MM/DD" without year — assume current year
    m = re.match(r"^(\d{1,2})/(\d{1,2})$", s)
    if m:
        try:
            dt = datetime(now.year, int(m.group(1)), int(m.group(2)), tzinfo=timezone.utc)
            if dt > now:
                dt = dt.replace(year=now.year - 1)
            return dt
        except ValueError:
            pass

    return None


@tool
def fetch_economic_news(query: str, hours: int = 24) -> str:
    """
    SerpAPI(Google News)를 통해 경제·금융 뉴스를 수집합니다.

    Args:
        query: 검색 쿼리 (예: "미국 증시 나스닥", "한국 금리")
        hours: 최근 몇 시간 이내 뉴스 (기본 24시간)

    Returns:
        수집된 뉴스 기사 목록 (제목, 출처, 요약, 링크)
    """
    api_key = os.environ.get("SERPAPI_API_KEY", "")
    if not api_key:
        return "SERPAPI_API_KEY가 설정되지 않았습니다."

    tbs = f"qdr:h{hours}"
    params = {
        "engine": "google_news",
        "q": query,
        "api_key": api_key,
        "hl": "ko",
        "gl": "kr",
        "num": 10,
        "tbs": tbs,
    }

    try:
        response = requests.get(SERPAPI_URL, params=params, timeout=20)
        response.raise_for_status()
        data = response.json()
    except Exception as e:
        logger.error("SerpAPI 호출 실패 (query=%s): %s", query, e)
        return f"'{query}' 뉴스 수집에 실패했습니다. 잠시 후 다시 시도해주세요."

    raw_articles = data.get("news_results", [])
    if not raw_articles:
        return f"'{query}' 관련 최근 뉴스를 찾을 수 없습니다."

    # stories 중첩 구조 펼치기: 클러스터 안의 개별 기사도 포함
    articles = []
    for item in raw_articles:
        stories = item.get("stories", [])
        if stories:
            articles.extend(stories)
        else:
            articles.append(item)

    cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)
    fresh, skipped = [], []
    for article in articles:
        dt = _parse_article_date(article.get("date", ""))
        if dt is None or dt >= cutoff:
            fresh.append(article)
        else:
            skipped.append(article.get("date", "?"))

    if not fresh:
        return f"'{query}' 관련 최근 {hours}시간 이내 뉴스를 찾을 수 없습니다."

    lines = [f"## {query} 관련 최신 뉴스 (최근 {hours}시간)\n"]
    if skipped:
        lines.append(f"_(오래된 기사 {len(skipped)}건 제외됨: {', '.join(skipped)})_\n")

    for i, article in enumerate(fresh[:8], 1):
        title = article.get("title", "")
        raw_source = article.get("source", {})
        source = raw_source.get("name", "") if isinstance(raw_source, dict) else str(raw_source)
        snippet = article.get("snippet", "")
        date = article.get("date", "")
        link = article.get("link", "")
        lines.append(f"{i}. **{title}**")
        lines.append(f"   출처: {source} | {date}")
        if snippet:
            lines.append(f"   {snippet}")
        lines.append(f"   {link}\n")

    return "\n".join(lines)
