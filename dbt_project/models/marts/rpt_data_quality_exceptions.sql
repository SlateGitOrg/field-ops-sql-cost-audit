-- Small audit surface: jobs excluded from fct_job_cost_to_serve because
-- their technician_id never resolved. Kept visible on purpose instead of
-- silently dropped -- this is what an analyst pulls when cost-to-serve
-- totals look short of the raw job count.
select
    j.job_id,
    j.region,
    j.priority,
    j.status,
    j.scheduled_date,
    link.technician_id as unresolved_technician_id,
    'technician_id not found in technicians roster' as exception_reason
from {{ ref('stg_jobs') }} j
inner join {{ ref('int_job_technician_link') }} link
    on j.job_id = link.job_id
where not link.has_valid_technician
