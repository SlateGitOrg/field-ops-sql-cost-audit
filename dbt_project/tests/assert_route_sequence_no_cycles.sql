-- dbt singular test: fails (returns rows) if the recursive route-sequence
-- walk didn't resolve every stop on a route exactly once. A cycle, a
-- dangling prev_stop_id (pointing at a stop that doesn't exist), or a
-- route with more than one "first stop" (prev_stop_id IS NULL) would all
-- show up here as a per-route stop-count mismatch between the raw stops
-- table and the recursive output -- silent data-quality failures the
-- recursion itself wouldn't error on.
with raw_counts as (
    select route_id, count(*) as raw_stop_count
    from {{ ref('stg_route_stops') }}
    group by 1
),
sequenced_counts as (
    select route_id, count(*) as sequenced_stop_count, count(distinct stop_sequence_number) as distinct_sequence_numbers
    from {{ ref('int_route_sequence') }}
    group by 1
)
select
    r.route_id,
    r.raw_stop_count,
    coalesce(s.sequenced_stop_count, 0)      as sequenced_stop_count,
    coalesce(s.distinct_sequence_numbers, 0) as distinct_sequence_numbers
from raw_counts r
left join sequenced_counts s on r.route_id = s.route_id
where r.raw_stop_count != coalesce(s.sequenced_stop_count, 0)
   or r.raw_stop_count != coalesce(s.distinct_sequence_numbers, 0)
