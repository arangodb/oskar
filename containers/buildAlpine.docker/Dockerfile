FROM alpine:3.7
MAINTAINER Max Neunhoeffer <max@arangodb.com>

RUN apk update && \
    apk add groff g++ bison flex make cmake ccache python libldap git linux-vanilla-dev linux-headers vim boost-dev ctags man gdb fish openssh db-dev libexecinfo-dev libexecinfo file libltdl zlib-dev curl coreutils texinfo gcovr py-setuptools

COPY ./tools/install-poll.sh /tools/
RUN /tools/install-poll.sh

COPY ./tools/install-openssl.sh /tools/
RUN [ "/tools/install-openssl.sh", "1.1.1c" ]
RUN [ "/tools/install-openssl.sh", "1.1.0k" ]

COPY ./tools/install-openldap.sh /tools/
RUN [ "/tools/install-openldap.sh", "1.1.1c" ]
RUN [ "/tools/install-openldap.sh", "1.1.0k" ]

COPY ./scripts /scripts

CMD [ "/usr/bin/fish" ]
