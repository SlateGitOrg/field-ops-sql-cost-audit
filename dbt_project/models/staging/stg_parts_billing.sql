-- Per-job billing lines. amount can legitimately be negative (a
-- credit_return line for a customer refund/adjustment) -- that's expected
-- messiness, not bad data; cost_to_serve nets these rather than dropping them.
select
    billing_id,
    job_id,
    line_type,
    description,
    cast(amount as double)          as amount,
    cast(billed_at as timestamp)    as billed_at
from {{ ref('parts_billing') }}
