-- One row per sequencer event. Grain verified: 128 rows, 128 distinct event ids.
--
-- is_test comes from the campaign and defaults to TRUE. Every row currently
-- carries is_test = true, because the only campaign run so far was October's
-- dry run to the author's own addresses. Any count of real outreach must
-- filter on `not is_test`, which today returns zero. That is the correct
-- answer, not a broken model.
{{ config(materialized='table') }}

select
    ev.event_id,
    ev.occurred_at,
    date_trunc('day',  ev.occurred_at)::date as occurred_on,
    date_trunc('week', ev.occurred_at)::date as occurred_week,
    ev.event_type,
    ev.step_no,
    ev.contact_email,
    ev.mailbox_id,

    ev.enrollment_id,
    en.enrollment_status,
    en.contact_id,

    ev.campaign_id,
    cp.campaign_name,
    cp.cohort,
    coalesce(cp.is_test, true) as is_test,

    -- the handful of event types that mean a message actually left
    ev.event_type = 'sent'                                   as is_send,
    ev.event_type in ('reply', 'auto_reply')                 as is_reply,
    ev.event_type in ('unsubscribe', 'unsubscribe_repeat')   as is_unsubscribe,
    ev.event_type in ('hard_bounce', 'send_failed')           as is_failure

from {{ ref('stg_events') }} ev
left join {{ ref('stg_enrollments') }} en on en.enrollment_id = ev.enrollment_id
left join {{ ref('stg_campaigns') }}   cp on cp.campaign_id   = ev.campaign_id
