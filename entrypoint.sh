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

  chmod 666 /etc/caddy/Caddyfile
)


/usr/sbin/caddy start --config /etc/caddy/Caddyfile &

/app/httpd.js -p5000 --no-cors --no-dotfiles www
