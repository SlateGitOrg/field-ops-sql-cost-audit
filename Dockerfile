# Runs the full offline pipeline (synthetic data -> dbt build -> pytest)
# in one container. No external services are required: dbt targets an
# embedded DuckDB file, so this image needs no linked Postgres/Docker
# Compose service to produce a working build.
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV DBT_PROFILES_DIR=/app/dbt_project

RUN python data_generation/generate_data.py

RUN cd dbt_project && dbt build --target dev

CMD ["python", "-m", "pytest", "tests/", "-v"]
