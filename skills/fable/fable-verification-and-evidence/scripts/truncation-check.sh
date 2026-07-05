#!/bin/sh
# truncation-check.sh — find Slack-style conversations API calls that will
# silently truncate or silently return nothing.
#
# Canon (verified against incident corpus, as of 2026-07-05):
#   - conversations.replies / conversations.history default to ~28 messages
#     and need limit=200 + a next_cursor loop, or threads silently truncate
#     (bit IC living memos, 2026-04-21).
#   - the `oldest` param returns 0 messages on ~80% of calls even with
#     in-range data; filter by age client-side instead (bit the IC memo cron
#     two Mondays running, 2026-04-27 and 2026-05-04).
#
# Usage: truncation-check.sh [dir-or-file]   (default: current directory)
# Exit:  0 = no findings, 1 = findings printed, 2 = usage error
#
# For each call site, the call line plus the next 6 lines (multiline arg
# lists) are inspected:
#   MISSING-LIMIT   no limit= in the window
#   MISSING-CURSOR  no cursor/next_cursor handling in the window
#   USES-OLDEST     oldest= passed (flaky; filter client-side)
# Scans *.py *.js *.ts. Portable: POSIX sh + awk + find.

target="${1:-.}"
[ -e "$target" ] || { echo "truncation-check: no such path: $target" >&2; exit 2; }

scan_file() {
  awk '
  { lines[NR] = $0 }
  END {
    for (i = 1; i <= NR; i++) {
      if (lines[i] !~ /conversations[_.](history|replies)[[:space:]]*\(/) continue
      haslimit = 0; hascursor = 0; hasoldest = 0
      hi = i + 6; if (hi > NR) hi = NR
      for (j = i; j <= hi; j++) {
        if (lines[j] ~ /limit[[:space:]]*[=:]/) haslimit = 1
        if (lines[j] ~ /(next_)?cursor/) hascursor = 1
        if (lines[j] ~ /oldest[[:space:]]*[=:]/) hasoldest = 1
      }
      tags = ""
      if (!haslimit) tags = tags " MISSING-LIMIT"
      if (!hascursor) tags = tags " MISSING-CURSOR"
      if (hasoldest) tags = tags " USES-OLDEST"
      if (tags != "") {
        printf "%s:%d:%s\n", FILENAME, i, tags
        printf "    %s\n", lines[i]
        found = 1
      }
    }
    exit found ? 10 : 0
  }' "$1"
}

if [ -f "$target" ]; then
  out=$(scan_file "$target")
else
  out=$(find "$target" -type f ! -path '*/.git/*' ! -path '*/node_modules/*' \
          \( -name '*.py' -o -name '*.js' -o -name '*.ts' \) -print | sort |
        while IFS= read -r f; do scan_file "$f"; done)
fi
if [ -n "$out" ]; then
  printf '%s\n' "$out"
  exit 1
fi
echo "truncation-check: no findings in $target"
exit 0
