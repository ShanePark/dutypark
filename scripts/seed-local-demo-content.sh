#!/usr/bin/env bash

# Populates the local-only demo teams after seed-local-demo-accounts.sh has
# created their loginable members. Database writes are limited to the isolated
# MySQL target, and API writes are allowed only after the running localhost
# backend proves that it serves the same marker member/team identities. This
# script intentionally has no host/database arguments: a typo must not turn a
# screenshot fixture into a production data writer.

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly AVATAR_DIR="${SCRIPT_DIR}/../docs/demo/avatars"
readonly DB_HOST="127.0.0.1"
readonly DB_PORT="3307"
readonly DB_NAME="dutypark_demo"
readonly DB_USER="${DUTYPARK_DEMO_DB_USER:-dutypark}"
readonly DB_PASSWORD="${DUTYPARK_DEMO_DB_PASSWORD:-PASSWORD_HERE}"
readonly DB_CONTAINER="${DUTYPARK_DEMO_DOCKER_CONTAINER:-dutypark-dev-db}"
readonly API_BASE_URL="${DUTYPARK_DEMO_API_BASE_URL:-http://127.0.0.1:8080}"
readonly DEMO_CONFIRM_VALUE="1"
readonly DEMO_PASSWORD="demo1234!"
readonly DEMO_BCRYPT_HASH='$2a$10$J6nedueOD3J3OeDW8YDhbOswTZHT9v9GxFLFOEeNSsClA.WFsZUeG'
readonly KO_TEAM_NAME="Dutypark Demo 2026"
readonly EN_TEAM_NAME="Dutypark English Demo 2026"
readonly KO_OWNER_EMAIL="demo.seoa@dutypark.local"
readonly EN_OWNER_EMAIL="demo.en.emma@dutypark.local"
readonly CAPTURE_DATE="2026-08-29"
readonly ENGLISH_CALENDAR_MONTH="2026-11"

readonly -a KO_MEMBERS=(
    "윤서아|demo.seoa@dutypark.local|seoa-moon-rabbit.png"
    "한지우|demo.jiwoo@dutypark.local|jiwoo-coral-bear.png"
    "김도윤|demo.doyoon@dutypark.local|doyoon-night-owl.png"
    "박하린|demo.harin@dutypark.local|harin-sunny-puppy.png"
    "이민준|demo.minjun@dutypark.local|minjun-teal-fox.png"
    "최유나|demo.yuna@dutypark.local|yuna-mint-cat.png"
    "정태오|demo.taeo@dutypark.local|taeo-lavender-otter.png"
    "오나리|demo.nari@dutypark.local|nari-peach-red-panda.png"
)

readonly -a EN_MEMBERS=(
    "Emma Moon|demo.en.emma@dutypark.local|seoa-moon-rabbit.png"
    "Jamie Bear|demo.en.jamie@dutypark.local|jiwoo-coral-bear.png"
    "Noah Owl|demo.en.noah@dutypark.local|doyoon-night-owl.png"
    "Chloe Sunny|demo.en.chloe@dutypark.local|harin-sunny-puppy.png"
    "Liam Fox|demo.en.liam@dutypark.local|minjun-teal-fox.png"
    "Sophia Cat|demo.en.sophia@dutypark.local|yuna-mint-cat.png"
    "Ethan Otter|demo.en.ethan@dutypark.local|taeo-lavender-otter.png"
    "Ava Panda|demo.en.ava@dutypark.local|nari-peach-red-panda.png"
)

readonly -a KO_DATES=(
    "2026-08-24" "2026-08-25" "2026-08-26" "2026-08-27"
    "2026-08-28" "2026-08-29" "2026-08-30" "2026-08-31"
)
readonly -a EN_DATES=(
    "2026-08-24" "2026-08-25" "2026-08-26" "2026-08-27"
    "2026-08-28" "2026-08-29" "2026-08-30" "2026-08-31"
    "2026-11-01" "2026-11-02" "2026-11-03" "2026-11-04"
    "2026-11-05" "2026-11-06" "2026-11-07" "2026-11-08"
    "2026-11-09" "2026-11-10" "2026-11-11" "2026-11-12"
    "2026-11-13" "2026-11-14" "2026-11-15" "2026-11-16"
    "2026-11-17" "2026-11-18" "2026-11-19" "2026-11-20"
    "2026-11-21" "2026-11-22" "2026-11-23" "2026-11-24"
    "2026-11-25" "2026-11-26" "2026-11-27" "2026-11-28"
    "2026-11-29" "2026-11-30"
)

CLEANUP_FILES=()
cleanup_file() {
    CLEANUP_FILES+=("$1")
}
cleanup_all() {
    local path
    (( ${#CLEANUP_FILES[@]} == 0 )) && return
    for path in "${CLEANUP_FILES[@]}"; do
        [[ -n "$path" ]] && rm -f "$path"
    done
}
trap cleanup_all EXIT

usage() {
    cat <<'EOF'
Usage: scripts/seed-local-demo-content.sh [--dry-run]

Creates the deterministic Korean and English local screenshot fixtures. The
script first runs seed-local-demo-accounts.sh, creates/refreshes the English
marker team, uploads the generated avatars, and then uses the localhost API
for schedules, Todos, D-Days, friends, pins, tags, notifications, and team
schedules. Duties are the only bulk rows inserted directly, because no API
creates deterministic duty rows for a capture date.

The only writable targets are:
  MySQL  127.0.0.1:3307/dutypark_demo
  API    http://127.0.0.1:8080 (default) or http://127.0.0.1:8081

Required for a real write:
  DUTYPARK_DEMO_CONFIRM=1 scripts/seed-local-demo-content.sh

To use an isolated demo backend without touching a developer server on 8080:
  DUTYPARK_DEMO_CONFIRM=1 \
  DUTYPARK_DEMO_API_BASE_URL=http://127.0.0.1:8081 \
  scripts/seed-local-demo-content.sh

All accounts use the local-only password demo1234!. Never run this against a
shared or production database.
EOF
}

dry_run=0
case "${1:-}" in
    "") ;;
    --dry-run) dry_run=1 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
esac

if [[ "$DB_HOST" != "127.0.0.1" || "$DB_PORT" != "3307" || "$DB_NAME" != "dutypark_demo" ]]; then
    echo "Refusing to run: demo seed target must be 127.0.0.1:3307/dutypark_demo." >&2
    exit 1
fi
case "$API_BASE_URL" in
    http://127.0.0.1:8080|http://127.0.0.1:8081) ;;
    *)
        echo "Refusing to run: demo API target must be loopback port 8080 or 8081." >&2
        exit 1
        ;;
