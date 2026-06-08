FROM python:3.11-slim

WORKDIR /app

COPY requirements-agentcore.txt .
RUN pip install --no-cache-dir -r requirements-agentcore.txt

COPY agent/ ./agent/
COPY tools/ ./tools/

ENV PYTHONPATH=/app

CMD ["python", "-m", "uvicorn", "agent.main:app", "--host", "0.0.0.0", "--port", "8080"]
