select
    technician_id,
    full_name,
    region,
    hourly_rate,
    hire_date,
    active
from {{ ref('stg_technicians') }}
