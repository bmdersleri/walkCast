#!/usr/bin/env bash
set -euo pipefail

# flutter-reset.sh
# soft reset => hot reload (r)
# hard reset => hot restart (R)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/apps/walkcast_mobile"
RUN_DIR="$ROOT_DIR/.run"
PIPE_FILE="$RUN_DIR/flutter.stdin"
PID_FILE="$RUN_DIR/flutter.pid"
LOG_FILE="$RUN_DIR/flutter.log"

mkdir -p "$RUN_DIR"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/flutter-reset.sh <start|soft|hard|stop|status>

Commands:
  start   Start flutter run in background (interactive stdin via pipe)
  soft    Send hot reload (r)
  hard    Send hot restart (R)
  stop    Stop flutter run process
  status  Show process status and log tail

Notes:
  - soft reset = Flutter hot reload
  - hard reset = Flutter hot restart
  - start uses:
      flutter run -d chrome --web-hostname=127.0.0.1 --web-port=40423
USAGE
}

is_running() {
  [[ -f "$PID_FILE" ]] || return 1
  local pid
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

require_running() {
  if ! is_running; then
    echo "Flutter process is not running. Start it first:" >&2
    echo "  ./scripts/flutter-reset.sh start" >&2
    exit 1
  fi
}

start_flutter() {
  if is_running; then
    echo "Flutter already running (pid: $(cat "$PID_FILE"))"
    exit 0
  fi

  rm -f "$PIPE_FILE"
  mkfifo "$PIPE_FILE"

  (
    cd "$APP_DIR"
    # Keep pipe writer open so flutter stdin does not get EOF.
    cat "$PIPE_FILE" | flutter run -d chrome --web-hostname=127.0.0.1 --web-port=40423 >>"$LOG_FILE" 2>&1
  ) &

  local bg_pid=$!
  echo "$bg_pid" > "$PID_FILE"
  sleep 1

  if is_running; then
    echo "Flutter started (pid: $bg_pid)"
    echo "Log: $LOG_FILE"
  else
    echo "Failed to start Flutter. Check log: $LOG_FILE" >&2
    exit 1
  fi
}

send_cmd() {
  local cmd="$1"
  require_running
  if [[ ! -p "$PIPE_FILE" ]]; then
    echo "Command pipe not found: $PIPE_FILE" >&2
    exit 1
  fi
  printf '%s\n' "$cmd" > "$PIPE_FILE"
}

stop_flutter() {
  if ! is_running; then
    echo "Flutter not running."
    rm -f "$PID_FILE" "$PIPE_FILE"
    exit 0
  fi

  local pid
  pid="$(cat "$PID_FILE")"
  kill "$pid" 2>/dev/null || true
  sleep 1
  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null || true
  fi

  rm -f "$PID_FILE" "$PIPE_FILE"
  echo "Flutter stopped."
}

show_status() {
  if is_running; then
    echo "Flutter running (pid: $(cat "$PID_FILE"))"
  else
    echo "Flutter not running"
  fi
  echo "Log: $LOG_FILE"
  if [[ -f "$LOG_FILE" ]]; then
    echo "--- log tail ---"
    tail -n 20 "$LOG_FILE"
  fi
}

cmd="${1:-}"
case "$cmd" in
  start) start_flutter ;;
  soft) send_cmd "r"; echo "Sent soft reset (hot reload)." ;;
  hard) send_cmd "R"; echo "Sent hard reset (hot restart)." ;;
  stop) stop_flutter ;;
  status) show_status ;;
  -h|--help|help|"") usage ;;
  *)
    echo "Unknown command: $cmd" >&2
    usage
    exit 1
    ;;
esac
