-- Reporting grain: one row per completed job with a resolvable
-- technician. This is the table Tableau's "Cost-to-Serve Overview"
-- dashboard connects to directly.
select
    job_id,
    region,
    priority,
    job_type,
    scheduled_date,
    created_at,
    completed_at,
    technician_id,
    technician_region,
    labor_cost,
    parts_cost_net,
    travel_minutes,
    travel_overhead_cost,
    total_cost_to_serve,
    round(labor_cost / nullif(total_cost_to_serve, 0), 4)          as labor_cost_share,
    round(travel_overhead_cost / nullif(total_cost_to_serve, 0), 4) as travel_cost_share
from {{ ref('int_job_cost_to_serve') }}