esac

if (( dry_run )); then
    cat <<EOF
mysql=${DB_HOST}:${DB_PORT}/${DB_NAME}
api=${API_BASE_URL}
koreanAccounts=${#KO_MEMBERS[@]}
englishAccounts=${#EN_MEMBERS[@]}
captureDate=${CAPTURE_DATE}
englishCalendarMonth=${ENGLISH_CALENDAR_MONTH}
write=disabled
EOF
    exit 0
fi

if [[ "${DUTYPARK_DEMO_CONFIRM:-}" != "$DEMO_CONFIRM_VALUE" ]]; then
    echo "Refusing to write demo content. Set DUTYPARK_DEMO_CONFIRM=1 explicitly." >&2
    exit 1
fi

for command_name in curl jq nc; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "The ${command_name} command is required before any database or API write." >&2
        exit 1
    fi
done
for avatar in \
    seoa-moon-rabbit.png jiwoo-coral-bear.png doyoon-night-owl.png \
    harin-sunny-puppy.png minjun-teal-fox.png yuna-mint-cat.png \
    taeo-lavender-otter.png nari-peach-red-panda.png; do
    if [[ ! -f "${AVATAR_DIR}/${avatar}" ]]; then
        echo "Missing generated avatar: ${AVATAR_DIR}/${avatar}" >&2
        exit 1
    fi
done
if ! nc -z -w 2 "$DB_HOST" "$DB_PORT" >/dev/null 2>&1; then
    echo "Cannot reach the required local MySQL endpoint ${DB_HOST}:${DB_PORT}." >&2
    exit 1
fi
if ! curl -fsS --connect-timeout 2 "${API_BASE_URL}/api/auth/status" >/dev/null; then
    echo "Cannot reach the required local API ${API_BASE_URL}." >&2
    exit 1
fi

mysql_args=(--protocol=tcp --host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" --database="$DB_NAME" --default-character-set=utf8mb4 --batch --raw --skip-column-names)
if command -v mysql >/dev/null 2>&1; then
    mysql_command=(mysql "${mysql_args[@]}")
elif command -v docker >/dev/null 2>&1; then
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

run_sql() {
    run_mysql -e "$1"
}

sql_quote() {
    # All callers pass fixed, checked-in fixture strings. This helper still
    # doubles apostrophes so a future display-name edit cannot break SQL.
    printf "%s" "$1" | sed "s/'/''/g"
}

if [[ "${mysql_command[0]}" == "docker" ]]; then
    if ! docker inspect "$DB_CONTAINER" >/dev/null 2>&1; then
        echo "The configured local Docker database container is unavailable: ${DB_CONTAINER}." >&2
        exit 1
    fi
fi

# The base script owns the Korean marker team and all Korean account rows.
# Calling it here keeps its conflict/stale-reference protections in one place.
DUTYPARK_DEMO_CONFIRM=1 "${SCRIPT_DIR}/seed-local-demo-accounts.sh" >/dev/null

# Create the English marker team/account base in the same isolated DB. It is
# intentionally not exposed as a general-purpose seed target or an API account
# creation flow (the product has no ordinary email/password signup endpoint).
en_emails_sql="'demo.en.emma@dutypark.local','demo.en.jamie@dutypark.local','demo.en.noah@dutypark.local','demo.en.chloe@dutypark.local','demo.en.liam@dutypark.local','demo.en.sophia@dutypark.local','demo.en.ethan@dutypark.local','demo.en.ava@dutypark.local'"
existing_en_team_id=$(run_sql "SELECT COALESCE((SELECT id FROM team WHERE name = '${EN_TEAM_NAME}' LIMIT 1), 0);")
en_conflict_count=$(run_sql "SELECT COUNT(*) FROM member WHERE email IN (${en_emails_sql}) AND (team_id IS NULL OR team_id <> ${existing_en_team_id});")
if [[ "$en_conflict_count" != "0" ]]; then
    echo "Refusing to update an English marker email owned by another team." >&2
    exit 1
fi

english_sql=$(mktemp "${TMPDIR:-/tmp}/dutypark-demo-english.XXXXXX.sql")
cleanup_file "$english_sql"
response_file=""
identity_cookie=""
cat >"$english_sql" <<SQL
SET SESSION time_zone = '+00:00';
START TRANSACTION;
SET @seed_now = DATE_ADD(UTC_TIMESTAMP(6), INTERVAL 9 HOUR);
INSERT INTO team (
    name, created_date, modified_date, description, admin_id,
    default_duty_name, duty_batch_template, default_duty_color
) VALUES (
    '${EN_TEAM_NAME}', @seed_now, @seed_now, 'Local-only English sample data for screenshots', NULL,
    'Off', NULL, '#20B8B0'
)
ON DUPLICATE KEY UPDATE
    id = LAST_INSERT_ID(id),
    description = VALUES(description),
    modified_date = @seed_now,
    default_duty_name = VALUES(default_duty_name),
    default_duty_color = VALUES(default_duty_color);
SET @seed_team_id = (SELECT id FROM team WHERE name = '${EN_TEAM_NAME}' LIMIT 1);
INSERT INTO member (name, password, team_id, email, calendar_visibility, created_date, modified_date, status)
SELECT seed.name, '${DEMO_BCRYPT_HASH}', @seed_team_id, seed.email, 'FRIENDS', @seed_now, @seed_now, 'ACTIVE'
FROM (
    SELECT 'Emma Moon' AS name, 'demo.en.emma@dutypark.local' AS email
    UNION ALL SELECT 'Jamie Bear', 'demo.en.jamie@dutypark.local'
    UNION ALL SELECT 'Noah Owl', 'demo.en.noah@dutypark.local'
    UNION ALL SELECT 'Chloe Sunny', 'demo.en.chloe@dutypark.local'
    UNION ALL SELECT 'Liam Fox', 'demo.en.liam@dutypark.local'
    UNION ALL SELECT 'Sophia Cat', 'demo.en.sophia@dutypark.local'
    UNION ALL SELECT 'Ethan Otter', 'demo.en.ethan@dutypark.local'
    UNION ALL SELECT 'Ava Panda', 'demo.en.ava@dutypark.local'
) seed
WHERE NOT EXISTS (SELECT 1 FROM member existing WHERE existing.email = seed.email);
UPDATE member
SET name = CASE email
    WHEN 'demo.en.emma@dutypark.local' THEN 'Emma Moon'
    WHEN 'demo.en.jamie@dutypark.local' THEN 'Jamie Bear'
    WHEN 'demo.en.noah@dutypark.local' THEN 'Noah Owl'
    WHEN 'demo.en.chloe@dutypark.local' THEN 'Chloe Sunny'
    WHEN 'demo.en.liam@dutypark.local' THEN 'Liam Fox'
    WHEN 'demo.en.sophia@dutypark.local' THEN 'Sophia Cat'
    WHEN 'demo.en.ethan@dutypark.local' THEN 'Ethan Otter'
    WHEN 'demo.en.ava@dutypark.local' THEN 'Ava Panda'
END,
    password = '${DEMO_BCRYPT_HASH}', team_id = @seed_team_id,
    calendar_visibility = 'FRIENDS', modified_date = @seed_now,
    status = 'ACTIVE', deletion_requested_at = NULL
WHERE email IN (${en_emails_sql});
SET @seed_owner_id = (SELECT id FROM member WHERE email = '${EN_OWNER_EMAIL}' AND team_id = @seed_team_id ORDER BY id LIMIT 1);
UPDATE team SET admin_id = @seed_owner_id, modified_date = @seed_now WHERE id = @seed_team_id;
INSERT INTO duty_type (name, position, team_id, color, hidden)
SELECT seed.name, seed.position, @seed_team_id, seed.color, 0
FROM (
    SELECT 'Morning' AS name, 0 AS position, '#20B8B0' AS color
    UNION ALL SELECT 'Evening', 1, '#FFC857'
    UNION ALL SELECT 'Night', 2, '#5865F2'
    UNION ALL SELECT 'Off', 3, '#CBD5E1'
) seed
WHERE NOT EXISTS (SELECT 1 FROM duty_type existing WHERE existing.team_id = @seed_team_id AND existing.name = seed.name);
UPDATE duty_type SET position = 0, color = '#20B8B0', hidden = 0 WHERE team_id = @seed_team_id AND name = 'Morning';
UPDATE duty_type SET position = 1, color = '#FFC857', hidden = 0 WHERE team_id = @seed_team_id AND name = 'Evening';
UPDATE duty_type SET position = 2, color = '#5865F2', hidden = 0 WHERE team_id = @seed_team_id AND name = 'Night';
UPDATE duty_type SET position = 3, color = '#CBD5E1', hidden = 0 WHERE team_id = @seed_team_id AND name = 'Off';
COMMIT;
SQL
run_mysql <"$english_sql" >/dev/null

KO_TEAM_ID=$(run_sql "SELECT id FROM team WHERE name = '${KO_TEAM_NAME}' LIMIT 1;")
EN_TEAM_ID=$(run_sql "SELECT id FROM team WHERE name = '${EN_TEAM_NAME}' LIMIT 1;")
if [[ -z "$KO_TEAM_ID" || -z "$EN_TEAM_ID" ]]; then
    echo "Marker teams were not created." >&2
    exit 1
fi

KO_IDS=()
KO_EMAILS=()
KO_NAMES=()
KO_AVATARS=()
for spec in "${KO_MEMBERS[@]}"; do
    IFS='|' read -r name email avatar <<<"$spec"
    id=$(run_sql "SELECT id FROM member WHERE email = '${email}' AND team_id = ${KO_TEAM_ID} LIMIT 1;")
    [[ -n "$id" ]] || { echo "Missing Korean marker member: ${email}" >&2; exit 1; }
    KO_IDS+=("$id"); KO_EMAILS+=("$email"); KO_NAMES+=("$name"); KO_AVATARS+=("$avatar")
done
EN_IDS=()
EN_EMAILS=()
EN_NAMES=()
EN_AVATARS=()
for spec in "${EN_MEMBERS[@]}"; do
    IFS='|' read -r name email avatar <<<"$spec"
    id=$(run_sql "SELECT id FROM member WHERE email = '${email}' AND team_id = ${EN_TEAM_ID} LIMIT 1;")
    [[ -n "$id" ]] || { echo "Missing English marker member: ${email}" >&2; exit 1; }
    EN_IDS+=("$id"); EN_EMAILS+=("$email"); EN_NAMES+=("$name"); EN_AVATARS+=("$avatar")
done

response_file=$(mktemp "${TMPDIR:-/tmp}/dutypark-demo-api.XXXXXX")
cleanup_file "$response_file"
LAST_BODY=""
api_call() {
    local method="$1" path="$2" cookie="$3" body="${4:-}"
    local status
    if [[ -n "$body" ]]; then
        status=$(curl -sS -o "$response_file" -w '%{http_code}' -b "$cookie" -c "$cookie" \
            -X "$method" -H 'Content-Type: application/json' --data "$body" \
            "${API_BASE_URL}${path}")
    else
        status=$(curl -sS -o "$response_file" -w '%{http_code}' -b "$cookie" -c "$cookie" \
            -X "$method" "${API_BASE_URL}${path}")
    fi
    LAST_BODY=$(<"$response_file")
    case "$status" in
        2??) ;;
        *)
            echo "API ${method} ${path} failed with HTTP ${status}: ${LAST_BODY}" >&2
            exit 1
            ;;
    esac
}

login() {
    local email="$1" cookie="$2"
    local body
    body=$(jq -nc --arg email "$email" --arg password "$DEMO_PASSWORD" '{email: $email, password: $password}')
    api_call POST /api/auth/token "$cookie" "$body"
    jq -e '.expiresIn > 0' >/dev/null <<<"$LAST_BODY" || {
        echo "Login did not return a token for ${email}." >&2
        exit 1
    }
}

assert_api_identity() {
    local email="$1" expected_id="$2" expected_name="$3" expected_team_id="$4" expected_team_name="$5" cookie="$6"
    login "$email" "$cookie"
    api_call GET /api/members/me "$cookie"
    if ! jq -e --arg email "$email" --arg name "$expected_name" --arg team "$expected_team_name" \
        --argjson id "$expected_id" --argjson teamId "$expected_team_id" \
        '.id == $id and .email == $email and .name == $name and .teamId == $teamId and .team == $team' \
        >/dev/null <<<"$LAST_BODY"; then
        echo "Refusing API writes: ${API_BASE_URL} is not serving the expected local identity for ${email}." >&2
        echo "Expected member=${expected_id}/${expected_name}, team=${expected_team_id}/${expected_team_name}; received: ${LAST_BODY}" >&2
        exit 1
    fi
}

upload_avatar() {
    local email="$1" avatar="$2" cookie="$3" status
    login "$email" "$cookie"
    status=$(curl -sS -o "$response_file" -w '%{http_code}' -b "$cookie" -c "$cookie" \
        -X PUT -F "file=@${AVATAR_DIR}/${avatar};type=image/png" \
        "${API_BASE_URL}/api/members/profile-photo")
    LAST_BODY=$(<"$response_file")
    case "$status" in
        2??) ;;
        *) echo "Avatar upload failed for ${email} (HTTP ${status}): ${LAST_BODY}" >&2; exit 1 ;;
    esac
}

