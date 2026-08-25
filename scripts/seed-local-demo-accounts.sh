#!/usr/bin/env bash

# Creates the loginable account/team/duty-type base rows used by the local demo
# screenshot workflow. This script is intentionally restricted to the isolated
# dutypark_demo database. It must never be pointed at a shared or production DB.

set -Eeuo pipefail

readonly DB_HOST="127.0.0.1"
readonly DB_PORT="3307"
readonly DB_NAME="dutypark_demo"
readonly DB_USER="${DUTYPARK_DEMO_DB_USER:-dutypark}"
readonly DB_PASSWORD="${DUTYPARK_DEMO_DB_PASSWORD:-PASSWORD_HERE}"
readonly DB_CONTAINER="${DUTYPARK_DEMO_DOCKER_CONTAINER:-dutypark-dev-db}"
readonly TEAM_NAME="Dutypark Demo 2026"
readonly OWNER_EMAIL="demo.seoa@dutypark.local"
readonly DEMO_PASSWORD="demo1234!"
readonly BCRYPT_HASH='$2a$10$J6nedueOD3J3OeDW8YDhbOswTZHT9v9GxFLFOEeNSsClA.WFsZUeG'

readonly -a MEMBERS=(
    "윤서아|demo.seoa@dutypark.local"
    "한지우|demo.jiwoo@dutypark.local"
    "김도윤|demo.doyoon@dutypark.local"
    "박하린|demo.harin@dutypark.local"
    "이민준|demo.minjun@dutypark.local"
    "최유나|demo.yuna@dutypark.local"
    "정태오|demo.taeo@dutypark.local"
    "오나리|demo.nari@dutypark.local"
)

# These are the only accounts that an earlier revision of this local marker
# seed created. They may be removed only inside the marker team and only when
# no application data references them.
readonly -a STALE_MEMBERS=(
    "demo.haneul@dutypark.local"
    "demo.minjae@dutypark.local"
    "demo.sodam@dutypark.local"
    "demo.serin@dutypark.local"
)

usage() {
    cat <<'EOF'
Usage: scripts/seed-local-demo-accounts.sh [--dry-run]

Creates or refreshes only the local demo team's eight loginable accounts and
three team duty types. The command is restricted to 127.0.0.1:3307/dutypark_demo.

Required for a real write:
  DUTYPARK_DEMO_CONFIRM=1 scripts/seed-local-demo-accounts.sh

The password demo1234! is local-only and must never be used in production.
The script does not upload profile photos or create schedules, todos, duties,
friends, tags, or notifications; those are created through the application API
after this base seed has printed account IDs.
EOF
}

dry_run=0
case "${1:-}" in
    "") ;;
    --dry-run) dry_run=1 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
esac

# These values are deliberately constants. Do not turn them into general DB
# flags: an accidental production invocation would make this seed destructive
# to the account contract even if the SQL itself only updates marker rows.
if [[ "$DB_HOST" != "127.0.0.1" || "$DB_PORT" != "3307" || "$DB_NAME" != "dutypark_demo" ]]; then
    echo "Refusing to run: demo seed target must be 127.0.0.1:3307/dutypark_demo" >&2
    exit 1
fi

if (( dry_run )); then
    cat <<EOF
