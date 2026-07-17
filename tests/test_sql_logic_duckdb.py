"""Unit tests for the two non-trivial SQL patterns, run against tiny,
hand-computed DuckDB fixtures (no dbt, no seeds, no generated data) so
the expected numbers can be verified by inspection in this file.

test_dbt_build.py separately verifies the whole pipeline builds and its
own dbt tests pass against the full generated dataset -- these tests
verify the *logic itself* is correct on cases small enough to check by hand.
"""
from __future__ import annotations

import duckdb
import pytest

from sql_test_utils import render_model_sql


@pytest.fixture
def con():
    c = duckdb.connect(":memory:")
    yield c
    c.close()


# ---------------------------------------------------------------------------
# Recursive CTE: int_route_sequence
# ---------------------------------------------------------------------------

def test_route_sequence_orders_multi_leg_route_and_accumulates_distance(con):
    con.execute("""
        create table stg_route_stops (
            stop_id varchar, route_id varchar, job_id varchar, technician_id varchar,
            prev_stop_id varchar, stop_type varchar,
            arrival_ts timestamp, departure_ts timestamp, distance_from_prev_km double
        )
    """)
    # A single route with 4 stops: depot -> job A -> job B -> depot.
    # Travel legs are exactly 30 minutes each by construction.
    con.execute("""
        insert into stg_route_stops values
            ('S1', 'R1', NULL, 'T1', NULL, 'depot_start', '2024-01-02 08:00:00', '2024-01-02 08:00:00', 0.0),
            ('S2', 'R1', 'JOB-A', 'T1', 'S1', 'job_stop',   '2024-01-02 08:30:00', '2024-01-02 09:00:00', 12.0),
            ('S3', 'R1', 'JOB-B', 'T1', 'S2', 'job_stop',   '2024-01-02 09:45:00', '2024-01-02 10:15:00', 15.0),
            ('S4', 'R1', NULL, 'T1', 'S3', 'depot_end',     '2024-01-02 10:40:00', '2024-01-02 10:40:00', 8.0)
    """)

    sql = render_model_sql("intermediate/int_route_sequence.sql")
    result = con.execute(f"{sql} order by stop_sequence_number").fetchdf()

    assert list(result["stop_id"]) == ["S1", "S2", "S3", "S4"]
    assert list(result["stop_sequence_number"]) == [1, 2, 3, 4]

    # leg travel time = arrival of this stop - departure of the previous stop
    assert result.loc[result.stop_id == "S2", "leg_travel_minutes"].iloc[0] == pytest.approx(30.0)
    assert result.loc[result.stop_id == "S3", "leg_travel_minutes"].iloc[0] == pytest.approx(45.0)
    assert result.loc[result.stop_id == "S4", "leg_travel_minutes"].iloc[0] == pytest.approx(25.0)

    # cumulative distance is a running sum of distance_from_prev_km
    assert result.loc[result.stop_id == "S4", "cumulative_distance_km"].iloc[0] == pytest.approx(
        12.0 + 15.0 + 8.0
    )
    # cumulative travel time is a running sum of leg_travel_minutes
    assert result.loc[result.stop_id == "S4", "cumulative_travel_minutes"].iloc[0] == pytest.approx(
        30.0 + 45.0 + 25.0
    )


def test_route_sequence_keeps_two_independent_routes_separate(con):
    con.execute("""
        create table stg_route_stops (
            stop_id varchar, route_id varchar, job_id varchar, technician_id varchar,
            prev_stop_id varchar, stop_type varchar,
            arrival_ts timestamp, departure_ts timestamp, distance_from_prev_km double
        )
    """)
    con.execute("""
        insert into stg_route_stops values
            ('A1', 'RA', NULL, 'T1', NULL, 'depot_start', '2024-01-02 08:00:00', '2024-01-02 08:00:00', 0.0),
            ('A2', 'RA', 'JOB-1', 'T1', 'A1', 'job_stop',  '2024-01-02 08:20:00', '2024-01-02 09:00:00', 10.0),
            ('B1', 'RB', NULL, 'T2', NULL, 'depot_start',  '2024-01-02 08:00:00', '2024-01-02 08:00:00', 0.0),
            ('B2', 'RB', 'JOB-2', 'T2', 'B1', 'job_stop',  '2024-01-02 08:40:00', '2024-01-02 09:10:00', 20.0)
    """)

    sql = render_model_sql("intermediate/int_route_sequence.sql")
    result = con.execute(sql).fetchdf()

    assert len(result) == 4
    # every route's own first stop is sequence 1, independent of the other route
    firsts = result[result.stop_sequence_number == 1]["route_id"].tolist()
    assert sorted(firsts) == ["RA", "RB"]


# ---------------------------------------------------------------------------
# SLA breach logic: int_sla_breach
# ---------------------------------------------------------------------------

@pytest.fixture
def sla_con(con):
    con.execute("""
        create table stg_jobs (
            job_id varchar, route_id varchar, customer_id varchar, region varchar,
            priority varchar, job_type varchar, technician_id varchar,
            created_at timestamp, scheduled_date date, completed_at timestamp, status varchar
        )
    """)
    con.execute("""
        create table stg_sla_targets (priority varchar, target_resolution_hours integer)
    """)
    con.execute("insert into stg_sla_targets values ('Standard', 72), ('Rush', 24), ('Emergency', 6)")
    return con


def test_sla_breach_flags_job_completed_after_deadline(sla_con):
    sla_con.execute("""
        insert into stg_jobs values
            ('JOB-1', NULL, 'C1', 'North', 'Rush', 'Repair', 'T1',
             '2024-01-01 08:00:00', '2024-01-01', '2024-01-03 10:00:00', 'completed')
    """)
    # Rush target = 24h -> deadline = 2024-01-02 08:00:00.
    # Completed 2024-01-03 10:00:00 is 26 hours late -> 1560 minutes.
    sql = render_model_sql("intermediate/int_sla_breach.sql")
    result = sla_con.execute(sql).fetchdf()
    row = result.iloc[0]
    assert bool(row["is_breached"]) is True
    assert int(row["breach_minutes"]) == 26 * 60


def test_sla_breach_does_not_flag_job_completed_within_target(sla_con):
    sla_con.execute("""
        insert into stg_jobs values
            ('JOB-2', NULL, 'C2', 'North', 'Emergency', 'Repair', 'T1',
             '2024-01-01 08:00:00', '2024-01-01', '2024-01-01 11:00:00', 'completed')
    """)
    # Emergency target = 6h -> deadline = 2024-01-01 14:00:00; completed at 11:00 is on time.
    sql = render_model_sql("intermediate/int_sla_breach.sql")
    result = sla_con.execute(sql).fetchdf()
    row = result.iloc[0]
    assert bool(row["is_breached"]) is False
    assert int(row["breach_minutes"]) == 0


def test_sla_breach_excludes_non_completed_jobs(sla_con):
    sla_con.execute("""
        insert into stg_jobs values
            ('JOB-3', NULL, 'C3', 'North', 'Standard', 'Repair', 'T1',
             '2024-01-01 08:00:00', '2024-01-01', NULL, 'cancelled')
    """)
    sql = render_model_sql("intermediate/int_sla_breach.sql")
    result = sla_con.execute(sql).fetchdf()
    assert len(result) == 0
