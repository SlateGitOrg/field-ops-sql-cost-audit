"""Integration test: builds the full dbt project (seed -> run -> test)
against an embedded DuckDB file and asserts it's green end to end. This is
the same command CI runs (see .github/workflows/ci.yml) and is fully
offline: no network, no Docker, no external database.

Also re-checks a handful of the core invariants directly over the built
DuckDB file with plain SQL, independent of dbt's own test runner, so a bug
in a dbt test's YAML wouldn't be the only thing standing between a real
regression and a green test suite.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import duckdb
import pytest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DBT_PROJECT_DIR = PROJECT_ROOT / "dbt_project"


@pytest.fixture(scope="module")
def built_duckdb_path(tmp_path_factory):
    """Runs `dbt build` once for this test module against a scratch DuckDB
    file, and hands back its path for direct SQL assertions."""
    scratch_dir = tmp_path_factory.mktemp("dbt_build")
    duckdb_path = scratch_dir / "field_ops_cost_audit.duckdb"

    env = os.environ.copy()
    env["DBT_PROFILES_DIR"] = str(DBT_PROJECT_DIR)
    env["DBT_DUCKDB_PATH"] = str(duckdb_path)

    # dbt ships a console-script entry point (no `python -m dbt` support),
    # so resolve it next to the interpreter running these tests -- this
    # works whether that's a venv's bin/ or a CI runner's site executables.
    dbt_bin = Path(sys.executable).parent / "dbt"
    dbt_cmd = str(dbt_bin) if dbt_bin.exists() else "dbt"

    result = subprocess.run(
        [dbt_cmd, "build", "--target", "dev"],
        cwd=str(DBT_PROJECT_DIR),
        env=env,
        capture_output=True,
        text=True,
        timeout=300,
    )

    if result.returncode != 0:
        pytest.fail(
            "dbt build failed:\n"
            f"--- stdout ---\n{result.stdout}\n"
            f"--- stderr ---\n{result.stderr}"
        )

    assert "Completed successfully" in result.stdout
    return duckdb_path


def test_dbt_build_succeeds(built_duckdb_path):
    assert built_duckdb_path.exists()


def test_no_negative_total_cost_to_serve(built_duckdb_path):
    con = duckdb.connect(str(built_duckdb_path), read_only=True)
    count = con.execute(
        "select count(*) from main_marts.fct_job_cost_to_serve where total_cost_to_serve < 0"
    ).fetchone()[0]
    con.close()
    assert count == 0


def test_no_orphaned_jobs_in_cost_to_serve(built_duckdb_path):
    con = duckdb.connect(str(built_duckdb_path), read_only=True)
    count = con.execute("""
        select count(*)
        from main_marts.fct_job_cost_to_serve f
        left join main_marts.dim_technicians t on f.technician_id = t.technician_id
        where t.technician_id is null
    """).fetchone()[0]
    con.close()
    assert count == 0


def test_data_quality_exceptions_are_tracked_not_silently_dropped(built_duckdb_path):
    """The orphaned-technician jobs the generator intentionally injects
    must show up *somewhere* (the audit model), proving the pipeline
    surfaces the gap instead of just making it vanish in staging."""
    con = duckdb.connect(str(built_duckdb_path), read_only=True)
    exception_count = con.execute(
        "select count(*) from main_marts.rpt_data_quality_exceptions"
    ).fetchone()[0]
    con.close()
    assert exception_count > 0


def test_route_sequence_resolves_every_stop_exactly_once(built_duckdb_path):
    con = duckdb.connect(str(built_duckdb_path), read_only=True)
    mismatches = con.execute("""
        with raw as (
            select route_id, count(*) as n from main_staging.stg_route_stops group by 1
        ),
        seq as (
            select route_id, count(*) as n from main_intermediate.int_route_sequence group by 1
        )
        select count(*)
        from raw join seq using (route_id)
        where raw.n != seq.n
    """).fetchone()[0]
    con.close()
    assert mismatches == 0


def test_sla_breach_rate_is_nonzero_and_plausible(built_duckdb_path):
    """Guards against a formula regression that would make everything (or
    nothing) breach -- either extreme would mean the SLA logic broke, not
    that the business got perfect or catastrophic."""
    con = duckdb.connect(str(built_duckdb_path), read_only=True)
    total, breached = con.execute("""
        select count(*), sum(case when is_breached then 1 else 0 end)
        from main_marts.fct_job_sla_breach
    """).fetchone()
    con.close()
    assert total > 0
    breach_rate = breached / total
    assert 0.0 < breach_rate < 0.5


def test_technician_utilization_rolling_average_is_bounded(built_duckdb_path):
    con = duckdb.connect(str(built_duckdb_path), read_only=True)
    row = con.execute("""
        select min(rolling_4wk_avg_utilization), max(rolling_4wk_avg_utilization)
        from main_marts.fct_technician_utilization
    """).fetchone()
    con.close()
    lo, hi = row
    assert lo is not None and hi is not None
    assert lo >= 0
    assert hi < 3.0  # sanity ceiling; utilization can exceed 1.0 (overtime) but not run away
