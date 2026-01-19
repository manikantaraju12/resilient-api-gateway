FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/* \
	&& pip install --no-cache-dir flask

COPY app.py /app/app.py

ENV PORT=5001

CMD ["python", "/app/app.py"]
