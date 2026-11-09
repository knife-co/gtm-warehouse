-- One row per inbound submission, with its routing decision and MQL handoff.
-- Grain verified on live data: 120 submissions, at most ONE decision and ONE
-- handoff each, so the two left joins cannot fan out.
--
-- All 120 rows are is_test = true. No real person has used the inbound form,
-- because it was built and then dropped as the wrong positioning (30 Oct).
-- Every conversion rate below must be computed over `not is_test`, which
-- yields NULL, not zero. "Not measurable" and "0%" are different claims.
{{ config(materialized='table') }}

select
    s.submission_id,
    s.received_at,
    date_trunc('day', s.received_at)::date as received_on,
    s.email_domain,
    s.submission_status,
    s.honeypot_hit,
    s.ack_status,
    s.ack_sent_at,
    s.enrich_status,
    s.processed_at,
    s.is_test,

    d.decision_id,
    d.fit_score,
    d.intent_score,
    d.fit_basis,
    d.tier,
    d.route,
    d.route_reason,
    d.owner_fallback_reason,
    d.decided_at,
    d.decision_id is not null       as was_routed,

    h.handoff_id,
    h.segment,
    h.combined_score,
    h.handed_off_at,
    h.handoff_status,
    h.responded_at,
    h.response_mins,
    h.reject_reason,
    h.handoff_id is not null        as became_mql,
    h.handoff_status = 'accepted'   as was_accepted,

    -- did the owner answer before the clock ran out?
    case when h.responded_at is not null and h.sla_due_at is not null
         then h.responded_at <= h.sla_due_at end as met_sla,

    extract(epoch from (s.ack_sent_at - s.received_at)) as ack_seconds

from {{ ref('stg_submissions') }} s
left join {{ ref('stg_decisions') }} d on d.submission_id = s.submission_id
left join {{ ref('stg_handoffs') }}  h on h.submission_id = s.submission_id
