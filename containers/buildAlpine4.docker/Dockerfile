FROM alpine:3.12
MAINTAINER Max Neunhoeffer <max@arangodb.com>

RUN apk update && \
    apk add groff bison flex make cmake ccache python3 git linux-headers vim boost-dev ctags mandoc gdb fish openssh db-dev libexecinfo-dev libexecinfo file libltdl zlib-dev curl coreutils texinfo libexecinfo-static gcovr py-setuptools valgrind libtool g++

COPY ./tools/install-poll.sh /tools/
RUN /tools/install-poll.sh

COPY ./tools/install-openssl.sh /tools/
RUN [ "/tools/install-openssl.sh", "1.1.1", "g" ]
RUN [ "/tools/install-openssl.sh", "1.1.0", "l" ]

COPY ./tools/install-openldap.sh /tools/
RUN [ "/tools/install-openldap.sh", "1.1.1g" ]
RUN [ "/tools/install-openldap.sh", "1.1.0l" ]

RUN curl -L https://github.com/mozilla/sccache/releases/download/0.2.12/sccache-0.2.12-x86_64-unknown-linux-musl.tar.gz | tar xvz -C /tmp && mv /tmp/sccache-0.2.12-x86_64-unknown-linux-musl/sccache /usr/bin/sccache

COPY ./scripts /scripts
COPY ./tools/gcc /tools/
COPY ./tools/g++ /tools/

CMD [ "/usr/bin/fish" ]
