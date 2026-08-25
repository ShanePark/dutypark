#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/dutypark-app-store-extract-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT

export_root="$work/export"
output_root="$work/raw"
fake_bin="$work/bin"
mkdir -p "$export_root" "$fake_bin"

names=(home calendar todo team more social dday)
suffixes=(01-home 02-calendar 03-todo 04-team 05-more 06-social 07-dday)
manifest="$export_root/manifest.json"

for index in "${!names[@]}"; do
    cp "$repo_root/docs/app-store/raw/ko/${names[$index]}.png" \
        "$export_root/exported-${suffixes[$index]}.png"
done

cat > "$manifest" <<'JSON'
[
  {
    "testIdentifier": "DemoAppStoreCaptureUITests/testCapturesKoreanDemoScreensForAppStore",
    "attachments": [
      {"exportedFileName":"exported-01-home.png","suggestedHumanReadableName":"appstore-ko-01-home-demo_0_11111111-1111-1111-1111-111111111111.png"},
      {"exportedFileName":"exported-02-calendar.png","suggestedHumanReadableName":"appstore-ko-02-calendar-demo_0_22222222-2222-2222-2222-222222222222.png"},
      {"exportedFileName":"exported-03-todo.png","suggestedHumanReadableName":"appstore-ko-03-todo-demo_0_33333333-3333-3333-3333-333333333333.png"},
      {"exportedFileName":"exported-04-team.png","suggestedHumanReadableName":"appstore-ko-04-team-demo_0_44444444-4444-4444-4444-444444444444.png"},
      {"exportedFileName":"exported-05-more.png","suggestedHumanReadableName":"appstore-ko-05-more-demo_0_55555555-5555-5555-5555-555555555555.png"},
      {"exportedFileName":"exported-06-social.png","suggestedHumanReadableName":"appstore-ko-06-social-demo_0_66666666-6666-6666-6666-666666666666.png"},
      {"exportedFileName":"exported-07-dday.png","suggestedHumanReadableName":"appstore-ko-07-dday-demo_0_77777777-7777-7777-7777-777777777777.png"}
    ]
  }
]
JSON

cat > "$fake_bin/xcrun" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-}" == "xcresulttool" && "${2:-}" == "export" && "${3:-}" == "attachments" ]] || exit 2
output_path=""
for ((index = 1; index <= $#; index++)); do
    arg="${!index}"
    if [[ "$arg" == "--output-path" ]]; then
        next=$((index + 1))
        output_path="${!next}"
    fi
done
[[ -n "$output_path" ]] || exit 2
cp "$DUTYPARK_TEST_EXPORT_ROOT"/* "$output_path/"
SCRIPT
chmod +x "$fake_bin/xcrun"

mkdir "$work/capture.xcresult"
PATH="$fake_bin:$PATH" DUTYPARK_TEST_EXPORT_ROOT="$export_root" \
    "$script_dir/extract-app-store-captures.sh" \
    --result "$work/capture.xcresult" --locale ko --output-root "$output_root"

for name in "${names[@]}"; do
    file="$output_root/ko/$name.png"
    [[ -f "$file" ]] || { echo "FAIL: missing extracted $file" >&2; exit 1; }
    metadata="$(sips -g pixelWidth -g pixelHeight -g hasAlpha "$file")"
    [[ "$metadata" == *"pixelWidth: 1320"* && "$metadata" == *"pixelHeight: 2868"* && "$metadata" == *"hasAlpha: no"* ]] || {
        echo "FAIL: extracted PNG contract for $file" >&2
        exit 1
    }
done

if PATH="$fake_bin:$PATH" DUTYPARK_TEST_EXPORT_ROOT="$export_root" \
    "$script_dir/extract-app-store-captures.sh" \
    --result "$work/capture.xcresult" --locale ko --output-root "$output_root" >/dev/null 2>&1; then
    echo "FAIL: overwrite without --force was accepted" >&2
    exit 1
fi

PATH="$fake_bin:$PATH" DUTYPARK_TEST_EXPORT_ROOT="$export_root" \
    "$script_dir/extract-app-store-captures.sh" \
    --result "$work/capture.xcresult" --locale ko --output-root "$output_root" --force >/dev/null

export_root_en="$work/export-en"
output_root_en="$work/raw-en"
mkdir "$export_root_en"
cp "$export_root"/exported-*.png "$export_root_en/"
sed 's/appstore-ko/appstore-en/g' "$manifest" > "$export_root_en/manifest.json"
PATH="$fake_bin:$PATH" DUTYPARK_TEST_EXPORT_ROOT="$export_root_en" \
    "$script_dir/extract-app-store-captures.sh" \
    --result "$work/capture.xcresult" --locale en --output-root "$output_root_en"
for name in "${names[@]}"; do
    [[ -f "$output_root_en/en/$name.png" ]] || {
        echo "FAIL: missing English extracted $name.png" >&2
        exit 1
    }
done

cp "$manifest" "$work/manifest.valid.json"
python3 - "$manifest" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    payload = json.load(stream)
payload[0]["attachments"].append(payload[0]["attachments"][0])
with open(sys.argv[1], "w", encoding="utf-8") as stream:
    json.dump(payload, stream)
PY
if PATH="$fake_bin:$PATH" DUTYPARK_TEST_EXPORT_ROOT="$export_root" \
    "$script_dir/extract-app-store-captures.sh" \
    --result "$work/capture.xcresult" --locale ko --output-root "$work/duplicate" >/dev/null 2>&1; then
    echo "FAIL: duplicate attachment was accepted" >&2
    exit 1
fi
[[ ! -e "$work/duplicate/ko/home.png" ]] || {
    echo "FAIL: duplicate attachment wrote partial output" >&2
    exit 1
}
mv "$work/manifest.valid.json" "$manifest"

rm "$export_root/exported-07-dday.png"
if PATH="$fake_bin:$PATH" DUTYPARK_TEST_EXPORT_ROOT="$export_root" \
    "$script_dir/extract-app-store-captures.sh" \
    --result "$work/capture.xcresult" --locale ko --output-root "$work/missing" >/dev/null 2>&1; then
    echo "FAIL: missing attachment was accepted" >&2
    exit 1
fi
[[ ! -e "$work/missing/ko/home.png" ]] || {
    echo "FAIL: missing attachment wrote partial output" >&2
    exit 1
}

cp "$repo_root/docs/app-store/generated/coral-cream-canvas.png" "$export_root/exported-07-dday.png"
if PATH="$fake_bin:$PATH" DUTYPARK_TEST_EXPORT_ROOT="$export_root" \
    "$script_dir/extract-app-store-captures.sh" \
    --result "$work/capture.xcresult" --locale ko --output-root "$work/invalid" >/dev/null 2>&1; then
    echo "FAIL: invalid dimensions were accepted" >&2
    exit 1
fi
[[ ! -e "$work/invalid/ko/home.png" ]] || {
    echo "FAIL: invalid image wrote partial output" >&2
    exit 1
}

echo "PASS: xcresult attachment extraction, seven-name mapping, validation, duplicate/missing handling, and overwrite guard"
