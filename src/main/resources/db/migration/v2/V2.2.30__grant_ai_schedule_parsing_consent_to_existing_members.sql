INSERT INTO ai_schedule_parsing_consent_event (
    member_id,
    event_type,
    policy_version,
    created_at,
    ip_address,
    user_agent
)
SELECT
    m.id,
    'GRANTED',
    '2026-08-13',
    NOW(),
    NULL,
    NULL
FROM member m
WHERE NOT EXISTS (
    SELECT 1
    FROM ai_schedule_parsing_consent_event existing_event
    WHERE existing_event.member_id = m.id
);
