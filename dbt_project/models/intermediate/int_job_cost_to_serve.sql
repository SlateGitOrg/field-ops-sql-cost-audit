-- Assembles the full cost-to-serve for every job with a resolvable
-- technician: labor + net parts/billing + allocated travel overhead.
--
-- Jobs whose technician_id doesn't resolve (int_job_technician_link.
-- has_valid_technician = false) are deliberately excluded here rather than
-- costed with a guessed rate -- they surface instead in
-- rpt_data_quality_exceptions. This is what keeps fct_job_cost_to_serve
-- free of orphaned-technician jobs (assert_no_orphaned_jobs).
--
-- total_cost_to_serve is floored at 0: a job that nets negative purely
-- because of a customer credit_return still cost something to dispatch;
-- we don't report a "negative cost" job, we report a $0-floor one and let
-- the credit show up in parts_cost_net for anyone drilling in.
with travel as (

    select
        job_id,
        sum(leg_travel_minutes)      as travel_minutes,
        max(cumulative_distance_km)  as cumulative_distance_km
    from {{ ref('int_job_travel_minutes') }}
    group by 1

),

costed as (

    select
        j.job_id,
        j.region,
        j.priority,
        j.job_type,
        j.status,
        j.scheduled_date,
        j.created_at,
        j.completed_at,
        link.technician_id,
        t.region        as technician_region,
        coalesce(labor.labor_cost, 0)                                   as labor_cost,
        coalesce(parts.parts_cost_net, 0)                               as parts_cost_net,
        coalesce(travel.travel_minutes, 0)                              as travel_minutes,
        round(coalesce(travel.travel_minutes, 0) / 60.0 * t.hourly_rate, 2) as travel_overhead_cost
    from {{ ref('stg_jobs') }} j
    inner join {{ ref('int_job_technician_link') }} link
        on j.job_id = link.job_id and link.has_valid_technician
    inner join {{ ref('stg_technicians') }} t
        on link.technician_id = t.technician_id
    left join {{ ref('int_job_labor_cost') }} labor
        on j.job_id = labor.job_id
    left join {{ ref('int_job_parts_cost') }} parts
        on j.job_id = parts.job_id
    left join travel
        on j.job_id = travel.job_id
    where j.status = 'completed'

)

select
    job_id,
    region,
    priority,
    job_type,
    status,
    scheduled_date,
    created_at,
    completed_at,
    technician_id,
    technician_region,
    labor_cost,
    parts_cost_net,
    travel_minutes,
    travel_overhead_cost,
    greatest(labor_cost + parts_cost_net + travel_overhead_cost, 0) as total_cost_to_serve
from costed
