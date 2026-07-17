-- dbt singular test: fails (returns rows) if fct_job_cost_to_serve ever
-- contains a job whose technician_id doesn't resolve to dim_technicians.
-- This is the invariant int_job_cost_to_serve's inner join is supposed to
-- guarantee; this test exists so a future refactor that loosens that join
-- gets caught immediately rather than quietly re-introducing orphans.
select f.job_id, f.technician_id
from {{ ref('fct_job_cost_to_serve') }} f
left join {{ ref('dim_technicians') }} t
    on f.technician_id = t.technician_id
where t.technician_id is null
