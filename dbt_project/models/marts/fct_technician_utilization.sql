-- Reporting grain: one row per technician per week. Backs the "Technician
-- Utilization" Tableau dashboard.
select
    u.technician_id,
    t.full_name,
    t.region,
    u.week_start,
    u.billable_hours,
    u.total_logged_hours,
    u.available_hours,
    u.utilization_rate,
    u.rolling_4wk_avg_utilization,
    case
        when u.rolling_4wk_avg_utilization < 0.55 then 'Underutilized'
        when u.rolling_4wk_avg_utilization > 0.95 then 'Overloaded'
        else 'Healthy'
    end as utilization_band
from {{ ref('int_technician_utilization') }} u
inner join {{ ref('dim_technicians') }} t
    on u.technician_id = t.technician_id
