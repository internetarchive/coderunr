FROM alpine

RUN apk add zsh

WORKDIR /app
COPY . .

CMD /app/watcher.sh
