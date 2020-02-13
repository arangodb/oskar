FROM alpine:3.11
MAINTAINER Max Neunhoeffer <max@arangodb.com>

RUN apk update && \
    apk add groff g++ bison flex make cmake ccache python git linux-vanilla linux-headers vim boost-dev ctags man gdb fish openssh db-dev libexecinfo-dev libexecinfo file libltdl zlib-dev curl coreutils texinfo libexecinfo-static gcovr py-setuptools valgrind libtool

COPY ./tools/install-poll.sh /tools/
RUN /tools/install-poll.sh

COPY ./tools/install-openssl.sh /tools/
RUN [ "/tools/install-openssl.sh", "1.1.1d" ]
RUN [ "/tools/install-openssl.sh", "1.1.0l" ]

COPY ./tools/install-openldap.sh /tools/
RUN [ "/tools/install-openldap.sh", "1.1.1d" ]
RUN [ "/tools/install-openldap.sh", "1.1.0l" ]

RUN curl -L https://github.com/mozilla/sccache/releases/download/0.2.12/sccache-0.2.12-x86_64-unknown-linux-musl.tar.gz | tar xvz -C /tmp && mv /tmp/sccache-0.2.12-x86_64-unknown-linux-musl/sccache /usr/bin/sccache

COPY ./scripts /scripts
COPY ./tools/gcc /tools/
COPY ./tools/g++ /tools/

CMD [ "/usr/bin/fish" ]
