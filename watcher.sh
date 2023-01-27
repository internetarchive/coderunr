#!/bin/zsh -exu

mkdir -m777 -p /prevu/

cp /app/deploy.sh /prevu/

echo "
export DOMAIN_WILDCARD=$DOMAIN_WILDCARD
export REGISTRY_FALLBACK=$REGISTRY_FALLBACK
" >| /prevu/.env


# start with minimal web server setup
[ -e /etc/caddy/Caddyfile ]  ||  (
  echo "
$(hostname -f) {
\troot * /app/www
\tfile_server
}" > /etc/caddy/Caddyfile
)


/usr/sbin/caddy start --config /etc/caddy/Caddyfile


sleep 864000 # hang out for 10d for now until incoming webhook should trigger a docker pull/restart
