{{ config(materialized='view') }}
select
    id              as enrollment_id,
    campaign_id,
    contact_id,
    mailbox_id,
    status          as enrollment_status,
    next_step,
    created_at      as enrolled_at,
    updated_at
from {{ source('gtm', 'seq_enrollments') }}
