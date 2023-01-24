# prevu - website edits live in seconds

## Deploy saved changes to website "preview apps" -- _without_ commits, pushes & full CI/CD

work-in-progress


## From editor save to live website in seconds
- Setup a DNS wildcard to a Virtual Machine that you can `ssh` into, with `docker`.
  - VM will need `git` pkg installed.
- Run our container below, but:
  - change `code.archive.org` to whatever your DNS wildcard domain is.
  - change `registry.archive.org` to whatever default docker container registry to use (github.com/gitlab.com will get autodetected)
```sh
docker run -d --net=host --privileged -v /var/run/docker.sock:/var/run/docker.sock --pull=always \
  -e DOMAIN_WILDCARD=code.archive.org \
  -e REGISTRY_FALLBACK=registry.archive.org \
  -v /prevu:/prevu -v /tmp:/xxx/tmp -v /etc/caddy:/etc/caddy \
  --restart=always --name prevu -d ghcr.io/internetarchive/prevu:main
```
- Setup VSCode (or similar) to run a command on every file save.
  - Install 'Run on Save' extension -- use this link since there are 2+ such named extensions (!)
    - https://marketplace.visualstudio.com/items?itemName=pucelle.run-on-save
    - [source code](https://github.com/pucelle/vscode-run-on-save)
- Configure VSCode Settings:
  - Change `example.com` to your `ssh`-able `docker` VM
```json
// Change `example.com` to your `ssh`-able `docker` VM server.
"runOnSave.statusMessageTimeout": 600000, // allow up to 10 minutes to first-time git clone & setup
"runOnSave.commands": [{
  "match": "/dev/", // change to local filename/dir pattern that you'd like using prevu.
  // Determine workspace's git clone url and git branch; send with saved file contents to server.
  "command": "cd '${workspaceFolder}'  &&  (git config --get remote.origin.url && git rev-parse --abbrev-ref HEAD && cat '${file}') | ssh example.com 'export INCOMING=$(mktemp) REPO=${workspaceFolderBasename} FILE=${fileRelative}  &&  cat >| $INCOMING  &&  /prevu/deploy.sh'  &&  echo SUCCESS",
  "runIn": "backend", // backend|vscode|terminal
  "runningStatusMessage": "🔺🔺🔺 SAVING 🔺🔺🔺",
  "finishStatusMessage": "Saved ✅",
}
```


## Notes
- One docker container per repo, for trigger-based build & incremental build steps
- Option for repo to self-multiplex hostnames => docroots (eg: petabox)
  - this allows for a full custom nginx and/or php webserver stack, etc.

### Progress notes
- Off to a promising start -- basic concept working for static file server with build step and triggered re-build steps
- harder case php fastcgi dual LB/caddy layer idea manual testing seems workable
- user needs to `docker login` (on code.ao, etc.) to any registry they can normally `docker pull` private images from
- if your docker containers are having trouble talking to outside work, check `/etc/default/docker` and try something like `DOCKER_OPTS="--dns 8.8.8.8 --dns 8.8.4.4"` (google public DNS) in case that helps


### Quirks notes
- petabox repo needs 8010 UDP ferm port opened.
- As of now, VM running docker `[prevu]` container needs `yq`.  You can get like this (check https://github.com/mikefarah/yq/releases/latest for alternate OS/ARC if not linux amd64):
```sh
sudo wget -O  /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.30.8/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```



## TODO
- xxx commit/push watcher to reset branch (presently does `git pull` on every file saved)
  - wipe local edits for `git push` => `git pull` triggers
- xxx webhooks
  - GL per group
  - GH per organization (!)

## Work in Progress
```bash

# xxx `nom-ssh` variant that `cd` you to proper branch, once inside container, eg:
nomad alloc exec -i -t -task www-av a208c683 zsh -c 'cd /prevu/main; zsh'

# nom-ssh  (use group-project + branch)
ssh -t -A code 'docker exec -it ia-petabox bash -c "cd /prevu/master; bash"'

# nom-logs (use group-project)
ssh -t -A code docker logs -f ia-petabox
```
