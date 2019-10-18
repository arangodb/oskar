FROM alpine:3.10
MAINTAINER Max Neunhoeffer <max@arangodb.com>

RUN apk update && \
    apk add groff

RUN apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/main g++

RUN apk add bison flex make cmake ccache python git linux-vanilla-dev linux-headers vim boost-dev ctags man gdb fish openssh db-dev libexecinfo-dev libexecinfo file libltdl zlib-dev curl coreutils texinfo libexecinfo-static gcovr py-setuptools valgrind libtool


COPY ./tools/install-poll.sh /tools/
RUN /tools/install-poll.sh

COPY ./tools/install-openssl.sh /tools/
RUN [ "/tools/install-openssl.sh", "1.1.1d" ]
RUN [ "/tools/install-openssl.sh", "1.1.0l" ]

COPY ./tools/install-openldap.sh /tools/
RUN [ "/tools/install-openldap.sh", "1.1.1d" ]
RUN [ "/tools/install-openldap.sh", "1.1.0l" ]

COPY ./scripts /scripts

CMD [ "/usr/bin/fish" ]
