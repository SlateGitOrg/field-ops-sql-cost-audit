select
    priority,
    cast(target_resolution_hours as integer) as target_resolution_hours
from {{ ref('sla_targets') }}
