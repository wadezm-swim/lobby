#!/bin/bash
# Launches the built app on a Mac and fails if it doesn't show its window, or
# if it spins after showing it.
#
#   scripts/launch-check.sh path/to/Lobby.app direct   run the binary straight from the shell
#   scripts/launch-check.sh path/to/Lobby.app open     launch through LaunchServices, like Finder does
#
# The app keeps a launch diary at ~/Library/Application Support/Lobby/launch.log
# and writes "window ready" once its first window has laid out.
set -u
APP="$1"
MODE="${2:-direct}"
DIARY="$HOME/Library/Application Support/Lobby/launch.log"
OUT="launch-$MODE.log"
rm -f "$DIARY"
: > "$OUT"

case "$MODE" in
  direct)
    "$APP/Contents/MacOS/Lobby" > "$OUT" 2>&1 &
    PID=$!
    ;;
  open)
    open -n "$APP"
    sleep 3
    PID=$(pgrep -nx Lobby || true)
    ;;
esac

alive() { [ -n "${PID:-}" ] && kill -0 "$PID" 2>/dev/null; }
ready() { [ -f "$DIARY" ] && grep -q "window ready" "$DIARY"; }

diary() {
  echo "--- launch diary ---"; cat "$DIARY" 2>/dev/null || echo "(no diary written)"
  if [ -s "$OUT" ]; then echo "--- app output ---"; head -40 "$OUT"; fi
}

sample_main() {
  sample "$PID" "$1" -file sample.txt >/dev/null 2>&1 || true
  awk '/com.apple.main-thread/{p=1} p{print} /^$/{if(p){exit}}' sample.txt | head -"${2:-60}" || true
}

for i in $(seq 1 30); do
  ready && break
  alive || break
  sleep 1
done

if ! alive; then
  CODE=0; wait "$PID" 2>/dev/null || CODE=$?
  echo "::error::[$MODE] Lobby exited (code $CODE) within 30 seconds"
  diary
  sleep 5
  for f in ~/Library/Logs/DiagnosticReports/Lobby*; do [ -f "$f" ] && head -150 "$f"; done
  exit 1
fi

if ! ready; then
  echo "::error::[$MODE] Lobby was alive after 30 seconds but never showed its window"
  diary
  echo "--- main thread sample ---"; sample_main 3 80
  kill "$PID" 2>/dev/null || true
  exit 1
fi

echo "[$MODE] Lobby showed its window after about ${i}s"
# Now watch it for a few seconds: a busy main thread here is the "not responding" Wade saw.
sleep 5
CPU=$(ps -o %cpu= -p "$PID" | tr -d ' ')
echo "[$MODE] CPU after the window: ${CPU}%"
diary
if [ "${CPU%.*}" -ge 50 ] 2>/dev/null; then
  echo "::error::[$MODE] Lobby is spinning at ${CPU}% CPU after showing its window"
  echo "--- main thread sample ---"; sample_main 3 80
  kill "$PID" 2>/dev/null || true
  exit 1
fi
kill "$PID" 2>/dev/null || true
exit 0
