-- Recursive CTE #1: multi-leg route sequencing.
--
-- stg_route_stops stores each route as a linked list (prev_stop_id points
-- to the stop before it; the first stop of a route has prev_stop_id = NULL).
-- Dispatch/GPS systems hand us stops in this "next pointer" shape rather
-- than a pre-numbered sequence, so we have to walk the chain ourselves to
-- get stop order, cumulative drive distance, and cumulative drive time --
-- the inputs cost-to-serve needs to allocate travel overhead per job.
with recursive route_sequence as (

    -- anchor: the first stop of every route (depot departure)
    select
        stop_id,
        route_id,
        job_id,
        technician_id,
        prev_stop_id,
        stop_type,
        arrival_ts,
        departure_ts,
        distance_from_prev_km,
        1                          as stop_sequence_number,
        cast(0.0 as double)       as leg_travel_minutes,
        cast(0.0 as double)       as cumulative_distance_km,
        cast(0.0 as double)       as cumulative_travel_minutes

    from {{ ref('stg_route_stops') }}
    where prev_stop_id is null

    union all

    -- recursive step: each stop's leg travel time is measured from the
    -- *previous* stop's departure to *this* stop's arrival.
    select
        cur.stop_id,
        cur.route_id,
        cur.job_id,
        cur.technician_id,
        cur.prev_stop_id,
        cur.stop_type,
        cur.arrival_ts,
        cur.departure_ts,
        cur.distance_from_prev_km,
        rs.stop_sequence_number + 1,
        extract(epoch from (cur.arrival_ts - rs.departure_ts)) / 60.0        as leg_travel_minutes,
        rs.cumulative_distance_km + cur.distance_from_prev_km                as cumulative_distance_km,
        rs.cumulative_travel_minutes
            + extract(epoch from (cur.arrival_ts - rs.departure_ts)) / 60.0  as cumulative_travel_minutes

    from {{ ref('stg_route_stops') }} cur
    inner join route_sequence rs on cur.prev_stop_id = rs.stop_id

)

select * from route_sequence
