-- SLA breach outcome per completed job. Deliberately independent of the
-- cost-to-serve technician-resolution logic above: SLA compliance is a
-- pure function of (created_at, completed_at, priority -> target hours),
-- so a job with an unresolvable technician_id can still have a perfectly
-- well-defined breach outcome.
--
-- This exact formula (deadline = created_at + target_resolution_hours;
-- breached = completed_at > deadline) is what
-- assert_sla_matches_hand_verified_sample.sql checks against a sample
-- that was derived independently in Python (see
-- data_generation/generate_data.py::build_hand_verified_sla_sample).
select
    j.job_id,
    j.priority,
    j.region,
    j.created_at,
    j.completed_at,
    st.target_resolution_hours,
    j.created_at + (st.target_resolution_hours * interval '1 hour')       as sla_deadline,
    (j.completed_at > j.created_at + (st.target_resolution_hours * interval '1 hour')) as is_breached,
    greatest(
        0,
        cast(extract(epoch from (
            j.completed_at - (j.created_at + (st.target_resolution_hours * interval '1 hour'))
        )) / 60.0 as integer)
    ) as breach_minutes
from {{ ref('stg_jobs') }} j
inner join {{ ref('stg_sla_targets') }} st
    on j.priority = st.priority
where j.status = 'completed'
  and j.completed_at is not null
