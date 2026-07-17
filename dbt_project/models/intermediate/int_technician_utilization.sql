-- Weekly technician utilization + a trailing 4-week rolling average,
-- computed with window functions over each technician's own week-ordered
-- history (the second non-trivial SQL pattern, alongside the recursive
-- route sequencing above).
with weekly_hours as (

    select
        technician_id,
        date_trunc('week', work_date)::date                                  as week_start,
        sum(case when entry_type = 'job' then hours_worked else 0 end)       as billable_hours,
        sum(hours_worked)                                                    as total_logged_hours
    from {{ ref('stg_timesheets') }}
    group by 1, 2

),

with_capacity as (

    select
        *,
        -- standard full-time capacity assumption; a technician logging
        -- more than this in a week is working overtime, not "over 100%
        -- utilized" in a way that breaks the metric.
        40.0 as available_hours
    from weekly_hours

)

select
    technician_id,
    week_start,
    billable_hours,
    total_logged_hours,
    available_hours,
    round(billable_hours / available_hours, 4) as utilization_rate,
    round(
        avg(billable_hours / available_hours) over (
            partition by technician_id
            order by week_start
            rows between 3 preceding and current row
        ), 4
    ) as rolling_4wk_avg_utilization,
    row_number() over (
        partition by technician_id order by week_start
    ) as technician_week_number
from with_capacity
