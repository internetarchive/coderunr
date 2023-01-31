#!/bin/zsh -eu

MYDIR=${0:a:h}

# REQUIRED ENV VARS FROM CALLER:
#   $INCOMING  - name of the new version of file; the new file contents should be in this temp file
#   $CLONE     - the repo's git clone url
#   $BRANCH    - name of repo's current git branch
#   $FILE      - relative path name of file (relative to top dir of repo)

# NOTE: this defines $REGISTRY_FALLBACK and $DOMAIN_WILDCARD
source $MYDIR/.env


set -o allexport

# VM host needs: zsh git yq

TOP=/prevu

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


[ -e $TOP/$GROUP       ] || mkdir -m777 $TOP/$GROUP
[ -e $TOP/$GROUP/$REPO ] || mkdir -m777 $TOP/$GROUP/$REPO


CLONE_NEEDED=
[ -e $CLONED_CACHE ]  ||  CLONE_NEEDED=1

if [ $CLONE_NEEDED ]; then
  mkdir -p         $CLONED_CACHE
  git clone $CLONE $CLONED_CACHE
fi


# xxx trigger on main/master branch pushes --> restart docker container
cd $CLONED_CACHE
git pull


# get branch setup if needed.  `cd` into checked out branch dir
if [ -e $DIR ]; then
  BRANCH_NEEDS_SETUP=
  cd $DIR
  git checkout -b $BRANCH 2>/dev/null  ||  git checkout $BRANCH  # xxx necessary?
  git pull || ( git stash && git stash drop|cat && git pull )
else
  BRANCH_NEEDS_SETUP=1
  cp -pr $CLONED_CACHE/ $DIR/
  cd $DIR
  git checkout $BRANCH || git checkout -b $BRANCH # xxx or new unpushed branch
  echo xxx setup watchers on optional file patterns to run sub-steps
fi



# now we have enough information to read any YAML customization

CFG=prevu.yml
[ -e $CFG ]  ||  CFG=/prevu/internetarchive/prevu/main/$GROUP-$REPO.yml # xxx

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


PROXY=$(cfg-val .reverse_proxy)
PORT=
PORTHOST=

if [ "$PROXY" = "" ]; then
  PORT=$(cfg-val .port)

  if [ "$PORT" != "" ]; then
    # container has a static port to serve on -- let's map it to a unique higher 10000+ port

    # see if we already have a port mapping for this project's container
    PROXY=$(grep "# $GROUP-$REPO" /prevu/Caddyfile | grep -Eo "reverse_proxy[^#]+" | tr -s ' ' | cut  -f2 -d ' ')

    if [ "$PROXY" = "" ]; then
      PORTMAX=$(grep reverse_proxy /prevu/Caddyfile | grep -Eo ':1[0-9][0-9][0-9][0-9]' | sort -u | tail -1 | tr -d : | grep . || echo 10000)
      let PORTHOST="1+$PORTMAX"
      PROXY=localhost:$PORTHOST
    else
      PORTHOST=$(echo "$PROXY" | cut -f2 -d :)
    fi
  fi
fi



if [ $CLONE_NEEDED ]; then
  # automatically start docker container & run container setup tasks
  typeset -a ARGS
  ARGS=($(cfg-val .docker.args))

  if [ "$PORTHOST" != "" ]; then
    ARGS+=(-p $PORTHOST:$PORT/tcp)
  fi

  BRANCH_DEFAULT=$(cfg-val .branch.default)
  [ $BRANCH_DEFAULT ]  ||  BRANCH_DEFAULT=$(git rev-parse --abbrev-ref origin/HEAD | cut -f2- -d/)


  # figure out which docker registry to use
  REGISTRY=$REGISTRY_FALLBACK
  [[ $CLONE =~ github.com ]]  &&  REGISTRY=ghcr.io
  [[ $CLONE =~ gitlab.com ]]  &&  REGISTRY=registry.gitlab.com


  IMG=$REGISTRY/$GROUP/$REPO/$BRANCH_DEFAULT
  [[ $CLONE =~ github.com ]]  &&  IMG=$REGISTRY/$GROUP/$REPO:$BRANCH_DEFAULT


  if [ "$GROUP/$REPO" != "internetarchive/prevu" ]; then
    # www-av fails w/o --security-opt arg xxx _could_ move to www-av.yml if the only one...
    docker run -d --restart=always --pull=always -v /prevu/$GROUP/${REPO}:/prevu --name=$GROUP-$REPO \
      --security-opt seccomp=unconfined \
      $ARGS $IMG
    sleep 3
  fi

  (
    IFS=$'\n'
    for CMD in $(cfg-vals .scripts.container.start); do
      docker exec $GROUP-$REPO sh -c "cd /prevu/$BRANCH && $CMD" # xxx prolly should put all cmds into tmp file, pass file in, exec it
    done
  )
fi




if [ $BRANCH_NEEDS_SETUP ]; then
  # now that docker container is up, run any optional initial build step(s) for new branch
  (
    IFS=$'\n'
    for CMD in $(cfg-vals .scripts.branch.start); do
      docker exec $GROUP-$REPO sh -c "cd /prevu/$BRANCH && $CMD" # xxx prolly should put all cmds into tmp file, pass file in, exec it
    done
  )
fi






DOCROOT=$(cfg-val .docroot)
[ "$DOCROOT" = "" ] && DOCROOT=www
[ ! -e $DOCROOT ] && mkdir $DOCROOT && (cd $DOCROOT && wget https://raw.githubusercontent.com/internetarchive/prevu/main/www/index.html )


# now copy edited/save file in place
mkdir -p $(dirname "$FILE")
cat $INCOMING >| "$FILE"
rm -fv $INCOMING # xxx setexit & always remove on errors


IDX=0
while true; do
  TRIGGER=$(cfg-val ".triggers[$IDX].pattern")
  [ "$TRIGGER" = "" ]  &&  break

  echo "$FILE" | grep -qE "$TRIGGER" && (
    CMD=$(cfg-val ".triggers[$IDX].cmd")
    docker exec $GROUP-$REPO sh -c "cd /prevu/$BRANCH && $CMD" # xxx prolly should put all cmds into tmp file, pass file in, exec it
  )

  let "IDX=1+$IDX"
done



# ensure hostname is known to caddy
grep -E "^$HOST {\$" /prevu/Caddyfile  ||  (

   (
    echo "$HOST {"
    if [ "$PROXY" = "" ]; then
      echo "
\troot * $DIR/$DOCROOT
\tfile_server"

    else
      echo "\treverse_proxy  $PROXY # $GROUP-$REPO"
    fi
    echo "}"
  ) | tee -a /prevu/Caddyfile

  docker exec prevu zsh -c '/usr/sbin/caddy reload --config /prevu/Caddyfile'
)

echo "\n\nhttps://$HOST\n\nSUCCESS PREVU\n\n"