json_number_array() {
    local output='[' id first=1
    for id in "$@"; do
        if (( first )); then first=0; else output+=','; fi
        output+="$id"
    done
    output+=']'
    printf '%s' "$output"
}

create_schedule() {
    local member_id="$1" cookie="$2" content="$3" description="$4" start="$5" end="$6" visibility="$7"
    local body
    body=$(jq -nc --argjson memberId "$member_id" --arg content "$content" --arg description "$description" \
        --arg startDateTime "$start" --arg endDateTime "$end" --arg visibility "$visibility" \
        '{memberId: $memberId, content: $content, description: $description, visibility: $visibility, startDateTime: $startDateTime, endDateTime: $endDateTime, aiTimeParsingRequested: false}')
    api_call POST /api/schedules "$cookie" "$body"
    jq -r '.id' <<<"$LAST_BODY"
}

create_todo() {
    local cookie="$1" title="$2" content="$3" status_value="$4" due_date="$5" body
    body=$(jq -nc --arg title "$title" --arg content "$content" --arg status "$status_value" --arg dueDate "$due_date" \
        '{title: $title, content: $content, status: $status, dueDate: $dueDate}')
    api_call POST /api/todos "$cookie" "$body"
    jq -r '.id' <<<"$LAST_BODY"
}

create_dday_if_missing() {
    local member_id="$1" cookie="$2" title="$3" date="$4" is_private="$5" count body
    count=$(run_sql "SELECT COUNT(*) FROM d_day_event WHERE member_id = ${member_id} AND title = '$(sql_quote "$title")' AND date = '${date}';")
    if [[ "$count" == "0" ]]; then
        body=$(jq -nc --arg title "$title" --arg date "$date" --argjson isPrivate "$is_private" \
            '{title: $title, date: $date, isPrivate: $isPrivate}')
        api_call POST /api/dday "$cookie" "$body" >/dev/null
    fi
}

