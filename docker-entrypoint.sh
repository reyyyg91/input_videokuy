#!/bin/sh
set -e

# Railway biasanya menyediakan PORT. Kalau tidak ada, default ke 80.
export PORT="${PORT:-80}"

# Ganti ${PORT} dengan nilai environment variable
envsubst '\${PORT}' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf

# Jalankan nginx
exec nginx -g 'daemon off;'
