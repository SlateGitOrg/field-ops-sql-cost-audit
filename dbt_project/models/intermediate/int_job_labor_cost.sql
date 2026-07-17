-- Labor cost per job = billable (entry_type = 'job') hours * the logging
-- technician's hourly rate. Inner-joined to stg_technicians deliberately:
-- a timesheet logged under an unresolvable technician_id can't be costed,
-- and that gap is tracked (not hidden) via unresolved_labor_hours below.
with job_hours as (

    select
        job_id,
        technician_id,
        sum(hours_worked) as billable_hours
    from {{ ref('stg_timesheets') }}
    where entry_type = 'job'
      and job_id is not null
    group by 1, 2

)

select
    jh.job_id,
    jh.technician_id,
    jh.billable_hours,
    t.hourly_rate,
    round(jh.billable_hours * t.hourly_rate, 2) as labor_cost,
    (t.technician_id is null)                   as has_unresolved_technician
from job_hours jh
left join {{ ref('stg_technicians') }} t
    on jh.technician_id = t.technician_id
