#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
module_cache="${CLANG_MODULE_CACHE_PATH:-${TMPDIR:-/tmp}/dutypark-swift-module-cache}"
mkdir -p "$module_cache"
export CLANG_MODULE_CACHE_PATH="$module_cache"

exec swift "$script_dir/test_compose_app_store_screenshots.swift"
