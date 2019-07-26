FROM golang:1.10.3-alpine
MAINTAINER ArangoDB <info@arangodb.com>

RUN \
    apk update && \
    apk add openssl-dev python zlib-dev lz4-dev g++ bash musl-dev make gcc git docker fish sudo openssh-client

RUN cd / && git clone https://github.com/arangodb/oskar && rm -rf oskar/.git

CMD [ "/usr/bin/fish" ]
