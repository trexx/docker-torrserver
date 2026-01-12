# Source
FROM busybox:1-uclibc AS source

RUN mkdir /tmp/src
RUN wget -qO- https://github.com/YouROK/TorrServer/archive/refs/tags/MatriX.136.tar.gz | tar --strip-components=1 -xzv -C /tmp/src

# # Remove telebot
COPY ./patches /tmp/patches
RUN rm -rf /tmp/src/server/tgbot
RUN patch /tmp/src/server/server.go /tmp/patches/remove_tgtoken.patch
RUN patch /tmp/src/server/cmd/main.go /tmp/patches/main.patch

# Frontend
FROM node:16-alpine AS front

COPY --from=source /tmp/src/web /tmp/src

WORKDIR /tmp/src/

RUN --mount=type=cache,target=/usr/local/share/.cache/yarn \ 
  yarn install

RUN yarn run build

# Server
FROM golang:1.23-alpine AS server

COPY --from=source /tmp/src /tmp/src
COPY --from=front /tmp/src/build /tmp/src/web/build

WORKDIR /tmp/src

RUN apk add --no-cache --update g++
RUN --mount=type=cache,target=/root/.cache/go-build go run gen_web.go

WORKDIR /tmp/src/server

RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
  CGO_ENABLED=0 go build -ldflags '-w -s' -tags=nosqlite -trimpath --o "torrserver" ./cmd 

# Final
FROM gcr.io/distroless/static@sha256:cd64bec9cec257044ce3a8dd3620cf83b387920100332f2b041f19c4d2febf93
LABEL org.opencontainers.image.source="https://github.com/trexx/docker-torrserver"

COPY --from=server /tmp/src/server/torrserver /torrserver

ENTRYPOINT ["/torrserver"]
