# FROM bitwalker/alpine-elixir:1.6.6
# RUN apk add bash imagemagick curl gcc make libc-dev libgcc && rm -rf /var/cache/apk/*

# ENV HOME=/opt/app/ SHELL=/bin/bash MIX_ENV=prod
# WORKDIR /opt/build

# # Cache dependencies
# COPY mix.exs mix.lock ./
# COPY apps/cf/mix.exs ./apps/cf/
# COPY apps/cf_atom_feed/mix.exs ./apps/cf_atom_feed/
# COPY apps/cf_graphql/mix.exs ./apps/cf_graphql/
# COPY apps/cf_jobs/mix.exs ./apps/cf_jobs/
# COPY apps/cf_opengraph/mix.exs ./apps/cf_opengraph/
# COPY apps/cf_rest_api/mix.exs ./apps/cf_rest_api/
# COPY apps/db/mix.exs ./apps/db/
# RUN HEX_HTTP_CONCURRENCY=4 HEX_HTTP_TIMEOUT=180 mix deps.get

# # Build dependencies
# COPY . .
# RUN mix deps.compile

# # Build app
# ARG APP
# RUN mix release --name ${APP} --env=$MIX_ENV

# # Copy app to workdir and remove build files
# WORKDIR /opt/app
# RUN mv /opt/build/_build/$MIX_ENV/rel/${APP}/* /opt/app/
# RUN rm -rf /opt/build
# RUN ln -s /opt/app/bin/${APP} bin/entrypoint

# EXPOSE 80
# ENTRYPOINT ["./bin/entrypoint"]



# docker build -t faithful_word:builder --target=builder .

FROM elixir:1.7.4-alpine as builder
RUN apk add --no-cache \
    gcc \
    git \
    make \
    musl-dev
RUN mix local.rebar --force && \
    mix local.hex --force
WORKDIR /app
ENV MIX_ENV=prod

# docker build -t faithful_word:deps --target=deps .
FROM builder as deps
COPY mix.* /app/
# Explicit list of umbrella apps
RUN mkdir -p \
    /app/apps/faithful_word \
    /app/apps/cf_rest_api
COPY apps/faithful_word/mix.* /app/apps/faithful_word/
COPY apps/cf_rest_api/mix.* /app/apps/cf_rest_api/
RUN mix do deps.get --only prod, deps.compile

# docker build -t faithful_word:frontend --target=frontend .
FROM node:10.14-alpine as frontend
WORKDIR /app
COPY apps/cf_rest_api/assets/package*.json /app/
COPY --from=deps /app/deps/phoenix /deps/phoenix
COPY --from=deps /app/deps/phoenix_html /deps/phoenix_html
RUN npm ci
COPY apps/cf_rest_api/assets /app
RUN npm run deploy

# docker build -t faithful_word:releaser --target=releaser .
FROM deps as releaser
COPY . /app/
COPY --from=frontend /priv/static apps/cf_rest_api/priv/static
RUN mix do phx.digest, release --env=prod --no-tar

# docker run -it --rm elixir:1.7.3-alpine sh -c 'head -n1 /etc/issue'
FROM alpine:3.8 as runner
RUN addgroup -g 1000 faithful_word && \
    adduser -D -h /app \
      -G faithful_word \
      -u 1000 \
      faithful_word
RUN apk add -U bash libssl1.0
USER root
WORKDIR /app
COPY --from=releaser /app/_build/prod/rel/captain_fact_umbrella /app
EXPOSE 80
ENTRYPOINT ["/app/bin/captain_fact_umbrella"]
CMD ["foreground"]
