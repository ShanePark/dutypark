#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

PROJECT_PATH="$IOS_DIR/Dutypark.xcodeproj"
PROJECT_FILE_PATH="$PROJECT_PATH/project.pbxproj"
SCHEME="Dutypark"
TEAM_ID="2V47G42CDS"
EXPORT_OPTIONS_PATH="$IOS_DIR/ExportOptions-TestFlight.plist"

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

print_command() {
	printf '+'
	printf ' %q' "$@"
	printf '\n'
}

run() {
	print_command "$@"
	if [[ "${DRY_RUN:-0}" == "1" ]]; then
		return 0
	fi
	"$@"
}

command -v xcodebuild >/dev/null 2>&1 || die "xcodebuild is required. Run this script on macOS with Xcode installed."
[[ -d "$PROJECT_PATH" ]] || die "Xcode project not found: $PROJECT_PATH"
[[ -f "$PROJECT_FILE_PATH" ]] || die "Xcode project file not found: $PROJECT_FILE_PATH"
[[ -f "$EXPORT_OPTIONS_PATH" ]] || die "Export options not found: $EXPORT_OPTIONS_PATH"

if [[ -n "${MARKETING_VERSION:-}" ]]; then
	marketing_version="$MARKETING_VERSION"
else
	marketing_version="$(awk -F ' = |;' '
		$1 ~ /^[[:space:]]*MARKETING_VERSION[[:space:]]*$/ {
			print $2
			exit
		}
	' "$PROJECT_FILE_PATH")"
	[[ -n "$marketing_version" ]] || die "Unable to read MARKETING_VERSION from the Xcode project."
fi

[[ "$marketing_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die \
	"MARKETING_VERSION must contain three numeric components: $marketing_version"

if [[ -n "${BUILD_NUMBER:-}" ]]; then
	build_number="$BUILD_NUMBER"
else
	build_number="$(TZ=Asia/Seoul date +%Y%m%d)"
fi

[[ "$build_number" =~ ^[0-9]{1,18}(\.[0-9]{1,18}){0,2}$ ]] || die \
	"BUILD_NUMBER must contain one to three numeric components, each at most 18 digits: $build_number"

build_root="${TESTFLIGHT_BUILD_DIR:-$IOS_DIR/build/testflight}"
run_id="${marketing_version}-${build_number}"
archive_path="${ARCHIVE_PATH:-$build_root/Dutypark-$run_id.xcarchive}"
export_path="${EXPORT_PATH:-$build_root/export-$run_id}"
derived_data_path="${DERIVED_DATA_PATH:-$build_root/DerivedData-$run_id}"

[[ ! -e "$archive_path" ]] || die "Archive already exists: $archive_path (choose another BUILD_NUMBER or ARCHIVE_PATH)."
[[ ! -e "$export_path" ]] || die "Export path already exists: $export_path (choose another BUILD_NUMBER or EXPORT_PATH)."

mkdir -p "$build_root"

printf 'Release version: %s\n' "$marketing_version"
printf 'Build number: %s\n' "$build_number"
printf 'Archive path: %s\n' "$archive_path"
printf 'Xcode account: required (Xcode Settings > Accounts)\n'

run xcodebuild \
	-project "$PROJECT_PATH" \
	-scheme "$SCHEME" \
	-configuration Release \
	-destination 'generic/platform=iOS' \
	-derivedDataPath "$derived_data_path" \
	-archivePath "$archive_path" \
	MARKETING_VERSION="$marketing_version" \
	CURRENT_PROJECT_VERSION="$build_number" \
	DEVELOPMENT_TEAM="$TEAM_ID" \
	CODE_SIGN_STYLE=Automatic \
	-allowProvisioningUpdates \
	archive

run xcodebuild \
	-exportArchive \
	-archivePath "$archive_path" \
	-exportPath "$export_path" \
	-exportOptionsPlist "$EXPORT_OPTIONS_PATH" \
	-allowProvisioningUpdates

if [[ "${DRY_RUN:-0}" == "1" ]]; then
	printf 'Dry run complete; no archive or upload was performed.\n'
else
	printf 'Upload accepted by App Store Connect. Processing continues asynchronously.\n'
	printf 'Archive: %s\n' "$archive_path"
fi