create_team_schedule_if_missing() {
    local team_id="$1" member_id="$2" cookie="$3" content="$4" description="$5" start="$6" end="$7" count body
    count=$(run_sql "SELECT COUNT(*) FROM team_schedule WHERE team_id = ${team_id} AND content = '$(sql_quote "$content")' AND start_date_time = '${start}' AND end_date_time = '${end}';")
    if [[ "$count" == "0" ]]; then
        body=$(jq -nc --argjson teamId "$team_id" --arg content "$content" --arg description "$description" \
            --arg startDateTime "$start" --arg endDateTime "$end" \
            '{teamId: $teamId, content: $content, description: $description, startDateTime: $startDateTime, endDateTime: $endDateTime}')
        api_call POST /api/teams/schedules "$cookie" "$body" >/dev/null
    fi
}

ensure_friend_pair() {
    local owner_id="$1" friend_id="$2" owner_email="$3" friend_email="$4" owner_cookie="$5" friend_cookie="$6"
    local relation_count pending_from pending_to body
    relation_count=$(run_sql "SELECT COUNT(*) FROM friends WHERE (member_id = ${owner_id} AND friend_id = ${friend_id}) OR (member_id = ${friend_id} AND friend_id = ${owner_id});")
    if [[ "$relation_count" == "2" ]]; then
        return
    fi
    if [[ "$relation_count" != "0" ]]; then
        echo "Refusing to repair a partial marker friendship ${owner_id}<->${friend_id}." >&2
        exit 1
    fi
    pending_from=$(run_sql "SELECT COUNT(*) FROM friend_requests WHERE from_member_id = ${owner_id} AND to_member_id = ${friend_id} AND status = 'PENDING';")
    pending_to=$(run_sql "SELECT COUNT(*) FROM friend_requests WHERE from_member_id = ${friend_id} AND to_member_id = ${owner_id} AND status = 'PENDING';")
    if [[ "$pending_from" == "0" && "$pending_to" == "0" ]]; then
        login "$owner_email" "$owner_cookie"
        api_call POST "/api/friends/request/send/${friend_id}" "$owner_cookie"
    fi
    if [[ "$pending_from" != "0" || "$pending_to" == "0" ]]; then
        login "$friend_email" "$friend_cookie"
        api_call POST "/api/friends/request/accept/${owner_id}" "$friend_cookie"
    else
        login "$owner_email" "$owner_cookie"
        api_call POST "/api/friends/request/accept/${friend_id}" "$owner_cookie"
    fi
    relation_count=$(run_sql "SELECT COUNT(*) FROM friends WHERE (member_id = ${owner_id} AND friend_id = ${friend_id}) OR (member_id = ${friend_id} AND friend_id = ${owner_id});")
    [[ "$relation_count" == "2" ]] || { echo "Friend relationship was not created for ${owner_email} and ${friend_email}." >&2; exit 1; }
}

