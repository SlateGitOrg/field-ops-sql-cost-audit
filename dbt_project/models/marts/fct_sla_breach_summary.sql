-- Reporting grain: one row per region/priority/month. Backs the "SLA
-- Breach Hotspots" Tableau dashboard -- where breach concentration lives,
-- not just the overall rate.
select
    region,
    priority,
    date_trunc('month', created_at)::date as month,
    count(*)                              as total_jobs,
    sum(case when is_breached then 1 else 0 end) as breached_jobs,
    round(
        sum(case when is_breached then 1 else 0 end)::double / count(*), 4
    ) as breach_rate,
    round(avg(breach_minutes) filter (where is_breached), 1) as avg_breach_minutes
from {{ ref('fct_job_sla_breach') }}
group by 1, 2, 3
