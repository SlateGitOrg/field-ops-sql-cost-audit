-- Travel time attributable to each job: the leg immediately preceding that
-- job's stop on the technician's route. Ad-hoc (route-less) jobs get a
-- flat estimated travel allowance instead, since they have no route_stops
-- row to derive an actual leg from.
select
    job_id,
    leg_travel_minutes,
    cumulative_distance_km,
    'route_leg' as travel_source
from {{ ref('int_route_sequence') }}
where job_id is not null
  and stop_type = 'job_stop'

union all

select
    j.job_id,
    20.0 as leg_travel_minutes,  -- flat estimated single-visit travel allowance
    null as cumulative_distance_km,
    'adhoc_estimate' as travel_source
from {{ ref('stg_jobs') }} j
where j.route_id is null
