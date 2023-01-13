#!/bin/zsh -eu

set -o allexport

TOP=/prevu
REGISTRY=registry.archive.org # xxx
DOMAIN=code.archive.org

CLONE=$(head -1 $INCOMING)
BRANCH=$(head -2 $INCOMING |tail -1)

GROUP_REPO=$(echo "$CLONE" | perl -pe 's=\.git$==; s=/+$==' |tr : / |rev |cut -f1-2 -d/ |rev)
GROUP=$(echo "$GROUP_REPO" |cut -d/ -f1)
 REPO=$(echo "$GROUP_REPO" |cut -d/ -f2)

EXTRA="-$BRANCH"
[ $BRANCH = main   ] && EXTRA=
[ $BRANCH = master ] && EXTRA=
HOST=${REPO}${EXTRA}.$DOMAIN # xxx optional username if collision or yml config to use them

IMG=$REGISTRY/$GROUP/$REPO/master # xxx or main... fish out from below cloned repo &

CLONED_CACHE=$TOP/$GROUP/$REPO/__clone


DIR=$TOP/$GROUP/$REPO/$BRANCH
env
set -x


[ -e $TOP              ] || sudo mkdir -m777 $TOP
[ -e $TOP/$GROUP       ] || sudo mkdir -m777 $TOP/$GROUP
[ -e $TOP/$GROUP/$REPO ] || sudo mkdir -m777 $TOP/$GROUP/$REPO

[ -e $CLONED_CACHE ]  ||  (
  mkdir  -p $CLONED_CACHE
  git clone $CLONE $CLONED_CACHE
)
(
  cd $CLONED_CACHE
  git pull
)


if [ -e $DIR ]; then
  cd $DIR
  git checkout -b $BRANCH  ||  git checkout $BRANCH  # xxx necessary?
  git pull
else
  cp -pr $CLONED_CACHE/ $DIR/
  cd $DIR
  git checkout $BRANCH
  echo xxx run any optional initial build step
  echo xxx setup watchers on optional file patterns to run sub-steps
  # docker run --rm -it -v /prevu/$GROUP/$REPO/:/prevu/ $IMG zsh
  #     --restart=always --name=$GROUP-$REPO
  #     cd /prevu/$BRANCH
  #     vr i

  # offshoot DOCROOT=build
  #     npm i
  #     npm run build

fi


# xxx do any initial build step here...

DOCROOT=www # xxx
[ ! -e $DOCROOT ] && [ -e public ] && DOCROOT=public
[ ! -e $DOCROOT ] && [ -e build  ] && DOCROOT=build
[ ! -e $DOCROOT ] && [ -e public ] && DOCROOT=www
[ ! -e $DOCROOT ] && mkdir www && (cd www && wget https://raw.githubusercontent.com/internetarchive/prevu/main/www/index.html )


# now copy edited/save file in place
mkdir -p $(dirname "$FILE")
tail -n +3 $INCOMING >| "$FILE" # omit the top 2 lines used for git info
rm -fv $INCOMING




# ensure hostname is known to caddy
grep -E "^$HOST {\$" /etc/caddy/Caddyfile  ||  (

  echo "
$HOST {
\troot * $DIR/$DOCROOT
\tfile_server
}
" | sudo tee -a /etc/caddy/Caddyfile

  docker exec prevu zsh -c '/usr/sbin/caddy reload --config /etc/caddy/Caddyfile'
)

echo "\n\nhttps://$HOST\n\nSUCCESS PREVU\n\n"
exit 0 # xxx petabox setup vvvv

export REGISTRY=registry.archive.org GROUP=ia REPO=petabox;

docker run -d --restart=always --pull=always -v /prevu/$GROUP/${REPO}:/prevu --name=$GROUP-$REPO \
  -e NOMAD_PORT_http=6666 \
  \
  --net=host  \
  -v /opt/.petabox/petabox-prod.xml:/opt/.petabox/petabox-prod.xml \
  -v /opt/.petabox/dbserver:/opt/.petabox/dbserver \
  \
  $REGISTRY/$GROUP/$REPO/master

# manually change /etc/caddy/Caddyfile:
echo '
petabox.code.archive.org {
  reverse_proxy  localhost:6666
}
'

cat       /prevu/ia/petabox/master/www/common/ia | docker exec -i ia-petabox zsh -c 'cat > www/common/ia'
docker cp /prevu/ia/petabox/master/etc/nginx/nginx.conf   ia-petabox:etc/nginx/
docker cp /prevu/ia/petabox/master/etc/nginx/archive.conf ia-petabox:etc/nginx/
docker exec -it ia-petabox zsh -c '/usr/local/sbin/nginx -s reload'

docker exec -it ia-petabox zsh -c 'cd /prevu/master && vr i'

-p 6666:6666 # non petabox
