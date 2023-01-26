FROM alpine
# FROM python:3-alpine # xxx for pyinotify.py

RUN apk add zsh caddy
# RUN wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.30.8/yq_linux_amd64 && chmod +x /usr/local/bin/yq # xxx if yq from inside prevu..

WORKDIR /app
COPY . .

CMD [ "/app/watcher.sh" ]
