#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
cd "$REPO_ROOT"

if ! command -v rg >/dev/null 2>&1; then
  echo "error: rg command is required" >&2
  exit 1
fi

TODAY=$(date +%Y-%m-%d)
REPORT="frontend/qa/theme-utility-phase2/baseline-metrics-${TODAY}.md"
LATEST="frontend/qa/theme-utility-phase2/baseline-metrics-latest.md"

count_cmd() {
  local cmd="$1"
  local output
  output=$(eval "$cmd" 2>/dev/null || true)
  if [[ -z "$output" ]]; then
    echo 0
  else
    printf '%s\n' "$output" | wc -l | tr -d ' '
  fi
}

TOTAL_STYLE=$(count_cmd "rg -n --glob 'frontend/src/**/*.vue' ':style='")
TEXT_PRIMARY=$(count_cmd "rg -n --glob 'frontend/src/**/*.vue' \":style=\\\"\\{ color: 'var\\(--dp-text-primary\\)' \\}\\\"\"")
TEXT_SECONDARY=$(count_cmd "rg -n --glob 'frontend/src/**/*.vue' \":style=\\\"\\{ color: 'var\\(--dp-text-secondary\\)' \\}\\\"\"")
TEXT_MUTED=$(count_cmd "rg -n --glob 'frontend/src/**/*.vue' \":style=\\\"\\{ color: 'var\\(--dp-text-muted\\)' \\}\\\"\"")
BG_SECONDARY=$(count_cmd "rg -n --glob 'frontend/src/**/*.vue' \":style=\\\"\\{ backgroundColor: 'var\\(--dp-bg-secondary\\)' \\}\\\"\"")
BORDER_PRIMARY=$(count_cmd "rg -n --glob 'frontend/src/**/*.vue' \":style=\\\"\\{ borderColor: 'var\\(--dp-border-primary\\)' \\}\\\"\"")

BG_CARD_BORDER_PRIMARY=$(count_cmd "rg -n --glob 'frontend/src/**/*.vue' \"backgroundColor: 'var\\(--dp-bg-card\\)'.*borderColor: 'var\\(--dp-border-primary\\)'\"")
INPUT_TRIPLE=$(count_cmd "rg -n --glob 'frontend/src/**/*.vue' \"backgroundColor: 'var\\(--dp-bg-input\\)'.*borderColor: 'var\\(--dp-border-input\\)'.*color: 'var\\(--dp-text-primary\\)'\"")
ROW_DIVIDER_PRIMARY=$(count_cmd "rg -n --glob 'frontend/src/**/*.vue' \"borderBottomWidth: '1px'.*borderBottomStyle: 'solid'.*borderBottomColor: 'var\\(--dp-border-primary\\)'\"")

LITERAL_OUTSIDE_STYLE_CSS=$(count_cmd "rg -n --glob 'frontend/src/**/*.{vue,ts,css}' \"#[0-9a-fA-F]{3,8}|rgba?\\(|hsla?\\(\" -g '!frontend/src/style.css'")
PALETTE_HARDCODE=$(count_cmd "rg -n --glob 'frontend/src/**/*.{vue,css,ts}' \"\\b(text|bg|border|from|to|ring|outline)-(red|blue|green|amber|orange|yellow|gray|slate|white|black)-\"")

TOP_FILES=$(eval "rg -n --glob 'frontend/src/**/*.vue' ':style='" 2>/dev/null | cut -d: -f1 | sort | uniq -c | sort -nr | head -20 || true)

cat > "$REPORT" <<EOF_MD
# Theme Utility Phase 2 Baseline Metrics (${TODAY})

## Summary
- Total static token ':style' usage in Vue templates: **${TOTAL_STYLE}**
- ':style="{ color: 'var(--dp-text-primary)' }"': **${TEXT_PRIMARY}**
- ':style="{ color: 'var(--dp-text-secondary)' }"': **${TEXT_SECONDARY}**
- ':style="{ color: 'var(--dp-text-muted)' }"': **${TEXT_MUTED}**
- ':style="{ backgroundColor: 'var(--dp-bg-secondary)' }"': **${BG_SECONDARY}**
- ':style="{ borderColor: 'var(--dp-border-primary)' }"': **${BORDER_PRIMARY}**

## Repeated Combination Patterns
- 'bg-card + border-primary': **${BG_CARD_BORDER_PRIMARY}**
- 'bg-input + border-input + text-primary': **${INPUT_TRIPLE}**
- 'border-bottom: 1px solid var(--dp-border-primary)': **${ROW_DIVIDER_PRIMARY}**

## Hardcoded Literal Guardrail
- Literal color matches outside 'frontend/src/style.css': **${LITERAL_OUTSIDE_STYLE_CSS}**
- Tailwind palette hardcode tokens (e.g. text-red-500, bg-blue-500): **${PALETTE_HARDCODE}**

## Top Files by :style Usage
~~~text
${TOP_FILES}
~~~

## Command Bundle
~~~bash
rg -n --glob 'frontend/src/**/*.vue' ':style='
rg -n --glob 'frontend/src/**/*.vue' ":style=\"\\{ color: 'var\\(--dp-text-primary\\)' \\}\""
rg -n --glob 'frontend/src/**/*.vue' ":style=\"\\{ color: 'var\\(--dp-text-secondary\\)' \\}\""
rg -n --glob 'frontend/src/**/*.vue' ":style=\"\\{ color: 'var\\(--dp-text-muted\\)' \\}\""
rg -n --glob 'frontend/src/**/*.vue' ":style=\"\\{ backgroundColor: 'var\\(--dp-bg-secondary\\)' \\}\""
rg -n --glob 'frontend/src/**/*.vue' ":style=\"\\{ borderColor: 'var\\(--dp-border-primary\\)' \\}\""
rg -n --glob 'frontend/src/**/*.vue' "backgroundColor: 'var\\(--dp-bg-card\\)'.*borderColor: 'var\\(--dp-border-primary\\)'"
rg -n --glob 'frontend/src/**/*.vue' "backgroundColor: 'var\\(--dp-bg-input\\)'.*borderColor: 'var\\(--dp-border-input\\)'.*color: 'var\\(--dp-text-primary\\)'"
rg -n --glob 'frontend/src/**/*.vue' "borderBottomWidth: '1px'.*borderBottomStyle: 'solid'.*borderBottomColor: 'var\\(--dp-border-primary\\)'"
rg -n --glob 'frontend/src/**/*.{vue,ts,css}' "#[0-9a-fA-F]{3,8}|rgba?\\(|hsla?\\(" -g '!frontend/src/style.css'
rg -n --glob 'frontend/src/**/*.{vue,css,ts}' "\\b(text|bg|border|from|to|ring|outline)-(red|blue|green|amber|orange|yellow|gray|slate|white|black)-"
~~~
EOF_MD

cp "$REPORT" "$LATEST"

echo "generated: $REPORT"
echo "updated: $LATEST"
