FROM alpine

RUN apk add zsh caddy

WORKDIR /app
COPY . .

CMD /app/watcher.sh
