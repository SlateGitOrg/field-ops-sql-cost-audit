"""Tests for the synthetic data generator itself: determinism, and that
the deliberate messiness (dupes, orphans, negative credit lines) it's
supposed to inject is actually present -- since the whole point of this
dataset is to exercise staging's cleaning logic, a generator that stopped
producing messy rows would silently defang every downstream test.
"""
from __future__ import annotations

import importlib

import generate_data as gen


def test_generation_is_deterministic():
    """Same fixed seed -> byte-identical output, both runs."""
    gen.random.seed(gen.SEED)
    techs_1 = gen.gen_technicians()
    jobs_1, stops_1 = gen.gen_routes_and_jobs(techs_1)

    gen.random.seed(gen.SEED)
    techs_2 = gen.gen_technicians()
    jobs_2, stops_2 = gen.gen_routes_and_jobs(techs_2)

    assert [t.technician_id for t in techs_1] == [t.technician_id for t in techs_2]
    assert [t.hourly_rate for t in techs_1] == [t.hourly_rate for t in techs_2]
    assert [j.job_id for j in jobs_1] == [j.job_id for j in jobs_2]
    assert [j.created_at for j in jobs_1] == [j.created_at for j in jobs_2]
    assert len(stops_1) == len(stops_2)


def test_technician_rows_include_deliberate_duplicates():
    gen.random.seed(gen.SEED)
    techs = gen.gen_technicians()
    rows = gen.messy_technician_rows(techs)
    ids = [r["technician_id"] for r in rows]
    distinct_ids = set(ids)

    assert len(rows) > len(distinct_ids), "expected at least one duplicated technician_id row"
    assert len(distinct_ids) == gen.N_TECHNICIANS


def test_jobs_include_orphaned_technician_references():
    gen.random.seed(gen.SEED)
    techs = gen.gen_technicians()
    jobs, _ = gen.gen_routes_and_jobs(techs)

    valid_ids = {t.technician_id for t in techs}
    orphaned = [j for j in jobs if j.technician_id not in valid_ids]

    assert len(orphaned) > 0, "expected some jobs to reference a technician_id outside the roster"
    assert all(j.technician_id == gen.TECH_ORPHAN_ID for j in orphaned)


def test_timesheets_include_deliberate_double_logged_duplicates():
    gen.random.seed(gen.SEED)
    techs = gen.gen_technicians()
    jobs, _ = gen.gen_routes_and_jobs(techs)
    rows = gen.gen_timesheets(jobs, techs)

    # group by the natural key staging dedupes on, and look for a group
    # with more than one row sharing identical hours (the true-duplicate case)
    from collections import defaultdict
    groups = defaultdict(list)
    for r in rows:
        key = (r["technician_id"], r["job_id"], r["work_date"], r["entry_type"], r["hours_worked"])
        groups[key].append(r)

    dup_groups = [g for g in groups.values() if len(g) > 1]
    assert len(dup_groups) > 0, "expected at least one double-logged timesheet duplicate"


def test_billing_includes_negative_credit_return_lines():
    gen.random.seed(gen.SEED)
    techs = gen.gen_technicians()
    jobs, _ = gen.gen_routes_and_jobs(techs)
    billing = gen.gen_parts_billing(jobs)

    negatives = [b for b in billing if b["amount"] < 0]
    assert len(negatives) > 0, "expected at least one credit_return line with a negative amount"
    assert all(b["line_type"] == "credit_return" for b in negatives)
    # parts lines themselves should never be negative
    parts_lines = [b for b in billing if b["line_type"] == "parts"]
    assert all(b["amount"] > 0 for b in parts_lines)


def test_hand_verified_sla_sample_matches_independent_recomputation():
    """Recomputes breach outcome for the hand-verified sample a THIRD way
    (independent of both generate_data's own oracle function and the SQL)
    to catch a bug in the oracle itself, not just a bug the oracle would share
    with the SQL."""
    import datetime as dt

    gen.random.seed(gen.SEED)
    techs = gen.gen_technicians()
    jobs, _ = gen.gen_routes_and_jobs(techs)
    sample = gen.build_hand_verified_sla_sample(jobs, n=20)

    jobs_by_id = {j.job_id: j for j in jobs}
    for row in sample:
        job = jobs_by_id[row["job_id"]]
        target_hours = gen.SLA_TARGET_HOURS[row["priority"]]
        deadline = job.created_at + dt.timedelta(hours=target_hours)
        expected_breached = job.completed_at > deadline
        expected_minutes = max(0, int((job.completed_at - deadline).total_seconds() / 60))

        assert row["expected_is_breached"] == expected_breached
        assert row["expected_breach_minutes"] == expected_minutes


def test_module_is_importable_and_reloadable():
    """Sanity check that the module has no import-time side effects that
    break on a second import (e.g. accidentally re-seeding global random
    state in a way that breaks other tests importing it later)."""
    reloaded = importlib.reload(gen)
    assert reloaded.N_TECHNICIANS == 30
