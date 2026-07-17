-- Technician roster deduped down to one row per technician_id.
--
-- Pattern: the payroll feed occasionally re-lands a stale row for a
-- technician (e.g. after a name correction), so raw seed can have >1 row
-- per technician_id. We keep the most-recently-updated row per id.
with source as (

    select
        technician_id,
        full_name,
        region,
        cast(hourly_rate as double)      as hourly_rate,
        cast(hire_date as date)          as hire_date,
        cast(active as boolean)          as active,
        cast(record_updated_at as timestamp) as record_updated_at
    from {{ ref('technicians') }}

),

deduped as (

    select
        *,
        row_number() over (
            partition by technician_id
            order by record_updated_at desc
        ) as rn
    from source

)

select
    technician_id,
    full_name,
    region,
    hourly_rate,
    hire_date,
    active,
    record_updated_at
from deduped
where rn = 1