ensure_pins() {
    local owner_email="$1" owner_cookie="$2" owner_id="$3"; shift 3
    local id friend_json pinned order_json
    login "$owner_email" "$owner_cookie"
    api_call GET /api/friends "$owner_cookie"
    friend_json="$LAST_BODY"
    for id in "$@"; do
        pinned=$(jq -r --argjson id "$id" '[.[] | select(.id == $id) | (.pinOrder // 0)] | first // 0' <<<"$friend_json")
        if [[ "$pinned" == "0" || "$pinned" == "null" ]]; then
            api_call PATCH "/api/friends/pin/${id}" "$owner_cookie"
        fi
    done
    order_json=$(json_number_array "$@")
    api_call PATCH /api/friends/pin/order "$owner_cookie" "$order_json"
}

ensure_schedule_tag() {
    local schedule_id="$1" owner_cookie="$2" friend_id="$3" count
    count=$(run_sql "SELECT COUNT(*) FROM schedule_tags WHERE schedule_id = '${schedule_id}' AND member_id = ${friend_id};")
    if [[ "$count" == "0" ]]; then
        api_call POST "/api/schedules/${schedule_id}/tags/${friend_id}" "$owner_cookie"
    fi
}

ensure_todo_tag() {
    local todo_id="$1" owner_cookie="$2" friend_id="$3" count
    count=$(run_sql "SELECT COUNT(*) FROM todo_tags WHERE todo_id = '${todo_id}' AND member_id = ${friend_id};")
    if [[ "$count" == "0" ]]; then
        api_call POST "/api/todos/${todo_id}/tags/${friend_id}" "$owner_cookie"
    fi
}

wait_for_notifications() {
    local team_id="$1" owner_id="$2" locale="$3"
    local deadline now accepted received schedule_tagged todo_tagged
    deadline=$(( $(date +%s) + 20 ))
    while true; do
        accepted=$(run_sql "SELECT COUNT(*) FROM notifications WHERE member_id = ${owner_id} AND type = 'FRIEND_REQUEST_ACCEPTED';")
        received=$(run_sql "SELECT COUNT(*) FROM notifications n JOIN member m ON m.id = n.member_id WHERE m.team_id = ${team_id} AND n.type = 'FRIEND_REQUEST_RECEIVED';")
        schedule_tagged=$(run_sql "SELECT COUNT(*) FROM notifications n JOIN member m ON m.id = n.member_id WHERE m.team_id = ${team_id} AND n.type = 'SCHEDULE_TAGGED';")
        todo_tagged=$(run_sql "SELECT COUNT(*) FROM notifications n JOIN member m ON m.id = n.member_id WHERE m.team_id = ${team_id} AND n.type = 'TODO_TAGGED';")
        if [[ "$accepted" -ge 7 && "$received" -ge 7 && "$schedule_tagged" -ge 7 && "$todo_tagged" -ge 1 ]]; then
            return
        fi
        now=$(date +%s)
        if [[ "$now" -ge "$deadline" ]]; then
            echo "Timed out waiting for ${locale} demo AFTER_COMMIT notifications (accepted=${accepted}, received=${received}, scheduleTagged=${schedule_tagged}, todoTagged=${todo_tagged})." >&2
            exit 1
        fi
        sleep 1
    done
}

