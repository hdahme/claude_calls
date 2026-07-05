#!/bin/sh
# dep-check.sh — grep-confirm a dependency actually exists in the manifest
# BEFORE a top-level import of it lands in auto-deployed code.
#
# Canon: on 2026-04-19 an Edit to requirements.txt "reported success" but the
# google-cloud-kms line never landed; the import auto-deployed and both replica
# sets CrashLoopBackOff'd — a full prod outage. An edit-tool success message is
# NOT evidence. This script produces the evidence: the matching manifest line.
#
# Usage: dep-check.sh <package> [manifest ...]
#   With no manifest args, checks requirements*.txt, pyproject.toml,
#   package.json in the current directory.
# Exit:  0 = found (matching lines printed), 1 = NOT FOUND, 2 = usage error

pkg="$1"
[ -n "$pkg" ] || { echo "usage: dep-check.sh <package> [manifest ...]" >&2; exit 2; }
shift

if [ $# -eq 0 ]; then
  set --
  for m in requirements*.txt pyproject.toml package.json; do
    [ -f "$m" ] && set -- "$@" "$m"
  done
  [ $# -eq 0 ] && { echo "dep-check: no manifest found in $(pwd)" >&2; exit 2; }
fi

found=1
for m in "$@"; do
  [ -f "$m" ] || { echo "dep-check: skipping missing $m" >&2; continue; }
  if grep -n -i -- "$pkg" "$m"; then
    echo "dep-check: FOUND '$pkg' in $m (lines above are the evidence)"
    found=0
  fi
done
[ $found -ne 0 ] && echo "dep-check: NOT FOUND: '$pkg' in: $*"
exit $found
