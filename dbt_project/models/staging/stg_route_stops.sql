-- One row per stop on a technician's route. prev_stop_id forms a linked
-- list per route_id (NULL prev_stop_id = first stop / depot departure);
-- int_route_sequence walks this list with a recursive CTE.
select
    stop_id,
    route_id,
    nullif(job_id, '')                             as job_id,
    technician_id,
    nullif(prev_stop_id, '')                        as prev_stop_id,
    stop_type,
    cast(arrival_ts as timestamp)                  as arrival_ts,
    cast(departure_ts as timestamp)                as departure_ts,
    case when distance_from_prev_km = '' then 0.0
         else cast(distance_from_prev_km as double) end as distance_from_prev_km
from {{ ref('route_stops') }}