populate_locale() {
    local locale="$1" team_id="$2" owner_email="$3"; shift 3
    local ids_name="$1" emails_name="$2" names_name="$3" avatars_name="$4"
    local -a ids emails names avatars
    eval "ids=(\"\${${ids_name}[@]}\")"
    eval "emails=(\"\${${emails_name}[@]}\")"
    eval "names=(\"\${${names_name}[@]}\")"
    eval "avatars=(\"\${${avatars_name}[@]}\")"
    local -a dates
    if [[ "$locale" == "ko" ]]; then dates=("${KO_DATES[@]}"); else dates=("${EN_DATES[@]}"); fi
    local owner_id="${ids[0]}" owner_cookie friend_cookie
    owner_cookie=$(mktemp "${TMPDIR:-/tmp}/dutypark-demo-owner.XXXXXX")
    cleanup_file "$owner_cookie"
    friend_cookie=$(mktemp "${TMPDIR:-/tmp}/dutypark-demo-friend.XXXXXX")
    cleanup_file "$friend_cookie"

    local index email avatar id schedule_id todo_id day
    for index in "${!ids[@]}"; do
        email="${emails[index]}"; avatar="${avatars[index]}"; id="${ids[index]}"
        upload_avatar "$email" "$avatar" "$friend_cookie"
        login "$email" "$friend_cookie"
        if [[ "$locale" == "ko" ]]; then
            schedule_id=$(create_schedule "$id" "$friend_cookie" '오늘의 집중 시간' '하루의 중요한 흐름을 가볍게 정리해요.' '2026-08-26T09:00:00' '2026-08-26T10:00:00' 'FRIENDS')
            create_schedule "$id" "$friend_cookie" '점심 산책과 리프레시' '잠시 화면을 내려놓고 산책해요.' '2026-08-26T12:30:00' '2026-08-26T13:15:00' 'FRIENDS' >/dev/null
            create_schedule "$id" "$friend_cookie" '저녁 약속 준비' '오늘의 약속을 차분히 준비해요.' '2026-08-26T18:30:00' '2026-08-26T19:30:00' 'PUBLIC' >/dev/null
            create_schedule "$id" "$friend_cookie" '내일을 위한 메모' '내일 해야 할 일을 미리 적어두어요.' '2026-08-27T09:30:00' '2026-08-27T10:00:00' 'FRIENDS' >/dev/null
            create_schedule "$id" "$friend_cookie" '친구와 함께하는 시간' '서로의 일정을 확인하고 약속을 맞춰요.' '2026-08-28T14:00:00' '2026-08-28T15:00:00' 'FRIENDS' >/dev/null
            create_schedule "$id" "$friend_cookie" '주말 루틴 점검' '이번 주를 돌아보고 다음 주를 준비해요.' '2026-08-29T11:00:00' '2026-08-29T11:45:00' 'PUBLIC' >/dev/null
            create_schedule "$id" "$friend_cookie" '마음 챙김 시간' '조금 느리게 쉬어가는 시간이에요.' '2026-08-30T16:00:00' '2026-08-30T17:00:00' 'FRIENDS' >/dev/null
            create_schedule "$id" "$friend_cookie" '월말 계획 정리' '새로운 한 주의 계획을 정리해요.' '2026-08-31T20:00:00' '2026-08-31T21:00:00' 'FRIENDS' >/dev/null
            create_todo "$friend_cookie" '이번 주 우선순위 정리' '가장 중요한 일 세 가지를 골라요.' 'TODO' '2026-08-28' >/dev/null
            todo_id=$(create_todo "$friend_cookie" '진행 중인 일정 확인' '친구들과 공유한 약속을 확인해요.' 'IN_PROGRESS' '2026-08-29')
            create_todo "$friend_cookie" '완료한 일 돌아보기' '이번 주에 해낸 일을 기록해요.' 'DONE' '2026-08-25' >/dev/null
            create_todo "$friend_cookie" '다음 주 준비하기' '새로운 주를 가볍게 시작할 준비를 해요.' 'TODO' '2026-08-31' >/dev/null
            create_dday_if_missing "$id" "$friend_cookie" '가을 휴가 시작' '2026-09-14' false
            create_dday_if_missing "$id" "$friend_cookie" '새로운 계절을 맞이하는 날' '2026-09-01' false
        else
            schedule_id=$(create_schedule "$id" "$friend_cookie" 'Morning focus block' 'Plan the most important part of the day.' '2026-08-26T09:00:00' '2026-08-26T10:00:00' 'FRIENDS')
            create_schedule "$id" "$friend_cookie" 'Lunch walk and reset' 'A short walk to reset before the afternoon.' '2026-08-26T12:30:00' '2026-08-26T13:15:00' 'FRIENDS' >/dev/null
            create_schedule "$id" "$friend_cookie" 'Evening plans' 'Leave room for a calm evening.' '2026-08-26T18:30:00' '2026-08-26T19:30:00' 'PUBLIC' >/dev/null
            create_schedule "$id" "$friend_cookie" 'Plan tomorrow' 'Write down the next small step.' '2026-08-27T09:30:00' '2026-08-27T10:00:00' 'FRIENDS' >/dev/null
            create_schedule "$id" "$friend_cookie" 'Shared coffee break' 'Make space for a friendly check-in.' '2026-08-28T14:00:00' '2026-08-28T15:00:00' 'FRIENDS' >/dev/null
            create_schedule "$id" "$friend_cookie" 'Weekend reset' 'Review the week and prepare for the next one.' '2026-08-29T11:00:00' '2026-08-29T11:45:00' 'PUBLIC' >/dev/null
            create_schedule "$id" "$friend_cookie" 'Mindful pause' 'A quiet hour to recharge.' '2026-08-30T16:00:00' '2026-08-30T17:00:00' 'FRIENDS' >/dev/null
            create_schedule "$id" "$friend_cookie" 'Month-end planning' 'Close the month with a clear plan.' '2026-08-31T20:00:00' '2026-08-31T21:00:00' 'FRIENDS' >/dev/null
            create_schedule "$id" "$friend_cookie" 'November focus sprint' 'A focused block for the November plan.' '2026-11-03T09:00:00' '2026-11-03T10:00:00' 'FRIENDS' >/dev/null
            create_schedule "$id" "$friend_cookie" 'November team sync' 'Align on the next milestone.' '2026-11-05T14:00:00' '2026-11-05T15:00:00' 'PUBLIC' >/dev/null
            create_schedule "$id" "$friend_cookie" 'Creative studio hour' 'Make steady progress on a creative idea.' '2026-11-08T16:00:00' '2026-11-08T17:00:00' 'FRIENDS' >/dev/null
            create_schedule "$id" "$friend_cookie" 'Mid-month check-in' 'Review what is working and adjust.' '2026-11-12T10:00:00' '2026-11-12T10:30:00' 'FRIENDS' >/dev/null
            create_schedule "$id" "$friend_cookie" 'Friends dinner' 'A warm evening to reconnect.' '2026-11-15T18:00:00' '2026-11-15T20:00:00' 'PUBLIC' >/dev/null
            create_schedule "$id" "$friend_cookie" 'Learning hour' 'Set aside time to learn something useful.' '2026-11-18T19:00:00' '2026-11-18T20:00:00' 'FRIENDS' >/dev/null
            create_schedule "$id" "$friend_cookie" 'November walk' 'Take a breath and enjoy the season.' '2026-11-21T11:00:00' '2026-11-21T12:00:00' 'PUBLIC' >/dev/null
            create_schedule "$id" "$friend_cookie" 'Month-end reflection' 'Capture the highlights before December.' '2026-11-25T20:00:00' '2026-11-25T21:00:00' 'FRIENDS' >/dev/null
            create_todo "$friend_cookie" 'Plan this week' 'Choose the three tasks that matter most.' 'TODO' '2026-08-28' >/dev/null
            todo_id=$(create_todo "$friend_cookie" 'Review shared plans' 'Check the plans shared with friends.' 'IN_PROGRESS' '2026-08-29')
            create_todo "$friend_cookie" 'Celebrate completed work' 'Write down what went well this week.' 'DONE' '2026-08-25' >/dev/null
            create_todo "$friend_cookie" 'Prepare next week' 'Start the next week with a light plan.' 'TODO' '2026-08-31' >/dev/null
            create_dday_if_missing "$id" "$friend_cookie" 'Autumn getaway' '2026-09-14' false
            create_dday_if_missing "$id" "$friend_cookie" 'New season begins' '2026-09-01' false
        fi
        if [[ "$id" == "$owner_id" ]]; then
            owner_primary_schedule_id="$schedule_id"
            owner_primary_todo_id="$todo_id"
        fi
    done

    local friend_index friend_id friend_email
    for friend_index in 1 2 3 4 5 6 7; do
        friend_id="${ids[friend_index]}"; friend_email="${emails[friend_index]}"
        ensure_friend_pair "$owner_id" "$friend_id" "$owner_email" "$friend_email" "$owner_cookie" "$friend_cookie"
    done
    ensure_pins "$owner_email" "$owner_cookie" "$owner_id" "${ids[@]:1}"
    for friend_index in 1 2 3 4 5 6 7; do
        ensure_schedule_tag "$owner_primary_schedule_id" "$owner_cookie" "${ids[friend_index]}"
    done
    ensure_todo_tag "$owner_primary_todo_id" "$owner_cookie" "${ids[1]}"
    wait_for_notifications "$team_id" "$owner_id" "$locale"

    login "$owner_email" "$owner_cookie"
    if [[ "$locale" == "ko" ]]; then
        create_team_schedule_if_missing "$team_id" "$owner_id" "$owner_cookie" '데모팀 전체 회의' '모두가 함께 확인하는 주간 회의예요.' '2026-08-26T15:00:00' '2026-08-26T16:00:00'
        create_team_schedule_if_missing "$team_id" "$owner_id" "$owner_cookie" '팀 점심 시간' '함께 쉬며 다음 계획을 이야기해요.' '2026-08-27T12:00:00' '2026-08-27T13:00:00'
        create_team_schedule_if_missing "$team_id" "$owner_id" "$owner_cookie" '월말 회고' '이번 달의 배움과 다음 목표를 나눠요.' '2026-08-31T17:00:00' '2026-08-31T18:00:00'
        create_team_schedule_if_missing "$team_id" "$owner_id" "$owner_cookie" '다음 달 준비' '새로운 달의 일정을 함께 준비해요.' '2026-09-01T10:00:00' '2026-09-01T11:00:00'
    else
        create_team_schedule_if_missing "$team_id" "$owner_id" "$owner_cookie" 'Demo team all-hands' 'A weekly sync for everyone on the team.' '2026-08-26T15:00:00' '2026-08-26T16:00:00'
        create_team_schedule_if_missing "$team_id" "$owner_id" "$owner_cookie" 'Team lunch break' 'A shared pause to talk through the next plan.' '2026-08-27T12:00:00' '2026-08-27T13:00:00'
        create_team_schedule_if_missing "$team_id" "$owner_id" "$owner_cookie" 'Month-end retro' 'Share the lessons and goals for next month.' '2026-08-31T17:00:00' '2026-08-31T18:00:00'
        create_team_schedule_if_missing "$team_id" "$owner_id" "$owner_cookie" 'November kickoff' 'Start the next month with a clear shared plan.' '2026-11-01T10:00:00' '2026-11-01T11:00:00'
    fi

    rm -f "$owner_cookie" "$friend_cookie"
}

