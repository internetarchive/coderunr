#!/bin/zsh -exu

mkdir  -p /coderunr/
chmod 777 /coderunr/

cp /app/deploy.sh /coderunr/

echo "
export DOMAIN_WILDCARD=$DOMAIN_WILDCARD
export REGISTRY_FALLBACK=$REGISTRY_FALLBACK
" >| /coderunr/.env


# start with minimal web server setup
[ -e /coderunr/Caddyfile ]  ||  (
  echo "
$(hostname -f) {
\troot * /app/www
\tfile_server
}" > /coderunr/Caddyfile

  chmod 666 /coderunr/Caddyfile
)

# xxx persist certs via /coderunr/   /root/.local/share/caddy/

/usr/sbin/caddy start --config /coderunr/Caddyfile &

/app/httpd.js -p5000 --no-cors --no-dotfiles www
