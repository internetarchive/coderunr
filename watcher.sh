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
  root * /app/www
  file_server
}" > /etc/caddy/Caddyfile
)


/usr/sbin/caddy start --config /etc/caddy/Caddyfile


sleep 864000 # hang out for 10d for now until triggers and container mgmt setup

# xxx could do instead?  ./pyinotify.py -e IN_CLOSE_WRITE -r /prevu

# every 5s enumerate:
for YML in $(ls /prevu/*/*/*/prevu.yml /prevu/internetarchive/prevu/main/*.yml 2>/dev/null); do

  ./pyinotify.py -e IN_CLOSE_WRITE www/sf/includes/less/**/


done