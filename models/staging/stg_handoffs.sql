{{ config(materialized='view') }}
select
    id              as handoff_id,
    submission_id,
    segment,
    fit_score       as handoff_fit,
    engagement,
    combined        as combined_score,
    owner_id,
    owner_fallback,
    created_at      as handed_off_at,
    sla_due_at,
    status          as handoff_status,
    responded_at,
    response_mins,
    reject_reason,
    coalesce(is_test, true) as is_test
from {{ source('gtm', 'mql_handoffs') }}
