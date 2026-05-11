#!/bin/sh
set -e

# Railway biasanya menyediakan PORT. Kalau tidak ada, default ke 80.
export PORT="${PORT:-80}"

# Runtime config untuk Flutter web (diakses via window.__ENV)
export BASE_API="${BASE_API:-}"

# Ganti ${PORT} dengan nilai environment variable
envsubst '\${PORT}' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf

# Buat /config.js dari template supaya BASE_API bisa beda per environment
if [ -f /usr/share/nginx/html/config.js.template ]; then
  envsubst '\${BASE_API}' < /usr/share/nginx/html/config.js.template > /usr/share/nginx/html/config.js
fi

# Jalankan nginx
exec nginx -g 'daemon off;'
