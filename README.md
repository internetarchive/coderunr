# coderunr - website edits live in seconds

# ₀₀₀₁₀₁  ᕕ( ᐛ )ᕗ

## Deploy saved changes to websites -- _without_ commits, pushes & full CI/CD

An opensource project from Internet Archive & tracey.

[Source code](https://github.com/internetarchive/coderunr)

(work in progress)


## From editor save to live website in seconds
- Setup VSCode (or similar) to run a command on every file save.
  - Install `CodeRunr` extension:
    - https://marketplace.visualstudio.com/items?itemName=InternetArchive.coderunr-vscode
    - [source code](https://github.com/internetarchive/coderunr-vscode)
  - This will sync your saved file to your CodeRunr Server
    - It will auto-detect your checked out branch, git clone url, and do various setup, so that you'll get a unique https:// url (with automatic https certs) for each branch.
- Configure VSCode Settings:
  - Change `example.com` to your `ssh`-able CodeRunr Server (see below).
```json
// Change `example.com` to your `ssh`-able CodeRunr Server.
"CodeRunr.server": "example.com",
"CodeRunr.match": "dev/|petabox",
```

### Prerequisites - CodeRunr Server
- An admin needs to do a one-time setup of a DNS wildcard to point to a Virtual Machine that you can `ssh` into.
  - This will be your CodeRunr Server.
  - The CodeRunr Server needs to have `docker` and `git` packages installed.
- The admin runs our container below, but:
  - changes `code.archive.org` to whatever your DNS wildcard domain is.
  - changes `registry.archive.org` to whatever default docker container registry to use, if needed (repos using github.com/gitlab.com will get autodetected).  This is optional -- you can set it to blank `""` empty string.
```sh
docker run -d --net=host --privileged -v /var/run/docker.sock:/var/run/docker.sock --pull=always \
  -e DOMAIN_WILDCARD=code.archive.org \
  -e REGISTRY_FALLBACK=registry.archive.org \
  -v /coderunr:/coderunr --restart=always --name coderunr -d ghcr.io/internetarchive/coderunr:main
```


## Notes
- One docker container per repo, for trigger-based build & incremental build steps
- Option for repo to self-multiplex hostnames => docroots (eg: petabox)
  - this allows for a full custom nginx and/or php webserver stack, etc.

### Progress notes
- Off to a promising start -- basic concept working for static file server with build step and triggered re-build steps
- harder case php fastcgi dual LB/caddy layer idea manual testing seems workable
- user needs to `docker login` (on server running the `[coderunr]` docker image) to any registry they can normally `docker pull` private images from
- if your docker containers are having trouble talking to outside work, check `/etc/default/docker` and try something like `DOCKER_OPTS="--dns 8.8.8.8 --dns 8.8.4.4"` (google public DNS) in case that helps


### Quirks notes
- As of now, the CodeRunr Server needs `yq`.  You can get like this (check https://github.com/mikefarah/yq/releases/latest for alternate OS/ARC if not linux amd64):
```sh
sudo wget -O  /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.30.8/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
- petabox repo needs 8010 UDP ferm port opened.
```



## TODO
- xxx note: file_server std serving option defaultd to no dir listing, but *does* serve DOTFILES
- xxx make `.settings.json` config option for verbose logging (switch to less verbose default)
- xxx commit/push watcher to reset branch (presently does `git pull` on every file saved)
  - wipe local edits for `git push` => `git pull` triggers
- xxx "clone" self locally *first* so repo YML overrides in our dir get used
- xxx make admin script(s) to restart a project (remove dir, docker stop & rm -v, edit Caddyfile)
- xxx make admin script(s) to restart all projects (remove dir, docker stop & rm -v ..) & coderunr
- xxx offshoot triggers
- xxx document repo docroot multiplexing setup
- xxx offshoot multistage build w/ rendertron makes nav...
- xxx document repo-based YAML overrides
- xxx webhooks
  - GL per group
  - GH per organization

## Work in Progress
```bash

# xxx `nom-ssh` variant that `cd` you to proper branch, once inside container, eg:
nomad alloc exec -i -t -task www-av a208c683 zsh -c 'cd /coderunr/main; zsh'

# nom-ssh  (use group-project + branch)
ssh -t -A code 'docker exec -it ia-petabox bash -c "cd /coderunr/master; bash"'

# nom-logs (use group-project)
ssh -t -A code docker logs -f ia-petabox
```
