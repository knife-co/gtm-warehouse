{{ config(materialized='view') }}
select
    company_key,
    employee_count,
    employee_band,
    industry_sf     as industry,
    confidence      as enrich_confidence,
    identity_check,
    enriched_at
from {{ source('gtm', 'account_enrichment') }}
