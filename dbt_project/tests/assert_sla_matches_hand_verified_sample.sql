-- dbt singular test: fails (returns rows) if fct_job_sla_breach disagrees
-- with the hand-verified sample -- ~20 jobs whose breach outcome was
-- derived independently in Python straight from created_at/completed_at
-- + the SLA policy table (data_generation/generate_data.py::
-- build_hand_verified_sla_sample), NOT by re-running the SQL. Any drift
-- between the two independent derivations means the SQL logic changed in
-- a way that actually altered outcomes.
select
    sample.job_id,
    sample.expected_is_breached,
    fct.is_breached,
    sample.expected_breach_minutes,
    fct.breach_minutes
from {{ ref('sla_hand_verified_sample') }} sample
inner join {{ ref('fct_job_sla_breach') }} fct
    on sample.job_id = fct.job_id
where sample.expected_is_breached != fct.is_breached
   or sample.expected_breach_minutes != fct.breach_minutes
