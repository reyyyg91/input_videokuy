#!/bin/sh
set -e

# Ganti ${PORT} dengan nilai environment variable
envsubst '\${PORT}' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf

# Jalankan nginx
exec nginx -g 'daemon off;'
