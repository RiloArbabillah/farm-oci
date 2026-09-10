#!/usr/bin/env bash
# keepalive.sh — stimulasi aktivitas ringan supaya instance tidak direclaim Oracle
# (idle = CPU/net/memori < 20% selama 7 hari bisa direclaim).
# Jalankan via cron:  */5 * * * * /usr/local/bin/keepalive.sh
set -euo pipefail

# Job ringan ~2-5% CPU selama ~2 menit, berjalan background lalu selesai sendiri.
nohup bash -c 'for i in $(seq 1 6); do openssl speed -seconds 2 aes-128-cbc >/dev/null 2>&1 || true; sleep 25; done' >/dev/null 2>&1 &
disown || true
exit 0
