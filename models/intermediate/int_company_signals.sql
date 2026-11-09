-- One row per company, with its signal history folded in.
-- Fixes the grain for every mart downstream.
{{ config(materialized='table') }}

with per_company as (
    select
        company_key,
        count(*)                    as signal_count,
        count(distinct signal_type) as signal_type_count,
        min(detected_at)            as first_signal_at,
        max(detected_at)            as last_signal_at
    from {{ ref('stg_signals') }}
    where is_resolvable
    group by company_key
)
select * from per_company
