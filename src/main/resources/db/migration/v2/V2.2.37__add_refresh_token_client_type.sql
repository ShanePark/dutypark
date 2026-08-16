ALTER TABLE refresh_token
    ADD COLUMN client_type VARCHAR(20) NOT NULL DEFAULT 'BROWSER';

-- Raw user agents stored for native app sessions: "Dutypark/<build> CFNetwork/<version> Darwin/<version>".
-- Both markers are required so that a browser merely mentioning the product name stays BROWSER.
UPDATE refresh_token
SET client_type = 'IOS_APP'
WHERE user_agent LIKE 'Dutypark/%'
  AND user_agent LIKE '%CFNetwork/%';

-- Legacy rows stored the parsed UserAgentInfo JSON instead of the raw user agent.
-- yauaa reports the native app user agent as os "iOS" with agent name "Dutypark".
UPDATE refresh_token
SET client_type = 'IOS_APP'
WHERE user_agent LIKE '{%'
  AND user_agent LIKE '%"os":"iOS"%'
  AND user_agent LIKE '%"browser":"Dutypark"%';
