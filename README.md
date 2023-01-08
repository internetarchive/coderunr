# prevu - website edits live in seconds

## Deploy saved changes to website "preview apps" -- _without_ commits, pushes & full CI/CD

work-in-progress


## From editor save to live website in seconds
- Setup a DNS wildcard to a Virtual Machine that you can `ssh` into, with `docker`.
  - VM will need `git` pkg installed.
- Run our container (xxx)
```sh
docker run -d --net=host --privileged -v /var/run/docker.sock:/var/run/docker.sock \
  -v /prevu:/prevu -v /etc/caddy/Caddyfile:/etc/caddy/Caddyfile \
  --restart=always --name prevu -d ghcr.io/internetarchive/prevu:main
```
- Setup VSCode (or similar) to run a command on every file save.
  - Install 'Run on Save' extension -- use this link since there are 2+ such named extensions (!)
    - https://marketplace.visualstudio.com/items?itemName=pucelle.run-on-save
    - [source code](https://github.com/pucelle/vscode-run-on-save)
- Configure VSCode Settings:
  - Change `example.com` to your `ssh`-able `docker` VM
```json
"runOnSave.statusMessageTimeout": 600000, // 10 minutes
"runOnSave.commands": [{
  "match": "/dev/",
  "command": "cd '${workspaceFolder}'  &&  (git config --get remote.origin.url && git rev-parse --abbrev-ref HEAD && cat '${file}') | ssh example.com 'export INCOMING=$(mktemp) REPO=${workspaceFolderBasename} FILE=${fileRelative}  &&  cat >| $INCOMING  &&  /prevu/deploy.sh'  &&  echo SUCCESS",
  "runIn": "backend", // backend|vscode|terminal
  "runningStatusMessage": "🔺🔺🔺 SAVING 🔺🔺🔺",
  "finishStatusMessage": "Saved ✅",
  "async": false,
}
```


## Notes
* Off to a promising start -- basic concept working for static file server with build step and triggered re-build steps
* harder case php fastcgi dual LB/caddy layer idea manual testing seems workable


## TODO
- xxx commit/push watcher to reset branch (presently does `git pull` on every file saved)
  - wipe local edits for `git push` => `git pull` triggers
- xxx triggers
- xxx one docker container per repo, for trigger-based build & incremental build steps
- xxx option for repo to self-multiplex hostnames => docroots (eg: petabox)
  - this allows for a full custom nginx and/or php webserver stack, etc.
