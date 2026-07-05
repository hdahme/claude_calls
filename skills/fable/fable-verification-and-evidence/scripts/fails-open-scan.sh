#!/bin/sh
# fails-open-scan.sh — find broad Python exception handlers that swallow errors
# ("fails open"), especially near side-effect calls. This is the pattern behind
# the 2026-06-12 Redis duplicate-post incident (get() -> except Exception ->
# return None -> dedup check re-fired) and the 2026-04-21 silent AttributeError
# incident (typo'd config attr swallowed as "synthesis failed").
#
# Usage: fails-open-scan.sh [dir-or-file]   (default: current directory)
# Exit:  0 = no findings, 1 = findings printed, 2 = usage error
#
# A finding = an `except Exception` / `except BaseException` / bare `except:`
# whose handler body (next 8 lines) swallows (return None/[]/{}/""/False, pass,
# or continue) without re-raising. Tag [NEAR-SIDE-EFFECT] is added when a
# side-effect-looking call (send/post/publish/set(/execute(/prompt/...) appears
# within 12 lines above or 8 below — those are the dangerous ones: an error
# becomes "not done yet" and the side effect fires again.
# Portable: POSIX sh + awk + find. No GNU extensions.

target="${1:-.}"
[ -e "$target" ] || { echo "fails-open-scan: no such path: $target" >&2; exit 2; }

scan_file() {
  awk '
  { lines[NR] = $0 }
  END {
    for (i = 1; i <= NR; i++) {
      if (lines[i] !~ /except([[:space:]]+(Exception|BaseException)[^:]*)?:/) continue
      swallows = 0; raises = 0
      ind = match(lines[i], /[^ \t]/)
      hi = i + 8; if (hi > NR) hi = NR
      for (j = i + 1; j <= hi; j++) {
        if (lines[j] ~ /^[[:space:]]*$/) continue            # blank line
        if (match(lines[j], /[^ \t]/) <= ind) break          # dedent: handler ended
        if (lines[j] ~ /(^|[[:space:]])raise([[:space:]]|$)/) { raises = 1; break }
        if (lines[j] ~ /return[[:space:]]+(None|False|\[\]|\{\}|"")([[:space:]]|#|$)/) swallows = 1
        if (lines[j] ~ /^[[:space:]]*(pass|continue)[[:space:]]*(#.*)?$/) swallows = 1
      }
      if (raises || !swallows) continue
      tag = ""
      lo = i - 12; if (lo < 1) lo = 1
      for (k = lo; k <= hi; k++) {
        if (lines[k] ~ /(send|post|publish|upload|dispatch|notify|insert|prompt|chat_|\.set\(|\.execute\(|\.delete\(|\.create\(|\.write\()/) {
          tag = " [NEAR-SIDE-EFFECT]"; break
        }
      }
      printf "%s:%d: broad except swallows error%s\n", FILENAME, i, tag
      printf "    %s\n", lines[i]
      found = 1
    }
    exit found ? 10 : 0
  }' "$1"
}

if [ -f "$target" ]; then
  out=$(scan_file "$target")
else
  out=$(find "$target" -name '*.py' -type f ! -path '*/.git/*' -print | sort |
        while IFS= read -r f; do scan_file "$f"; done)
fi
if [ -n "$out" ]; then
  printf '%s\n' "$out"
  exit 1
fi
echo "fails-open-scan: no findings in $target"
exit 0
