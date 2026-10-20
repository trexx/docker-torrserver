# Source
FROM busybox:1-uclibc AS source

RUN mkdir /tmp/src
RUN wget -qO- https://github.com/YouROK/TorrServer/archive/refs/tags/MatriX.147.tar.gz | tar --strip-components=1 -xzv -C /tmp/src

# Frontend
FROM node:16-alpine AS front

COPY --from=source /tmp/src/web /tmp/src

WORKDIR /tmp/src/

RUN --mount=type=cache,target=/usr/local/share/.cache/yarn \ 
  yarn install

RUN yarn run build

# Server
FROM golang:1.27-alpine@sha256:f2c872bcee949b7be9c490efd02b48a8a2fbf947cdf533f1c58525ec9d8170fd AS server

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
