FROM denoland/deno:alpine

# `coreutils` for `env -S`
RUN apk add  bash zsh coreutils caddy

WORKDIR /app
COPY . .

# USER deno
CMD [ "/app/entrypoint.sh" ]
