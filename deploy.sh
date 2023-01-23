#!/bin/zsh -eu

MYDIR=${0:a:h}

source $MYDIR/.env

set -o allexport

# VM host needs: zsh git yq

TOP=/prevu
CLONE=$(head -1 $INCOMING)
BRANCH=$(head -2 $INCOMING |tail -1)

GROUP_REPO=$(echo "$CLONE" | perl -pe 's=\.git$==; s=/+$==' |tr : / |rev |cut -f1-2 -d/ |rev)
GROUP=$(echo "$GROUP_REPO" |cut -d/ -f1)
 REPO=$(echo "$GROUP_REPO" |cut -d/ -f2)

EXTRA="-$BRANCH"
[ $BRANCH = main   ] && EXTRA=
[ $BRANCH = master ] && EXTRA=
HOST=${REPO}${EXTRA}.$DOMAIN_WILDCARD # xxx optional username if collision or yml config to use them

CLONED_CACHE=$TOP/$GROUP/$REPO/__clone


DIR=$TOP/$GROUP/$REPO/$BRANCH

echo BRANCH=$BRANCH
echo CLONE=$CLONE
echo CLONED_CACHE=$CLONED_CACHE

set -x


[ -e $TOP              ] || sudo mkdir -m777 $TOP
[ -e $TOP/$GROUP       ] || sudo mkdir -m777 $TOP/$GROUP
[ -e $TOP/$GROUP/$REPO ] || sudo mkdir -m777 $TOP/$GROUP/$REPO

CFG=/prevu/internetarchive/prevu/main/$GROUP-$REPO.yml # xxx

function cfg-val() {
  # Returns yaml configuration key, or "" if not present/empty
  local VAL=
  if [ -e $CFG ]; then
    VAL=$(yq -r "$1" $CFG | sed 's/^[ \t]*//;s/[ \t]*$//' | grep -Ev '^#')
    if [ "$VAL" = "" ]; then
      VAL=
    elif [ "$VAL" = null ]; then
      VAL=
    fi
  fi
  echo -n "$VAL"
}
function cfg-vals() {
  # Returns yaml configuration array of values, as mutliple lines, like cfg-val().
  # You can split the returned string via NEWLINE characters.
  local VAL=$(cfg-val "$1" | grep -E ^- | cut -b3-)
  echo -n "$VAL"
}


[ -e $CLONED_CACHE ]  ||  (
  mkdir  -p $CLONED_CACHE
  git clone $CLONE $CLONED_CACHE || echo nixxx this

  # figure out which docker registry to use
  REGISTRY=$REGISTRY_FALLBACK
  [ $CLONE =~ github.com ]  &&  REGISTRY=ghcr.io
  [ $CLONE =~ gitlab.com ]  &&  REGISTRY=registry.gitlab.com


  # xxx docker start container & run setup tasks
  typeset -a ARGS
  ARGS=($(cfg-val .docker.args))

  BRANCH_DEFAULT=$(cfg-val .branch.default)
  [ $BRANCH_DEFAULT ]  ||  BRANCH_DEFAULT=main

  if [ "$GROUP/$REPO" != "internetarchive/prevu" ]; then
    docker run -d --restart=always --pull=always -v /prevu/$GROUP/${REPO}:/prevu --name=$GROUP-$REPO \
      $ARGS $REGISTRY/$GROUP/$REPO/$BRANCH_DEFAULT
    sleep 3
  fi

  [ -e $CFG ]  &&  (
    IFS=$'\n'
    for cmd in $(cfg-vals .scripts.container.start); do
      docker exec $GROUP-$REPO sh -c "cd /prevu/$BRANCH && $cmd" # xxx prolly should put all cmds into tmp file, pass file in, exec it
    done
  )
)
(
  # xxx trigger on main/master branch pushes --> restart docker container
  cd $CLONED_CACHE
  git pull
)


if [ -e $DIR ]; then
  cd $DIR
  git checkout -b $BRANCH 2>/dev/null  ||  git checkout $BRANCH  # xxx necessary?
  git pull || ( git stash && git stash drop|cat && git pull )
else
  cp -pr $CLONED_CACHE/ $DIR/
  cd $DIR
  git checkout $BRANCH || git checkout -b $BRANCH # xxx or new unpushed branch
  echo xxx run any optional initial build step
  echo xxx setup watchers on optional file patterns to run sub-steps

 [ -e $CFG ]  &&  (
    IFS=$'\n'
    for CMD in $(cfg-vals .scripts.branch.start); do
      docker exec $GROUP-$REPO sh -c "cd /prevu/$BRANCH && $CMD" # xxx prolly should put all cmds into tmp file, pass file in, exec it
    done
  )
fi


# xxx do any initial build step here...

DOCROOT=$(cfg-val .docroot)
[ "$DOCROOT" = "" ] && DOCROOT=www
[ ! -e $DOCROOT ] && mkdir $DOCROOT && (cd $DOCROOT && wget https://raw.githubusercontent.com/internetarchive/prevu/main/www/index.html )


# now copy edited/save file in place
mkdir -p $(dirname "$FILE")
tail -n +3 $INCOMING >| "$FILE" # omit the top 2 lines used for git info
rm -fv $INCOMING




# ensure hostname is known to caddy
grep -E "^$HOST {\$" /etc/caddy/Caddyfile  ||  (

  PROXY=$(cfg-val .reverse_proxy)
  (
    echo "$HOST {"
    if [ "$PROXY" = "" ]; then
      echo "
\troot * $DIR/$DOCROOT
\tfile_server"

    else
      echo "reverse_proxy  $PROXY"
    fi
    echo "}"
  ) | sudo tee -a /etc/caddy/Caddyfile

  docker exec prevu zsh -c '/usr/sbin/caddy reload --config /etc/caddy/Caddyfile'
)

echo "\n\nhttps://$HOST\n\nSUCCESS PREVU\n\n"
exit 0 # xxx petabox setup vvvv


# petabox needs 8010 UDP ferm port opened.


-p 6666:6666 # non petabox # xxx??


# get `yq`
sudo wget -O  /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.30.8/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
