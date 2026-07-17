-- Dedupes double-logged timesheet entries (a payroll-clock glitch that
-- occasionally re-submits the exact same entry a little later). Two
-- entries are treated as the "same" entry if they agree on technician,
-- job, work date, entry type AND hours -- a genuine split shift (e.g.
-- 2.1h logged, then a separate 1.4h logged) has different hours and so
-- survives untouched; only exact repeats are collapsed, keeping the
-- earliest submission.
with source as (

    select
        timesheet_id,
        technician_id,
        nullif(job_id, '')                as job_id,
        cast(work_date as date)           as work_date,
        cast(hours_worked as double)      as hours_worked,
        entry_type,
        cast(logged_at as timestamp)      as logged_at
    from {{ ref('timesheets') }}

),

deduped as (

    select
        *,
        row_number() over (
            partition by technician_id, job_id, work_date, entry_type, hours_worked
            order by logged_at asc
        ) as rn
    from source

)

select
    timesheet_id,
    technician_id,
    job_id,
    work_date,
    hours_worked,
    entry_type,
    logged_at
from deduped
where rn = 1
