#!/usr/bin/env bash
set -u

# Lightweight VPS monitor for short freezes.
# Usage:
#   sudo bash vps-snapshot-monitor.sh 5
# Optional env:
#   HABITO_MONITOR_LOG_DIR=/var/log/habito-vps-monitor
#   WP_PATH=/var/www/habitobarberia.com

INTERVAL_SECONDS="${1:-5}"
LOG_DIR="${HABITO_MONITOR_LOG_DIR:-/var/log/habito-vps-monitor}"
HEAVY_EVERY="${HABITO_MONITOR_HEAVY_EVERY:-12}"

if ! [[ "$INTERVAL_SECONDS" =~ ^[0-9]+$ ]] || [ "$INTERVAL_SECONDS" -lt 1 ]; then
  echo "Interval must be a positive integer. Example: $0 5" >&2
  exit 1
fi

if ! mkdir -p "$LOG_DIR" 2>/dev/null; then
  LOG_DIR="$PWD/habito-vps-monitor-logs"
  mkdir -p "$LOG_DIR"
  echo "Could not write /var/log. Using $LOG_DIR"
fi

have() {
  command -v "$1" >/dev/null 2>&1
}

log_file() {
  date +"$LOG_DIR/vps-monitor-%Y-%m-%d.log"
}

section() {
  printf '\n===== %s =====\n' "$1"
}

run_or_note() {
  local label="$1"
  shift
  section "$label"
  "$@" 2>&1 || printf 'command failed: %s\n' "$*"
}

snapshot() {
  local iteration="$1"
  local run_heavy=0
  if [ "$HEAVY_EVERY" -le 1 ] || [ $((iteration % HEAVY_EVERY)) -eq 0 ]; then
    run_heavy=1
  fi

  {
    section "snapshot"
    date -Is
    printf 'hostname: %s\n' "$(hostname 2>/dev/null || true)"
    printf 'kernel: %s\n' "$(uname -a 2>/dev/null || true)"
    printf 'interval_seconds: %s\n' "$INTERVAL_SECONDS"
    printf 'iteration: %s\n' "$iteration"
    printf 'heavy_snapshot: %s\n' "$run_heavy"

    section "load"
    cat /proc/loadavg 2>/dev/null || true
    if have nproc; then
      printf 'cpu_cores: %s\n' "$(nproc)"
    fi
    uptime 2>/dev/null || true

    run_or_note "memory" free -m
    if have vmstat; then
      run_or_note "vmstat" vmstat 1 2
    fi

    section "top cpu"
    if have top; then
      COLUMNS=220 top -b -n 1 -o %CPU 2>/dev/null | head -40 || true
    fi

    section "processes cpu"
    ps aux --sort=-%cpu 2>/dev/null | head -30 || ps aux 2>/dev/null | head -30 || true

    section "processes memory"
    ps aux --sort=-%mem 2>/dev/null | head -30 || true

    section "service process counts"
    for pattern in php-fpm apache2 httpd nginx mysqld mariadbd redis-server; do
      printf '%s: %s\n' "$pattern" "$(pgrep -fc "$pattern" 2>/dev/null || echo 0)"
    done

    if [ "$run_heavy" -eq 1 ]; then
      run_or_note "disk" df -h

      if have iostat; then
        run_or_note "iostat" iostat -xz 1 2
      fi

      if have ss; then
        run_or_note "socket summary" ss -s
        section "top tcp states"
        ss -tan 2>/dev/null | awk 'NR>1 {count[$1]++} END {for (s in count) print s, count[s]}' | sort || true
      fi

      if have systemctl; then
        section "systemd service status"
        for service in nginx apache2 httpd php-fpm php8.1-fpm php8.2-fpm php8.3-fpm mysql mariadb redis-server; do
          systemctl is-active "$service" >/dev/null 2>&1 && systemctl --no-pager --plain status "$service" 2>/dev/null | head -18
        done
      fi

      if have mysqladmin; then
        run_or_note "mysqladmin status" mysqladmin status
      fi

      if have mysql; then
        section "mysql processlist"
        mysql --batch --raw -e "SHOW FULL PROCESSLIST;" 2>&1 | head -80 || true
        section "mysql innodb status"
        mysql --batch --raw -e "SHOW ENGINE INNODB STATUS\\G" 2>&1 | sed -n '1,180p' || true
      fi

      if have wp && [ -n "${WP_PATH:-}" ] && [ -d "$WP_PATH" ]; then
        section "wp cron due"
        wp --allow-root --path="$WP_PATH" cron event list --due-now --fields=hook,next_run_relative,recurrence 2>&1 | head -80 || true
        section "wp option cron size"
        wp --allow-root --path="$WP_PATH" option get cron --format=json 2>/dev/null | wc -c | awk '{print "cron_option_bytes: "$1}' || true
      fi

      section "recent kernel messages"
      dmesg -T 2>/dev/null | tail -40 || true

      if have journalctl; then
        section "recent php/mysql/nginx/apache logs"
        journalctl --since "2 minutes ago" --no-pager 2>/dev/null \
          | grep -Ei 'php|fpm|mysql|mariadb|nginx|apache|oom|killed|error|slow|timeout' \
          | tail -120 || true
      fi
    fi

    printf '\n'
  } >>"$(log_file)"
}

echo "Writing VPS snapshots to: $LOG_DIR"
echo "Press Ctrl+C to stop."

iteration=0
while true; do
  iteration=$((iteration + 1))
  snapshot "$iteration"
  sleep "$INTERVAL_SECONDS"
done
