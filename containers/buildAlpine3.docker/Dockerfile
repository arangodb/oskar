FROM alpine:3.11
MAINTAINER Max Neunhoeffer <max@arangodb.com>

ARG ARCH "x86_64"

RUN apk update && \
    apk add groff g++ bison flex make cmake ccache python python3 git linux-headers vim boost-dev ctags man gdb fish openssh db-dev libexecinfo-dev libexecinfo file libltdl zlib-dev curl coreutils texinfo libexecinfo-static gcovr py-setuptools valgrind libtool nodejs npm

COPY ./tools/install-poll.sh /tools/
RUN /tools/install-poll.sh

COPY ./tools/install-openssl.sh /tools/
RUN [ "/tools/install-openssl.sh", "1.1.1", "o" ]

COPY ./tools/install-openldap.sh /tools/
RUN [ "/tools/install-openldap.sh", "1.1.1o" ]

RUN curl -L https://github.com/mozilla/sccache/releases/download/v0.2.15/sccache-v0.2.15-${ARCH}-unknown-linux-musl.tar.gz | tar xvz -C /tmp && mv /tmp/sccache-v0.2.15-${ARCH}-unknown-linux-musl/sccache /usr/bin/sccache && chmod +x /usr/bin/sccache && rm -rf /tmp/sccache-v0.2.15-${ARCH}-unknown-linux-musl

RUN apk add py3-pip && pip3 install gcovr==5 && apk del py3-pip

COPY ./scripts /scripts
COPY ./tools/gcc /tools/
COPY ./tools/g++ /tools/

RUN git config --global --add safe.directory /work/ArangoDB
RUN git config --global --add safe.directory /work/ArangoDB/enterprise
RUN git config --global --add safe.directory /work/ArangoDB/docs

CMD [ "/usr/bin/fish" ]
