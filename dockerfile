FROM alpine

RUN apk --no-cache add bmake libarchive-tools e2fsprogs

RUN mkdir /smolBSD

WORKDIR /smolBSD
