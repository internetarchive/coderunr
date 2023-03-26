#!/bin/zsh -u

# wipes out an entire repo from the coderunr system

# eg: www/av
GROUP_REPO=${1:?"Usage: <group-repo eg: www/av>"}
SLUG=$(echo "$GROUP_REPO" | tr / -)

sudo find /coderunr/$GROUP_REPO -ls -delete
sudo docker stop  $SLUG
sudo docker rm -v $SLUG

fgrep -C 2 $SLUG /coderunr/Caddyfile
