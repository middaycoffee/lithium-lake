FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y curl git && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://github.com/bruin-data/bruin/releases/download/v0.11.464/bruin_Linux_x86_64.tar.gz \
    -o bruin.tar.gz \
    && tar -xzf bruin.tar.gz \
    && mv bruin /usr/local/bin/bruin \
    && rm bruin.tar.gz

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY .bruin.yml .
COPY pipelines/ pipelines/

RUN git init

ENV MATERIALS_PROJECT_API=""
ENV GOOGLE_APPLICATION_CREDENTIALS=/app/gcp-service.json

CMD ["sh", "-c", "bruin run pipelines/ingestion && bruin run pipelines/transformation"]
