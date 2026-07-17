"""Small helper for unit-testing individual dbt model SQL files directly
against hand-built DuckDB fixture tables, without spinning up a full dbt
run. This is what gives the "recursive route sequencing" and "SLA breach"
logic true unit-test-level coverage (exact expected numbers on a tiny,
hand-computed fixture) on top of the full dbt build/test integration pass
in test_dbt_build.py.
"""
from __future__ import annotations

import re
from pathlib import Path

DBT_MODELS_DIR = Path(__file__).resolve().parents[1] / "dbt_project" / "models"

_REF_PATTERN = re.compile(r"\{\{\s*ref\(\s*['\"]([a-zA-Z0-9_]+)['\"]\s*\)\s*\}\}")


def render_model_sql(relative_path: str) -> str:
    """Reads a dbt model .sql file and replaces every `{{ ref('x') }}` with
    the bare identifier `x`, so it can run standalone against a fixture
    table/view literally named `x` in a plain DuckDB connection."""
    path = DBT_MODELS_DIR / relative_path
    sql = path.read_text()
    return _REF_PATTERN.sub(lambda m: m.group(1), sql)
