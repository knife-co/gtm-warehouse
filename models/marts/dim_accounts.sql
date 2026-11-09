-- One row per company. The spine every account question joins to.
-- Verified against live data: 442 rows, 442 distinct keys - three left joins
-- and no fan-out, because each right-hand side is already one row per company.
{{ config(materialized='table') }}

select
    c.company_key,
    c.company_name,
    c.domain,
    c.icp_score,
    c.is_good_fit,
    c.sourced_at,

    e.employee_count,
    e.employee_band,
    e.industry,
    e.enrich_confidence,
    e.identity_check,
    e.company_key is not null        as is_enriched,

    r.latest_tier,
    r.latest_priority,
    r.last_decided_at,
    r.company_key is not null        as is_routed,

    coalesce(s.signal_count, 0)      as signal_count,
    coalesce(s.signal_type_count, 0) as signal_type_count,
    s.first_signal_at,
    s.last_signal_at,
    s.company_key is not null        as has_signal

from {{ ref('stg_companies') }} c
left join {{ ref('stg_enrichment') }}      e on e.company_key = c.company_key
left join {{ ref('int_account_routing') }} r on r.company_key = c.company_key
left join {{ ref('int_company_signals') }} s on s.company_key = c.company_key
