#!/bin/zsh -ex

GROUP=${1:-"www"}
REPO=${2:-"av"}
BRANCH=${3:-"main"}
DOCROOT=${4:-"www"}

GIT=git.archive.org

CLONE=${5:-"https://$GIT/$GROUP/$REPO.git"} # xxx
CLONE=${5:-"git@$GIT:$GROUP/$REPO"} # xxx

REGISTRY=registry.archive.org
IMG=$REGISTRY/GROUP/$REPO/master
DOMAIN=code.archive.org
TOP=/prevu
CLONED_CACHE=$TOP/$GROUP/$REPO/__clone

DIR=$TOP/$GROUP/$REPO/$BRANCH

EXTRA="-$BRANCH"
[ $BRANCH = main   ] && EXTRA=
[ $BRANCH = master ] && EXTRA=
HOST=${REPO}${EXTRA}.$DOMAIN


[ -e $TOP              ] || sudo mkdir -m777 $TOP
[ -e $TOP/$GROUP       ] || sudo mkdir -m777 $TOP/$GROUP
[ -e $TOP/$GROUP/$REPO ] || sudo mkdir -m777 $TOP/$GROUP/$REPO

[ -e $CLONED_CACHE ]  ||  (
  sudo mkdir -m777 -p $CLONED_CACHE
  git clone $CLONE $CLONED_CACHE
)
(
  cd $CLONED_CACHE
  git pull  ||  (
    # git config --global --add safe.directory /private/var/tmp/prevu/www/lohi/__clone # xxx workaround root owner issue (when running locally on mac, at least)
    git pull
  )
)


if [ -e $DIR ]; then
  cd $DIR
  git checkout -b $BRANCH  ||  git checkout $BRANCH  # xxx necessary?
  git pull
else
  rsync -qav $CLONED_CACHE/ $DIR/
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


# ensure hostname is known to caddy
grep -E "^$HOST {\$" /etc/Caddyfile  ||  (

  echo "
$HOST {
\troot * $DIR/$DOCROOT
\tfile_server
}
" | sudo tee -a /etc/Caddyfile

  cd /etc/
  sudo /usr/bin/caddy reload
)

exit 0 # xxx petabox setup vvvv

export REGISTRY=registry.archive.org GROUP=ia REPO=petabox;

docker run -d --restart=always -v /prevu/$GROUP/${REPO}:/prevu --name=$GROUP-$REPO \
  -e NOMAD_PORT_http=6666 \
  \
  --net=host  \
  -v /opt/.petabox/petabox-prod.xml:/opt/.petabox/petabox-prod.xml \
  -v /opt/.petabox/dbserver:/opt/.petabox/dbserver \
  \
  $REGISTRY/$GROUP/$REPO/master


-p 6666:6666 # non petabox
