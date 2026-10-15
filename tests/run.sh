#!/usr/bin/env bash
#
# Runs every suite under plain Lua -- no REAPER, no ReaImGui. The modules under
# test (lib/scan.lua, lib/report.lua) touch neither.
#
# REAPER ships Lua 5.4, so that is the version to prefer when several are around.

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LUA="${LUA:-}"
if [ -z "$LUA" ]; then
  for candidate in lua5.4 lua54 lua; do
    if command -v "$candidate" >/dev/null 2>&1; then LUA="$candidate"; break; fi
  done
fi

if [ -z "$LUA" ]; then
  echo "No lua interpreter found. Install lua5.4, or set LUA=/path/to/lua." >&2
  exit 1
fi

echo "lua: $("$LUA" -v 2>&1)"
echo

status=0
for suite in "$HERE"/test_*.lua; do
  # Capture before printing, so a pipe cannot swallow the exit status.
  output="$("$LUA" "$suite" 2>&1)"
  rc=$?
  echo "$output"
  [ $rc -eq 0 ] || status=1
done

echo
if [ $status -eq 0 ]; then echo "ALL GREEN"; else echo "FAILURES"; fi
exit $status
