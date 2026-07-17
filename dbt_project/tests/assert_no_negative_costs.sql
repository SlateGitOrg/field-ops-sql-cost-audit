-- dbt singular test: fails (returns rows) if any component of cost-to-serve
-- is negative. Net billing (parts_cost_net) is allowed to be negative on
-- its own (a credit_return line), but the components stored here --
-- labor_cost, travel_overhead_cost, and the floored total -- never should be.
select job_id, labor_cost, travel_overhead_cost, total_cost_to_serve
from {{ ref('fct_job_cost_to_serve') }}
where labor_cost < 0
   or travel_overhead_cost < 0
   or total_cost_to_serve < 0
