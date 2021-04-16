FROM alpine:3.12
MAINTAINER Max Neunhoeffer <max@arangodb.com>

RUN apk update && \
    apk add groff bison flex make cmake ccache python3 git linux-headers vim boost-dev ctags mandoc gdb fish openssh db-dev libexecinfo-dev libexecinfo file libltdl zlib-dev curl coreutils texinfo libexecinfo-static gcovr py-setuptools valgrind libtool nodejs npm prometheus && \
    apk add g++ --repository=http://dl-cdn.alpinelinux.org/alpine/v3.12/main

RUN ln -s /usr/bin/python3 /usr/bin/python

COPY ./tools/install-poll.sh /tools/
RUN /tools/install-poll.sh

COPY ./tools/install-openssl.sh /tools/
RUN [ "/tools/install-openssl.sh", "1.1.1", "k" ]

COPY ./tools/install-openldap.sh /tools/
RUN [ "/tools/install-openldap.sh", "1.1.1k" ]

RUN curl -L https://github.com/mozilla/sccache/releases/download/v0.2.15/sccache-v0.2.15-x86_64-unknown-linux-musl.tar.gz | tar xvz -C /tmp && mv /tmp/sccache-v0.2.15-x86_64-unknown-linux-musl/sccache /usr/bin/sccache && chmod +x /usr/bin/sccache && rm -rf /tmp/sccache-v0.2.15-x86_64-unknown-linux-musl

COPY ./scripts /scripts
COPY ./tools/gcc /tools/
COPY ./tools/g++ /tools/

CMD [ "/usr/bin/fish" ]
