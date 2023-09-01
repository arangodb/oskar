FROM alpine:3.17
MAINTAINER Max Neunhoeffer <hackers@arangodb.com>

ARG ARCH "x86_64"

RUN apk update && \
    apk add groff bison flex make cmake ccache python3 git linux-headers vim boost-dev ctags mandoc gdb fish openssh db-dev file libltdl zlib-dev curl coreutils texinfo gcovr py-setuptools valgrind libtool nodejs npm py3-psutil && apk add g++ prometheus bash liburing-dev

RUN apk add py3-pip && pip3 install PyYAML && apk del py3-pip

COPY ./tools/install-poll.sh /tools/
RUN /tools/install-poll.sh

COPY ./tools/install-openssl.sh /tools/
RUN [ "/tools/install-openssl.sh", "3.1", "2" ]

COPY ./tools/install-openldap.sh /tools/
RUN [ "/tools/install-openldap.sh", "3.1.2" ]

RUN curl -L https://github.com/mozilla/sccache/releases/download/v0.3.1/sccache-v0.3.1-${ARCH}-unknown-linux-musl.tar.gz | tar xvz -C /tmp && mv /tmp/sccache-v0.3.1-${ARCH}-unknown-linux-musl/sccache /usr/bin/sccache && chmod +x /usr/bin/sccache && rm -rf /tmp/sccache-v0.3.1-${ARCH}-unknown-linux-musl

RUN apk add py3-pip && pip install gcovr==5 && apk del py3-pip

COPY ./scripts /scripts
COPY ./tools/gcc /tools/
COPY ./tools/g++ /tools/

RUN git config --global --add safe.directory '*'

CMD [ "/usr/bin/fish" ]
