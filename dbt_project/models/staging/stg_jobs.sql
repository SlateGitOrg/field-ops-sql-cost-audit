-- Cleans the raw dispatch/work-order feed: blank strings -> NULL, casts
-- timestamps, and standardizes status. Does NOT drop or "fix" the jobs
-- with an unresolvable technician_id -- that referential check happens
-- explicitly downstream (int_job_valid_technician / assert_no_orphaned_jobs)
-- so the gap stays visible rather than silently vanishing in staging.
select
    job_id,
    nullif(route_id, '')                    as route_id,
    customer_id,
    region,
    priority,
    job_type,
    nullif(technician_id, '')               as technician_id,
    cast(created_at as timestamp)           as created_at,
    cast(scheduled_date as date)            as scheduled_date,
    case when completed_at = '' then null
         else cast(completed_at as timestamp) end as completed_at,
    status
from {{ ref('jobs') }}