insert_duties() {
    local locale="$1" team_id="$2"; shift 2
    local ids_name="$1"
    local -a ids dates type_ids
    eval "ids=(\"\${${ids_name}[@]}\")"
    if [[ "$locale" == "ko" ]]; then
        dates=("${KO_DATES[@]}")
        type_ids=(
            "$(run_sql "SELECT id FROM duty_type WHERE team_id = ${team_id} AND name = '오전' LIMIT 1;")"
            "$(run_sql "SELECT id FROM duty_type WHERE team_id = ${team_id} AND name = '오후' LIMIT 1;")"
            "$(run_sql "SELECT id FROM duty_type WHERE team_id = ${team_id} AND name = '야간' LIMIT 1;")"
        )
    else
        dates=("${EN_DATES[@]}")
        type_ids=(
            "$(run_sql "SELECT id FROM duty_type WHERE team_id = ${team_id} AND name = 'Morning' LIMIT 1;")"
            "$(run_sql "SELECT id FROM duty_type WHERE team_id = ${team_id} AND name = 'Evening' LIMIT 1;")"
            "$(run_sql "SELECT id FROM duty_type WHERE team_id = ${team_id} AND name = 'Night' LIMIT 1;")"
            "$(run_sql "SELECT id FROM duty_type WHERE team_id = ${team_id} AND name = 'Off' LIMIT 1;")"
        )
    fi
    for type_id in "${type_ids[@]}"; do [[ -n "$type_id" ]] || { echo "Missing ${locale} duty type." >&2; exit 1; }; done
    local duties_sql=$(mktemp "${TMPDIR:-/tmp}/dutypark-demo-duties.XXXXXX.sql")
    cleanup_file "$duties_sql"
    local member_index date_index date type_id
    {
        echo "SET SESSION time_zone = '+00:00';"
        echo "START TRANSACTION;"
        for member_index in "${!ids[@]}"; do
            for date_index in "${!dates[@]}"; do
                date="${dates[date_index]}"
                type_id="${type_ids[$((date_index % ${#type_ids[@]}))]}"
                echo "INSERT INTO duty (duty_type_id, member_id, duty_date, team_id, manual_override) SELECT ${type_id}, ${ids[member_index]}, '${date}', ${team_id}, 0 WHERE NOT EXISTS (SELECT 1 FROM duty WHERE member_id = ${ids[member_index]} AND duty_date = '${date}');"
            done
        done
        echo "COMMIT;"
    } >"$duties_sql"
    run_mysql <"$duties_sql" >/dev/null
    rm -f "$duties_sql"
}

identity_cookie=$(mktemp "${TMPDIR:-/tmp}/dutypark-demo-identity.XXXXXX")
cleanup_file "$identity_cookie"
assert_api_identity "$KO_OWNER_EMAIL" "${KO_IDS[0]}" "${KO_NAMES[0]}" "$KO_TEAM_ID" "$KO_TEAM_NAME" "$identity_cookie"
assert_api_identity "$EN_OWNER_EMAIL" "${EN_IDS[0]}" "${EN_NAMES[0]}" "$EN_TEAM_ID" "$EN_TEAM_NAME" "$identity_cookie"
rm -f "$identity_cookie"

