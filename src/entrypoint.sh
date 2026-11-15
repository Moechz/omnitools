#!/bin/sh
# ===========================================================================
# Omni Tools entrypoint for a non-root container (TOS 7 requirement).
#
# The image serves its static site with nginx on port 80, which uid 1000 cannot
# bind. This wrapper writes a small nginx configuration on the mounted volume
# and serves the same files on port 8080.
# ===========================================================================
set -e
set -u

CFG=/config
mkdir -p "$CFG" 2>/dev/null || true

if ! ( : > "$CFG/.write-test" ) 2>/dev/null; then
  echo "omnitools: $CFG is not writable by uid $(id -u)" >&2
  exit 1
fi
rm -f "$CFG/.write-test"

cat > "$CFG/nginx.conf" <<'NGINX'
worker_processes 1;
pid /tmp/nginx.pid;
error_log /dev/stderr warn;
events { worker_connections 1024; }
http {
  include /etc/nginx/mime.types;
  default_type application/octet-stream;
  access_log /dev/stdout;
  client_body_temp_path /tmp/nginx-body;
  proxy_temp_path /tmp/nginx-proxy;
  fastcgi_temp_path /tmp/nginx-fcgi;
  uwsgi_temp_path /tmp/nginx-uwsgi;
  scgi_temp_path /tmp/nginx-scgi;
  server {
    listen 8080;
    root /usr/share/nginx/html;
    index index.html;
    location / { try_files $uri $uri/ /index.html; }
  }
}
NGINX

exec nginx -c "$CFG/nginx.conf" -g "daemon off;"
