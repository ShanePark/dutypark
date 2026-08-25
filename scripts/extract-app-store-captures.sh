#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat >&2 <<'USAGE'
Usage: scripts/extract-app-store-captures.sh --result <capture.xcresult> --locale <ko|en> [--output-root <dir>] [--force]

Exports XCTAttachments with names appstore-{locale}-01..07-*-demo and writes
validated 1320x2868, opaque PNGs to <output-root>/{ko,en}/.
USAGE
    exit 2
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
default_output_root="$(cd "$script_dir/.." && pwd)/docs/app-store/raw"
result_path=""
locale=""
output_root="$default_output_root"
force=0

while (($# > 0)); do
    case "$1" in
        --result)
            (($# >= 2)) || usage
            result_path="$2"
            shift 2
            ;;
        --locale)
            (($# >= 2)) || usage
            locale="$2"
            shift 2
            ;;
        --output-root)
            (($# >= 2)) || usage
            output_root="$2"
            shift 2
            ;;
        --force)
            force=1
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            usage
            ;;
    esac
done

[[ -n "$result_path" && -n "$locale" ]] || usage
[[ "$locale" == "ko" || "$locale" == "en" ]] || {
    echo "error: --locale must be ko or en" >&2
    exit 2
}

case "$result_path" in
    /*) ;;
    *) result_path="$PWD/$result_path" ;;
esac
case "$output_root" in
    /*) ;;
    *) output_root="$PWD/$output_root" ;;
esac

[[ -d "$result_path" ]] || {
    echo "error: xcresult bundle not found: $result_path" >&2
    exit 1
}

export_root="$(mktemp -d "${TMPDIR:-/tmp}/dutypark-app-store-export.XXXXXX")"
trap 'rm -rf "$export_root"' EXIT

echo "Exporting attachments from $result_path" >&2
xcrun xcresulttool export attachments \
    --path "$result_path" \
    --output-path "$export_root"

manifest="$export_root/manifest.json"
[[ -f "$manifest" ]] || {
    echo "error: xcresulttool did not produce manifest.json" >&2
    exit 1
}

module_cache="${CLANG_MODULE_CACHE_PATH:-${TMPDIR:-/tmp}/dutypark-swift-module-cache}"
mkdir -p "$module_cache"
export CLANG_MODULE_CACHE_PATH="$module_cache"

swift_args=(
    --manifest "$manifest"
    --export-root "$export_root"
    --output-root "$output_root"
    --locale "$locale"
)
if [[ "$force" -eq 1 ]]; then
    swift_args+=(--force)
fi

swift "$script_dir/extract_app_store_captures.swift" \
    "${swift_args[@]}"