target=${DB_HOST}:${DB_PORT}/${DB_NAME}
team=${TEAM_NAME}
accounts=${#MEMBERS[@]}
password=demo1234! (local-only; never use in production)
write=disabled
EOF
    exit 0
fi

if [[ "${DUTYPARK_DEMO_CONFIRM:-}" != "1" ]]; then
    echo "Refusing to write demo data. Set DUTYPARK_DEMO_CONFIRM=1 explicitly." >&2
    exit 1
fi

if ! command -v nc >/dev/null 2>&1; then
    echo "The nc command is required to verify the local MySQL endpoint." >&2
    exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
    echo "The jq command is required to produce the seed result before any database write." >&2
    exit 1
fi
if ! nc -z -w 2 "$DB_HOST" "$DB_PORT" >/dev/null 2>&1; then
    echo "Cannot reach the required local MySQL endpoint ${DB_HOST}:${DB_PORT}." >&2
    exit 1
fi

mysql_args=(--protocol=tcp --host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" --database="$DB_NAME" --default-character-set=utf8mb4 --batch --raw --skip-column-names)
if command -v mysql >/dev/null 2>&1; then
    mysql_command=(mysql "${mysql_args[@]}")
elif command -v docker >/dev/null 2>&1; then
    # macOS developer machines often have Docker's mysql client but no host
    # mysql binary. The endpoint check above still requires the exposed local
    # port, while this fallback keeps the script usable in the dev container.
    mysql_command=(docker exec -i -e "MYSQL_PWD=${DB_PASSWORD}" "$DB_CONTAINER" mysql --protocol=tcp --host=127.0.0.1 --port=3306 --user="$DB_USER" --database="$DB_NAME" --default-character-set=utf8mb4 --batch --raw --skip-column-names)
else
    echo "mysql or docker is required to connect to the local demo database." >&2
    exit 1
fi

run_mysql() {
    if [[ "${mysql_command[0]}" == "docker" ]]; then
        "${mysql_command[@]}" "$@"
    else
        MYSQL_PWD="$DB_PASSWORD" "${mysql_command[@]}" "$@"
    fi
}

member_emails_sql=""
for member in "${MEMBERS[@]}"; do
    email=${member#*|}
    member_emails_sql+="'$email',"
done
member_emails_sql=${member_emails_sql%,}

stale_emails_sql=""
for email in "${STALE_MEMBERS[@]}"; do
    stale_emails_sql+="'$email',"
done
stale_emails_sql=${stale_emails_sql%,}

sql_file=$(mktemp "${TMPDIR:-/tmp}/dutypark-demo-seed.XXXXXX.sql")
trap 'rm -f "$sql_file"' EXIT

cat >"$sql_file" <<SQL
SET SESSION time_zone = '+00:00';
START TRANSACTION;

SET @seed_now = DATE_ADD(UTC_TIMESTAMP(6), INTERVAL 9 HOUR);

INSERT INTO team (
    name, created_date, modified_date, description, admin_id,
    default_duty_name, duty_batch_template, default_duty_color
) VALUES (
    '${TEAM_NAME}', @seed_now, @seed_now, 'Local-only sample data for screenshots', NULL,
    'OFF', NULL, '#20B8B0'
)
ON DUPLICATE KEY UPDATE
    id = LAST_INSERT_ID(id),
    description = VALUES(description),
    modified_date = @seed_now,
    default_duty_name = VALUES(default_duty_name),
    default_duty_color = VALUES(default_duty_color);

SET @seed_team_id = (SELECT id FROM team WHERE name = '${TEAM_NAME}' LIMIT 1);

-- Remove only the previous seed revision's marker accounts. The shell
-- preflight refuses this transaction when any application row references one.
DELETE FROM member
WHERE team_id = @seed_team_id
  AND email IN (${stale_emails_sql});

-- The marker emails are owned by this local seed. A matching email in another
-- team is rejected by the shell preflight below before this transaction runs.
INSERT INTO member (name, password, team_id, email, calendar_visibility, created_date, modified_date, status)
SELECT seed.name, '${BCRYPT_HASH}', @seed_team_id,
       seed.email, 'FRIENDS', @seed_now, @seed_now, 'ACTIVE'
FROM (
    SELECT '윤서아' AS name, 'demo.seoa@dutypark.local' AS email
    UNION ALL SELECT '한지우', 'demo.jiwoo@dutypark.local'
    UNION ALL SELECT '김도윤', 'demo.doyoon@dutypark.local'
    UNION ALL SELECT '박하린', 'demo.harin@dutypark.local'
    UNION ALL SELECT '이민준', 'demo.minjun@dutypark.local'
    UNION ALL SELECT '최유나', 'demo.yuna@dutypark.local'
    UNION ALL SELECT '정태오', 'demo.taeo@dutypark.local'
    UNION ALL SELECT '오나리', 'demo.nari@dutypark.local'
) seed
WHERE NOT EXISTS (SELECT 1 FROM member existing WHERE existing.email = seed.email);

UPDATE member
SET name = CASE email
    WHEN 'demo.seoa@dutypark.local' THEN '윤서아'
    WHEN 'demo.jiwoo@dutypark.local' THEN '한지우'
    WHEN 'demo.doyoon@dutypark.local' THEN '김도윤'
    WHEN 'demo.harin@dutypark.local' THEN '박하린'
    WHEN 'demo.minjun@dutypark.local' THEN '이민준'
    WHEN 'demo.yuna@dutypark.local' THEN '최유나'
    WHEN 'demo.taeo@dutypark.local' THEN '정태오'
    WHEN 'demo.nari@dutypark.local' THEN '오나리'
END,
    password = '${BCRYPT_HASH}',
    team_id = @seed_team_id,
    calendar_visibility = 'FRIENDS',
    modified_date = @seed_now,
    status = 'ACTIVE',
    deletion_requested_at = NULL
WHERE email IN (${member_emails_sql});

SET @seed_owner_id = (SELECT id FROM member WHERE email = '${OWNER_EMAIL}' AND team_id = @seed_team_id ORDER BY id LIMIT 1);
UPDATE team SET admin_id = @seed_owner_id, modified_date = @seed_now WHERE id = @seed_team_id;

INSERT INTO duty_type (name, position, team_id, color, hidden)
SELECT seed.name, seed.position, @seed_team_id, seed.color, 0
FROM (
    SELECT '오전' AS name, 0 AS position, '#20B8B0' AS color
    UNION ALL SELECT '오후', 1, '#FFC857'
    UNION ALL SELECT '야간', 2, '#5865F2'
) seed
WHERE NOT EXISTS (
    SELECT 1 FROM duty_type existing
    WHERE existing.team_id = @seed_team_id AND existing.name = seed.name
);

UPDATE duty_type SET position = 0, color = '#20B8B0', hidden = 0
WHERE team_id = @seed_team_id AND name = '오전';
UPDATE duty_type SET position = 1, color = '#FFC857', hidden = 0
WHERE team_id = @seed_team_id AND name = '오후';
UPDATE duty_type SET position = 2, color = '#5865F2', hidden = 0
WHERE team_id = @seed_team_id AND name = '야간';

COMMIT;

SELECT id, email, name FROM member
WHERE team_id = @seed_team_id AND email IN (${member_emails_sql})
ORDER BY FIELD(email,
    'demo.seoa@dutypark.local', 'demo.jiwoo@dutypark.local',
    'demo.doyoon@dutypark.local', 'demo.harin@dutypark.local',
    'demo.minjun@dutypark.local', 'demo.yuna@dutypark.local',
    'demo.taeo@dutypark.local', 'demo.nari@dutypark.local'
);
SQL

# Abort before the transaction if a marker email is already attached to an
# unrelated team. This prevents an accidental account takeover while allowing
# an interrupted prior seed to be repaired safely. When the marker team does
# not exist yet, every existing marker email is a conflict.
existing_team_id=$(run_mysql -e "SELECT id FROM team WHERE name = '${TEAM_NAME}' LIMIT 1;")
if [[ -z "$existing_team_id" ]]; then
    conflict_count=$(run_mysql -e "
    SELECT COUNT(*) FROM member WHERE email IN (${member_emails_sql});
    ")
else
    conflict_count=$(run_mysql -e "
    SELECT COUNT(*)
    FROM member
    WHERE email IN (${member_emails_sql})
      AND (team_id IS NULL OR team_id <> ${existing_team_id});
    ")
fi
if [[ "$conflict_count" != "0" ]]; then
    echo "Refusing to update marker email(s) owned by another team." >&2
    exit 1
fi

# Never delete a stale marker account after another step has started using it.
# This deliberately checks both FK-backed and legacy, non-FK tables because the
# latter can otherwise leave orphaned schedules or friends behind.
stale_dependency_count=0
if [[ -n "$existing_team_id" ]]; then
    stale_member_ids="SELECT id FROM member WHERE team_id = ${existing_team_id} AND email IN (${stale_emails_sql})"
    stale_dependency_count=$(run_mysql -e "
    SELECT COALESCE(SUM(ref_count), 0)
    FROM (
        SELECT COUNT(*) AS ref_count FROM schedule WHERE member_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM todo WHERE member_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM duty WHERE member_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM d_day_event WHERE member_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM friends WHERE member_id IN (${stale_member_ids}) OR friend_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM friend_requests WHERE from_member_id IN (${stale_member_ids}) OR to_member_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM notifications WHERE member_id IN (${stale_member_ids}) OR actor_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM schedule_tags WHERE member_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM todo_tags WHERE member_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM member_manager WHERE manager_id IN (${stale_member_ids}) OR managed_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM team_managers WHERE member_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM team_schedule WHERE create_member_id IN (${stale_member_ids}) OR update_member_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM refresh_token WHERE member_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM member_social_account WHERE member_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM member_consent WHERE member_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM ai_schedule_parsing_consent_event WHERE member_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM content_report WHERE reporter_id IN (${stale_member_ids}) OR reported_member_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM inquiry WHERE member_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM member_block WHERE blocker_id IN (${stale_member_ids}) OR blocked_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM member_duty_pattern WHERE member_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM account_reauth_proof WHERE member_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM mobile_oauth_transaction WHERE member_id IN (${stale_member_ids}) OR link_member_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM web_oauth_transaction WHERE link_member_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM account_deletion_job WHERE root_member_id IN (${stale_member_ids}) OR replacement_manager_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM account_deletion_target_member WHERE member_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM attachment WHERE created_by IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM attachment_upload_session WHERE owner_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM team WHERE admin_id IN (${stale_member_ids})
        UNION ALL SELECT COUNT(*) FROM login_attempt WHERE email IN (${stale_emails_sql})
    ) refs;
    ")
fi
if [[ "$stale_dependency_count" != "0" ]]; then
    echo "Refusing to remove stale marker account(s) with existing application data." >&2
    exit 1
fi

rows=$(run_mysql <"$sql_file")
row_lines=()
while IFS= read -r row_line; do
    [[ -z "$row_line" ]] && continue
    row_lines[${#row_lines[@]}]="$row_line"
done <<<"$rows"
if (( ${#row_lines[@]} != ${#MEMBERS[@]} )); then
    echo "Expected ${#MEMBERS[@]} demo accounts, got ${#row_lines[@]}." >&2
    exit 1
fi

team_id=$(run_mysql -e "SELECT id FROM team WHERE name = '${TEAM_NAME}' LIMIT 1;")
duty_types=$(run_mysql -e "
SELECT JSON_ARRAYAGG(JSON_OBJECT('id', id, 'name', name, 'position', position))
FROM duty_type WHERE team_id = (SELECT id FROM team WHERE name = '${TEAM_NAME}' LIMIT 1);
")

members_json='[]'
for row in "${row_lines[@]}"; do
    IFS=$'\t' read -r id email name <<<"$row"
    members_json=$(jq -c --arg id "$id" --arg email "$email" --arg name "$name" \
        '. + [{id: ($id | tonumber), email: $email, name: $name}]' <<<"$members_json")
done

jq -n \
    --arg database "${DB_HOST}:${DB_PORT}/${DB_NAME}" \
    --arg teamName "$TEAM_NAME" \
    --arg teamId "$team_id" \
    --arg password "$DEMO_PASSWORD" \
    --argjson members "$members_json" \
    --argjson dutyTypes "${duty_types:-[]}" \
    '{database: $database, team: {id: ($teamId | tonumber), name: $teamName}, credentials: {password: $password, localOnly: true}, members: $members, dutyTypes: $dutyTypes}'
