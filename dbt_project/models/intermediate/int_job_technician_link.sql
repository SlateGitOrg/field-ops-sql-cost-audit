-- Explicitly surfaces jobs whose technician_id doesn't resolve to any row
-- in stg_technicians (a decommissioned/mistyped staff id from the dispatch
-- system). Kept as its own model -- rather than silently filtered inside
-- staging -- so the gap is visible and auditable (see
-- rpt_data_quality_exceptions) instead of just disappearing.
select
    j.job_id,
    j.technician_id,
    t.technician_id is not null as has_valid_technician
from {{ ref('stg_jobs') }} j
left join {{ ref('stg_technicians') }} t
    on j.technician_id = t.technician_id
