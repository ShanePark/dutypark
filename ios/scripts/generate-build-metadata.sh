#!/bin/sh

set -eu

info_plist="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
if [ ! -f "$info_plist" ]; then
    echo "error: Built Info.plist was not found at ${info_plist}" >&2
    exit 1
fi

repository_root="${SRCROOT}/.."
build_date=$(TZ=Asia/Seoul /bin/date '+%Y-%m-%d %H:%M:%S KST')
commit_hash="unknown"
source_state="unknown"

if commit_hash=$(git -C "$repository_root" rev-parse --short=7 HEAD 2>/dev/null); then
    if git -C "$repository_root" diff --quiet HEAD --; then
        source_state="clean"
    else
        source_state="modified"
    fi
fi

set_plist_value() {
    key="$1"
    value="$2"
    /usr/bin/plutil -remove "$key" "$info_plist" >/dev/null 2>&1 || true
    /usr/bin/plutil -insert "$key" -string "$value" "$info_plist"
}

set_plist_value "DutyparkBuildDate" "$build_date"
set_plist_value "DutyparkGitCommit" "$commit_hash"
set_plist_value "DutyparkSourceState" "$source_state"

echo "Generated build metadata for the application bundle."
