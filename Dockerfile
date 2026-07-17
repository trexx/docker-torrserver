# Source
FROM busybox:1-uclibc AS source

RUN mkdir /tmp/src
RUN wget -qO- https://github.com/YouROK/TorrServer/archive/refs/tags/MatriX.142.1.tar.gz | tar --strip-components=1 -xzv -C /tmp/src

# Frontend
FROM node:16-alpine AS front

COPY --from=source /tmp/src/web /tmp/src

WORKDIR /tmp/src/

RUN --mount=type=cache,target=/usr/local/share/.cache/yarn \ 
  yarn install

RUN yarn run build

# Server
FROM golang:1.26-alpine@sha256:0178a641fbb4858c5f1b48e34bdaabe0350a330a1b1149aabd498d0699ff5fb2 AS server

COPY --from=source /tmp/src /tmp/src
COPY --from=front /tmp/src/build /tmp/src/web/build

WORKDIR /tmp/src

RUN --mount=type=cache,target=/root/.cache/go-build go run gen_web.go

WORKDIR /tmp/src/server

RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
  CGO_ENABLED=0 go build -ldflags '-w -s' -tags=nosqlite -trimpath --o "torrserver" ./cmd

# Final
FROM scratch AS compile
LABEL org.opencontainers.image.source="https://github.com/trexx/docker-torrserver"

COPY --from=server /tmp/src/server/torrserver /torrserver

ENTRYPOINT ["/torrserver"]
