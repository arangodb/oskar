FROM alpine:3.13
MAINTAINER Max Neunhoeffer <hackers@arangodb.com>

ARG ARCH "x86_64"

RUN apk update && \
    apk add groff bison flex make cmake ccache python3 git linux-headers vim boost-dev ctags mandoc gdb fish openssh db-dev libexecinfo-dev libexecinfo file libltdl zlib-dev curl coreutils texinfo libexecinfo-static gcovr py-setuptools valgrind libtool nodejs npm && apk add g++ prometheus py3-psutil

RUN ln -s /usr/bin/python3 /usr/bin/python

RUN apk add py3-pip && pip3 install PyYAML && apk del py3-pip

COPY ./tools/install-poll.sh /tools/
RUN /tools/install-poll.sh

COPY ./tools/install-openssl.sh /tools/
RUN [ "/tools/install-openssl.sh", "1.1.1", "v" ]

COPY ./tools/install-openldap.sh /tools/
RUN [ "/tools/install-openldap.sh", "1.1.1v" ]

RUN curl -L https://github.com/mozilla/sccache/releases/download/v0.2.15/sccache-v0.2.15-${ARCH}-unknown-linux-musl.tar.gz | tar xvz -C /tmp && mv /tmp/sccache-v0.2.15-${ARCH}-unknown-linux-musl/sccache /usr/bin/sccache && chmod +x /usr/bin/sccache && rm -rf /tmp/sccache-v0.2.15-${ARCH}-unknown-linux-musl

RUN apk add py3-pip && pip install gcovr==5 && apk del py3-pip

COPY ./scripts /scripts
COPY ./tools/gcc /tools/
COPY ./tools/g++ /tools/

RUN git config --global --add safe.directory /work/ArangoDB
RUN git config --global --add safe.directory /work/ArangoDB/enterprise
RUN git config --global --add safe.directory /work/ArangoDB/docs

RUN git config --global --add safe.directory /work/ArangoDB/3rdParty/fmt
RUN git config --global --add safe.directory /work/ArangoDB/3rdParty/iresearch
RUN git config --global --add safe.directory /work/ArangoDB/3rdParty/rocksdb
RUN git config --global --add safe.directory /work/ArangoDB/3rdParty/velocypack

CMD [ "/usr/bin/fish" ]
