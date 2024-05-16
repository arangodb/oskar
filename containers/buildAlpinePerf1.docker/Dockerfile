FROM alpine:3.18.4 as build

COPY ./scripts /scripts
COPY ./apkbuild /apkbuild
RUN /scripts/install_base.sh
RUN /scripts/setup_apk_building.sh
RUN /scripts/rebuild_gcc.sh
RUN /scripts/build_glibc_string.sh
RUN /scripts/rebuild_musl_perf.sh

FROM alpine:3.18.4 as perfbuild

COPY --from=build /home/arangodb/packages /packages
COPY --from=build /etc/apk/keys /etc/apk/keys
COPY /scripts/install_packages.sh /scripts/install_packages.sh
RUN /scripts/install_packages.sh

FROM perfbuild as beforessl
MAINTAINER Max Neunhoeffer <max@arangodb.com>

ARG ARCH="x86_64"

RUN apk add groff bison flex make cmake python3 git linux-headers vim boost-dev mandoc gdb openssh db-dev file libltdl zlib-dev curl coreutils texinfo py-setuptools libtool nodejs npm py3-psutil && apk add g++ bash liburing-dev clang clang-static clang-dev clang-analyzer llvm lld && apk add ccache ctags fish gcovr valgrind prometheus

RUN apk add py3-pip && pip3 install PyYAML && apk del py3-pip

COPY ./tools/install-poll.sh /tools/
RUN /tools/install-poll.sh

FROM beforessl

MAINTAINER Max Neunhoeffer <max@arangodb.com>

COPY ./tools/install-openssl.sh /tools/
RUN [ "/tools/install-openssl.sh", "3.1", "3" ]

COPY ./tools/install-openldap.sh /tools/
RUN [ "/tools/install-openldap.sh", "3.1.3" ]

RUN curl -L https://github.com/mozilla/sccache/releases/download/v0.3.1/sccache-v0.3.1-${ARCH}-unknown-linux-musl.tar.gz | tar xvz -C /tmp && mv /tmp/sccache-v0.3.1-${ARCH}-unknown-linux-musl/sccache /usr/bin/sccache && chmod +x /usr/bin/sccache && rm -rf /tmp/sccache-v0.3.1-${ARCH}-unknown-linux-musl

RUN apk add py3-pip && pip install gcovr==5 --break-system-packages && apk del py3-pip

COPY ./tools/gcc /tools/
COPY ./tools/g++ /tools/

RUN git config --global --add safe.directory '*'

CMD [ "/usr/bin/fish" ]

