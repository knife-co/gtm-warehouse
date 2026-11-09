-- One row per decision. The router re-decides daily, so this is NOT
-- one row per account - see int_account_routing for that.
{{ config(materialized='view') }}
select
    run_id,
    account_key,
    company_key,
    tier,
    priority,
    icp_score       as decision_icp_score,
    signal_score,
    decided_at
from {{ source('gtm', 'router_decisions') }}
