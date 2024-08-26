#!/bin/zsh -exu

mkdir  -p /coderunr/
chmod 777 /coderunr/

cp /app/run.sh /coderunr/

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

mkdir -p /root/.local/share
mkdir -p /coderunr/__certs
ln -s /coderunr/__certs  /root/.local/share/caddy

/usr/sbin/caddy start --config /coderunr/Caddyfile &

cd www
../httpd.js
