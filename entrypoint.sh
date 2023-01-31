#!/bin/zsh -exu

mkdir  -p /prevu/
chmod 777 /prevu/

cp /app/deploy.sh /prevu/

echo "
export DOMAIN_WILDCARD=$DOMAIN_WILDCARD
export REGISTRY_FALLBACK=$REGISTRY_FALLBACK
" >| /prevu/.env


# start with minimal web server setup
[ -e /prevu/Caddyfile ]  ||  (
  echo "
$(hostname -f) {
\troot * /app/www
\tfile_server
}" > /prevu/Caddyfile

  chmod 666 /prevu/Caddyfile
)


/usr/sbin/caddy start --config /prevu/Caddyfile &

/app/httpd.js -p5000 --no-cors --no-dotfiles www
