# Tableau dashboards

Three dashboards, each live-connected (no extracts) directly to a single
reporting view in `main_marts` -- point Tableau at the same Postgres
database dbt is building `marts` into, no intermediate export step.

## 1. Cost-to-Serve Overview
**Source**: `main_marts.fct_job_cost_to_serve`

| Sheet | Chart | Fields |
|---|---|---|
| Cost by region & priority | Heatmap | `region` (rows), `priority` (columns), `AVG(total_cost_to_serve)` (color) |
| Cost composition | Stacked bar | `job_id` (detail), `labor_cost` / `parts_cost_net` / `travel_overhead_cost` (stacked measures) |
| Cost trend | Line, monthly | `DATETRUNC('month', scheduled_date)`, `AVG(total_cost_to_serve)`, split by `region` |
| Top cost drivers | Table | Sorted `total_cost_to_serve` desc, with `labor_cost_share` / `travel_cost_share` as calculated-field callouts |

Calculated fields used:
```
# Cost per travel minute (efficiency signal)
[Cost per Travel Minute] = [total_cost_to_serve] / NULLIF([travel_minutes], 0)
```

## 2. Technician Utilization
**Source**: `main_marts.fct_technician_utilization`

| Sheet | Chart | Fields |
|---|---|---|
| Utilization trend | Line per technician | `week_start`, `rolling_4wk_avg_utilization`, colored by `utilization_band` |
| Region roll-up | Box plot | `region`, distribution of `utilization_rate` |
| Under/overloaded roster | Table + KPI tiles | Filter `utilization_band IN ('Underutilized','Overloaded')`, count distinct `technician_id` |

Reference line at `utilization_rate = 1.0` (100% of standard 40h/week
capacity) makes over/under-loaded weeks visually obvious.

## 3. SLA Breach Hotspots
**Source**: `main_marts.fct_sla_breach_summary` (region/priority/month
rollup) drilling into `main_marts.fct_job_sla_breach` (job grain) via a
dashboard filter action.

| Sheet | Chart | Fields |
|---|---|---|
| Breach rate heatmap | Heatmap | `region` (rows) x `priority` (columns), color = `breach_rate` |
| Breach rate over time | Area chart | `month`, `breach_rate`, split by `region` |
| Breach detail (drill-through) | Table | `job_id`, `breach_minutes`, filtered by the heatmap selection |

This is the dashboard that surfaces the project's headline operational
insight: **East and South carry a materially higher Standard-priority SLA
breach rate than the other three regions** -- see the root-cause note in
the SLA breach table in the top-level README.

## Connecting live

1. Point a new Tableau data source at the Postgres database the `prod`
   dbt target writes to (see "Running against PostgreSQL" in the top-level README) -- host/db/schema from your own `PGHOST` / `PGDATABASE`.
2. Select **Live** (not Extract) so the dashboards always reflect the
   latest `dbt build`.
3. Build from the three `main_marts` / prod-schema views listed above --
   they're already the exact grain and column set each dashboard needs; no
   further joins are required inside Tableau.

No workbook file is included; these are build specifications for the dashboards.
