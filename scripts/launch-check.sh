#!/bin/bash
# Launches the built app on a Mac and fails if it doesn't show its window.
#
#   scripts/launch-check.sh path/to/Lobby.app direct   run the binary straight from the shell
#   scripts/launch-check.sh path/to/Lobby.app open     launch through LaunchServices, like Finder does
#
# The app logs "Lobby: window ready" once its first window has laid out. If
# that never shows, the main thread is sampled so the log says where it stuck.
set -u
APP="$1"
MODE="${2:-direct}"
LOG="launch-$MODE.log"
: > "$LOG"

case "$MODE" in
  direct)
    "$APP/Contents/MacOS/Lobby" > "$LOG" 2>&1 &
    PID=$!
    ;;
  open)
    START=$(date "+%Y-%m-%d %H:%M:%S")
    open -n "$APP"
    sleep 3
    PID=$(pgrep -nx Lobby || true)
    ;;
esac

ready() {
  if [ "$MODE" = open ]; then
    log show --start "$START" --predicate 'process == "Lobby"' --style compact > "$LOG" 2>/dev/null
  fi
  grep -q "window ready" "$LOG"
}

for i in $(seq 1 30); do
  ready && break
  if [ -z "${PID:-}" ] || ! kill -0 "$PID" 2>/dev/null; then break; fi
  sleep 1
done

if [ -n "${PID:-}" ] && kill -0 "$PID" 2>/dev/null; then
  if ready; then
    echo "[$MODE] Lobby showed its window after about ${i}s"
    echo "--- app output ---"; cat "$LOG"
    kill "$PID" 2>/dev/null || true
    exit 0
  fi
  echo "::error::[$MODE] Lobby was alive after 30 seconds but never showed its window (a hang)"
  echo "--- app output ---"; cat "$LOG"
  echo "--- main thread sample ---"
  sample "$PID" 3 -file sample.txt >/dev/null 2>&1 || true
  awk '/com.apple.main-thread/{p=1} p{print} /^$/{if(p){exit}}' sample.txt | head -90
  kill "$PID" 2>/dev/null || true
  exit 1
fi

CODE=0
[ -n "${PID:-}" ] && { wait "$PID" 2>/dev/null || CODE=$?; }
echo "::error::[$MODE] Lobby exited (code $CODE) within 30 seconds"
echo "--- app output ---"; cat "$LOG"
sleep 5
for f in ~/Library/Logs/DiagnosticReports/Lobby*; do [ -f "$f" ] && head -150 "$f"; done
exit 1
