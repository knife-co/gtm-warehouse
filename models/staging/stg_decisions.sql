{{ config(materialized='view') }}
select
    id              as decision_id,
    submission_id,
    fit_score,
    intent_score,
    fit_basis,
    tier,
    route,
    reason          as route_reason,
    owner_id,
    owner_fallback_reason,
    sla_due_at,
    decided_at
from {{ source('gtm', 'inbound_decisions') }}
