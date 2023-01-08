#!/bin/zsh

mkdir -m777 -p /prevu/

cp /app/deploy.sh /prevu/


/usr/sbin/caddy start --config /etc/caddy/Caddyfile
