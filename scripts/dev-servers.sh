#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_DIR="${ROOT_DIR}/.run"
VENV_DIR="${ROOT_DIR}/.venv"
PYTHON_BIN="${VENV_DIR}/bin/python"
UVICORN_BIN="${VENV_DIR}/bin/uvicorn"
BACKEND_PID_FILE="${RUN_DIR}/backend.pid"
PWA_PID_FILE="${RUN_DIR}/pwa.pid"
BACKEND_LOG="${RUN_DIR}/backend.log"
PWA_LOG="${RUN_DIR}/pwa.log"

BACKEND_HOST="127.0.0.1"
BACKEND_PORT="8000"
PWA_HOST="127.0.0.1"
PWA_PORT="5500"

mkdir -p "${RUN_DIR}"

is_running() {
  local pid="$1"
  kill -0 "${pid}" 2>/dev/null
}

read_pid() {
  local pid_file="$1"
  if [[ -f "${pid_file}" ]]; then
    cat "${pid_file}"
  fi
}

start_backend() {
  local pid
  pid="$(read_pid "${BACKEND_PID_FILE}" || true)"
  if [[ -n "${pid}" ]] && is_running "${pid}"; then
    echo "backend already running (pid: ${pid})"
    return
  fi

  echo "starting backend on ${BACKEND_HOST}:${BACKEND_PORT} ..."
  if [[ ! -x "${UVICORN_BIN}" ]]; then
    echo "missing ${UVICORN_BIN}. create venv and install requirements first."
    exit 1
  fi
  (
    cd "${ROOT_DIR}"
    nohup "${UVICORN_BIN}" backend.app.main:app --host "${BACKEND_HOST}" --port "${BACKEND_PORT}" >"${BACKEND_LOG}" 2>&1 &
    echo $! >"${BACKEND_PID_FILE}"
  )
  echo "backend started (pid: $(cat "${BACKEND_PID_FILE}"))"
}

start_pwa() {
  local pid
  pid="$(read_pid "${PWA_PID_FILE}" || true)"
  if [[ -n "${pid}" ]] && is_running "${pid}"; then
    echo "pwa already running (pid: ${pid})"
    return
  fi

  echo "starting pwa on ${PWA_HOST}:${PWA_PORT} ..."
  if [[ ! -x "${PYTHON_BIN}" ]]; then
    echo "missing ${PYTHON_BIN}. create venv and install requirements first."
    exit 1
  fi
  (
    cd "${ROOT_DIR}/mobile-pwa"
    nohup "${PYTHON_BIN}" -m http.server "${PWA_PORT}" --bind "${PWA_HOST}" >"${PWA_LOG}" 2>&1 &
    echo $! >"${PWA_PID_FILE}"
  )
  echo "pwa started (pid: $(cat "${PWA_PID_FILE}"))"
}

stop_service() {
  local name="$1"
  local pid_file="$2"

  local pid
  pid="$(read_pid "${pid_file}" || true)"
  if [[ -z "${pid}" ]]; then
    echo "${name} is not running (no pid file)"
    return
  fi

  if is_running "${pid}"; then
    echo "stopping ${name} (pid: ${pid}) ..."
    kill "${pid}" 2>/dev/null || true
    sleep 0.5
    if is_running "${pid}"; then
      echo "force killing ${name} (pid: ${pid})"
      kill -9 "${pid}" 2>/dev/null || true
    fi
    echo "${name} stopped"
  else
    echo "${name} pid file exists but process is not running"
  fi

  rm -f "${pid_file}"
}

status_service() {
  local name="$1"
  local pid_file="$2"
  local url="$3"

  local pid
  pid="$(read_pid "${pid_file}" || true)"

  if [[ -n "${pid}" ]] && is_running "${pid}"; then
    echo "${name}: running (pid: ${pid}) -> ${url}"
  else
    echo "${name}: stopped"
  fi
}

show_logs() {
  local target="${1:-all}"
  case "${target}" in
    backend)
      tail -n 80 "${BACKEND_LOG}" 2>/dev/null || echo "no backend log yet"
      ;;
    pwa)
      tail -n 80 "${PWA_LOG}" 2>/dev/null || echo "no pwa log yet"
      ;;
    all)
      echo "--- backend log ---"
      tail -n 40 "${BACKEND_LOG}" 2>/dev/null || echo "no backend log yet"
      echo
      echo "--- pwa log ---"
      tail -n 40 "${PWA_LOG}" 2>/dev/null || echo "no pwa log yet"
      ;;
    *)
      echo "invalid logs target: ${target}"
      echo "use: logs [backend|pwa|all]"
      exit 1
      ;;
  esac
}

usage() {
  cat <<USAGE
Usage: $(basename "$0") <command> [args]

Commands:
  start            Start backend and PWA servers
  stop             Stop backend and PWA servers
  restart          Restart backend and PWA servers
  status           Show server statuses
  logs [target]    Show logs (target: backend|pwa|all)
  help             Show this help
USAGE
}

cmd="${1:-help}"
case "${cmd}" in
  start)
    start_backend
    start_pwa
    ;;
  stop)
    stop_service "backend" "${BACKEND_PID_FILE}"
    stop_service "pwa" "${PWA_PID_FILE}"
    ;;
  restart)
    stop_service "backend" "${BACKEND_PID_FILE}"
    stop_service "pwa" "${PWA_PID_FILE}"
    start_backend
    start_pwa
    ;;
  status)
    status_service "backend" "${BACKEND_PID_FILE}" "http://${BACKEND_HOST}:${BACKEND_PORT}/api/v1/items"
    status_service "pwa" "${PWA_PID_FILE}" "http://${PWA_HOST}:${PWA_PORT}/"
    ;;
  logs)
    show_logs "${2:-all}"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "unknown command: ${cmd}"
    usage
    exit 1
    ;;
esac
