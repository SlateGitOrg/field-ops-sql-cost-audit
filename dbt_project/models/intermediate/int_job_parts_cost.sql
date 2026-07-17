-- Net billing amount per job. Summing (rather than filtering out)
-- credit_return lines is intentional: a customer credit legitimately
-- reduces what it cost to serve that job, it isn't bad data.
select
    job_id,
    sum(amount)                                      as parts_cost_net,
    sum(case when line_type = 'parts' then amount else 0 end)          as parts_only_cost,
    sum(case when line_type = 'credit_return' then amount else 0 end)  as credit_return_total,
    count(*)                                          as billing_line_count
from {{ ref('stg_parts_billing') }}
group by 1
