FROM public.ecr.aws/docker/library/python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# 依赖层：仅 requirements.txt 变化时重建
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 代码层
COPY . .

# 非 root
RUN groupadd --system appgroup && \
    useradd --system --gid appgroup --home-dir /app --shell /usr/sbin/nologin appuser && \
    chown -R appuser:appgroup /app
USER appuser

EXPOSE 8000

# slim 无 curl，用 python urllib 探活（需服务暴露 /health）
HEALTHCHECK --interval=15s --timeout=3s --start-period=20s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8000/health').status==200 else 1)"

# 生产：gunicorn 管理多个 uvicorn worker
CMD ["gunicorn", "app:app", "-k", "uvicorn.workers.UvicornWorker", "-w", "2", "-b", "0.0.0.0:8000"]
