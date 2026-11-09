{{ config(materialized='view') }}
select
    id              as event_id,
    at              as occurred_at,
    event_type,
    enrollment_id,
    campaign_id,
    contact_email,
    mailbox_id,
    step_no
from {{ source('gtm', 'seq_events') }}
