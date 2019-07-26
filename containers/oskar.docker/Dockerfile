FROM golang:1.10.3-alpine
MAINTAINER ArangoDB <info@arangodb.com>

RUN \
    apk update && \
    apk add openssl-dev python zlib-dev lz4-dev g++ bash musl-dev make gcc git docker fish sudo openssh-client && \
    mkdir -p /usr/src && \
    cd /usr/src && \
    git clone -b v0.11.5 https://github.com/edenhill/librdkafka.git && \
    cd librdkafka && \
    sed -i -e "s|_GNU_SOURCE|_NOT_DEFINED|" "src/rdposix.h" && \
    ./configure --prefix /usr && \
    make && \
    make install

RUN cd / && git clone https://github.com/arangodb/oskar && rm -rf oskar/.git

CMD [ "/usr/bin/fish" ]
