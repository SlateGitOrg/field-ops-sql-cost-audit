-- Job-grain SLA outcome. This is the exact grain the hand-verified sample
-- test (assert_sla_matches_hand_verified_sample) checks against.
select
    job_id,
    region,
    priority,
    created_at,
    completed_at,
    target_resolution_hours,
    sla_deadline,
    is_breached,
    breach_minutes
from {{ ref('int_sla_breach') }}
