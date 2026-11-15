#!/usr/bin/env bash
# Tests for scripts/session-start.sh — the status endpoint is served
# from files via curl's file:// support, no network needed.
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0

run() { echo '{}' | DESTREAMED_API_URL="$1" bash scripts/session-start.sh; }
ctx() { jq -r '.hookSpecificOutput.additionalContext'; }
check() { # name, haystack, needle
  if printf '%s' "$2" | grep -qF -- "$3"; then echo "ok   $1"; else echo "FAIL $1: missing '$3'"; echo "$2"; fail=1; fi
}
check_not() {
  if printf '%s' "$2" | grep -qF -- "$3"; then echo "FAIL $1: unexpected '$3'"; fail=1; else echo "ok   $1"; fi
}

# 1. Before the sunset: notice + tuner loop.
mkdir -p "$tmp/before"
cat > "$tmp/before/sunset" <<'JSON'
{"sunset_at":"2026-12-31T23:00:00+00:00","last_day":"2026-12-31","shut_down":false,"timezone":"Europe/Berlin","message_en":"Destreamed will be discontinued on 31.12.2026 (end of day, Europe/Berlin). Export your own data before then: Profile → Account → Export, or GET /api/v1/profile/export. Details: https://destreamed.com/sunset"}
JSON
out=$(run "file://$tmp/before")
printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' >/dev/null && echo "ok   before: valid hook JSON"
c=$(printf '%s' "$out" | ctx)
check "before: notice" "$c" "discontinued on 31.12.2026"
check "before: tuner loop kept" "$c" "/destreamed:tune"

# 2. After the sunset: no tuner loop, export hint.
mkdir -p "$tmp/after"
sed 's/"shut_down":false/"shut_down":true/' "$tmp/before/sunset" > "$tmp/after/sunset"
c=$(run "file://$tmp/after" | ctx)
check "after: discontinued" "$c" "Destreamed has been discontinued"
check "after: export hint" "$c" "Profile → Account → Export"
check_not "after: no tuner loop" "$c" "run the /destreamed:tune skill"

# 3. Status unreachable: plain tuner text, still valid JSON.
c=$(run "file://$tmp/missing" | ctx)
check "offline: tuner loop" "$c" "/destreamed:tune"
check_not "offline: no notice" "$c" "discontinued"

exit $fail
