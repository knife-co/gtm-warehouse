{{ config(materialized='view') }}
select
    company_key,
    company_name,
    domain,
    coalesce(icp_score, 0)       as icp_score,
    coalesce(gate_passed, false) as is_good_fit,
    created_at                   as sourced_at
from {{ source('gtm', 'icp_companies') }}