# Reconcile only the two verified marker teams. A previous capture run or an
# older fixture revision must not accumulate alongside the current deterministic
# dataset. This happens only after the running API has proved that it serves the
# exact local member/team identities read from dutypark_demo.
marker_member_ids=""
for marker_id in "${KO_IDS[@]}" "${EN_IDS[@]}"; do
    [[ -z "$marker_member_ids" ]] || marker_member_ids+=","
    marker_member_ids+="$marker_id"
done
run_sql "
START TRANSACTION;
DELETE FROM schedule_tags WHERE schedule_id IN (SELECT id FROM schedule WHERE member_id IN (${marker_member_ids}));
DELETE FROM todo_tags WHERE todo_id IN (SELECT id FROM todo WHERE member_id IN (${marker_member_ids}));
DELETE FROM notifications WHERE member_id IN (${marker_member_ids});
DELETE FROM friend_requests WHERE from_member_id IN (${marker_member_ids}) OR to_member_id IN (${marker_member_ids});
DELETE FROM friends WHERE member_id IN (${marker_member_ids}) OR friend_id IN (${marker_member_ids});
DELETE FROM schedule WHERE member_id IN (${marker_member_ids});
DELETE FROM todo WHERE member_id IN (${marker_member_ids});
DELETE FROM d_day_event WHERE member_id IN (${marker_member_ids});
DELETE FROM team_schedule WHERE team_id IN (${KO_TEAM_ID}, ${EN_TEAM_ID});
DELETE FROM duty WHERE member_id IN (${marker_member_ids}) OR team_id IN (${KO_TEAM_ID}, ${EN_TEAM_ID});
COMMIT;
"

populate_locale ko "$KO_TEAM_ID" "$KO_OWNER_EMAIL" KO_IDS KO_EMAILS KO_NAMES KO_AVATARS
insert_duties ko "$KO_TEAM_ID" KO_IDS
populate_locale en "$EN_TEAM_ID" "$EN_OWNER_EMAIL" EN_IDS EN_EMAILS EN_NAMES EN_AVATARS
insert_duties en "$EN_TEAM_ID" EN_IDS

# A small API smoke check makes a successful SQL-only partial run impossible to
# mistake for a complete fixture. It also leaves a machine-readable summary.
summary_cookie=$(mktemp "${TMPDIR:-/tmp}/dutypark-demo-summary.XXXXXX")
cleanup_file "$summary_cookie"
login "$KO_OWNER_EMAIL" "$summary_cookie"
api_call GET /api/members/me "$summary_cookie"
ko_profile=$(jq -r '.hasProfilePhoto' <<<"$LAST_BODY")
api_call GET /api/friends "$summary_cookie"
ko_friend_count=$(jq 'length' <<<"$LAST_BODY")
api_call GET /api/todos/board "$summary_cookie"
ko_todo_count=$(jq '[.todo, .inProgress, .done, .completed, .TODO, .IN_PROGRESS, .DONE] | map(select(type == "array") | length) | add // 0' <<<"$LAST_BODY")
[[ "$ko_profile" == "true" && "$ko_friend_count" == "7" ]] || { echo "Korean demo API smoke check failed." >&2; exit 1; }
login "$EN_OWNER_EMAIL" "$summary_cookie"
api_call GET /api/members/me "$summary_cookie"
en_profile=$(jq -r '.hasProfilePhoto' <<<"$LAST_BODY")
api_call GET /api/friends "$summary_cookie"
en_friend_count=$(jq 'length' <<<"$LAST_BODY")
[[ "$en_profile" == "true" && "$en_friend_count" == "7" ]] || { echo "English demo API smoke check failed." >&2; exit 1; }
rm -f "$summary_cookie"

ko_schedule_count=$(run_sql "SELECT COUNT(*) FROM schedule WHERE member_id IN (SELECT id FROM member WHERE team_id = ${KO_TEAM_ID});")
en_schedule_count=$(run_sql "SELECT COUNT(*) FROM schedule WHERE member_id IN (SELECT id FROM member WHERE team_id = ${EN_TEAM_ID});")
ko_todo_count_db=$(run_sql "SELECT COUNT(*) FROM todo WHERE member_id IN (SELECT id FROM member WHERE team_id = ${KO_TEAM_ID});")
en_todo_count_db=$(run_sql "SELECT COUNT(*) FROM todo WHERE member_id IN (SELECT id FROM member WHERE team_id = ${EN_TEAM_ID});")
ko_duty_count=$(run_sql "SELECT COUNT(*) FROM duty WHERE team_id = ${KO_TEAM_ID} AND duty_date BETWEEN '2026-08-24' AND '2026-08-31';")
en_duty_count=$(run_sql "SELECT COUNT(*) FROM duty WHERE team_id = ${EN_TEAM_ID} AND (duty_date BETWEEN '2026-08-24' AND '2026-08-31' OR duty_date BETWEEN '2026-11-01' AND '2026-11-30');")

jq -n \
    --arg database "${DB_HOST}:${DB_PORT}/${DB_NAME}" \
    --arg api "$API_BASE_URL" \
    --arg captureDate "$CAPTURE_DATE" \
    --arg englishMonth "$ENGLISH_CALENDAR_MONTH" \
    --argjson koreanTeamId "$KO_TEAM_ID" \
    --argjson englishTeamId "$EN_TEAM_ID" \
    --argjson koreanAccounts "${#KO_IDS[@]}" \
    --argjson englishAccounts "${#EN_IDS[@]}" \
    --argjson koreanSchedules "$ko_schedule_count" \
    --argjson englishSchedules "$en_schedule_count" \
    --argjson koreanTodos "$ko_todo_count_db" \
    --argjson englishTodos "$en_todo_count_db" \
    --argjson koreanDuties "$ko_duty_count" \
    --argjson englishDuties "$en_duty_count" \
    '{database: $database, api: $api, captureDate: $captureDate, englishCalendarMonth: $englishMonth, teams: {korean: {id: $koreanTeamId, accounts: $koreanAccounts, schedules: $koreanSchedules, todos: $koreanTodos, duties: $koreanDuties}, english: {id: $englishTeamId, accounts: $englishAccounts, schedules: $englishSchedules, todos: $englishTodos, duties: $englishDuties}}, credentials: {password: "demo1234!", localOnly: true}}'
