FROM ubuntu:18.04
MAINTAINER Max Neunhoeffer <max@arangodb.com>

ARG ARCH "x86_64"

ENV COMPILER_VERSION 9

ENV CLANG_VERSION 12

RUN apt-get update --fix-missing && \
    apt-get install -y software-properties-common && \
    add-apt-repository -y ppa:ubuntu-toolchain-r/test && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y build-essential gcc-${COMPILER_VERSION} g++-${COMPILER_VERSION} cmake make bison flex python3-psutil python3-distutils ccache git libjemalloc-dev vim exuberant-ctags gdb fish psmisc sudo debhelper debconf jq wget libdb-dev curl gnupg2 gcovr prometheus tcpdump &&\
    apt-get clean

RUN curl -L https://github.com/mozilla/sccache/releases/download/v0.2.15/sccache-v0.2.15-${ARCH}-unknown-linux-musl.tar.gz | tar xvz -C /tmp && mv /tmp/sccache-v0.2.15-${ARCH}-unknown-linux-musl/sccache /usr/bin/sccache && chmod +x /usr/bin/sccache && rm -rf /tmp/sccache-v0.2.15-${ARCH}-unknown-linux-musl

COPY ./tools/* /tools/

RUN [ "/tools/install.sh", "1.1.1", "s" ]

COPY ./scripts /scripts

RUN export LC_ALL="C" && wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | sudo apt-key add - && add-apt-repository -s "deb http://apt.llvm.org/bionic/ llvm-toolchain-bionic-${CLANG_VERSION} main" && apt install -y clang-${CLANG_VERSION} lldb-${CLANG_VERSION} lld-${CLANG_VERSION} libc++-${CLANG_VERSION}-dev libc++abi-${CLANG_VERSION}-dev

RUN update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-${CLANG_VERSION} 100 && update-alternatives --install /usr/bin/clang clang /usr/bin/clang-${CLANG_VERSION} 100

RUN LC_ALL="C" update-ccache-symlinks

RUN git config --global --add safe.directory /work/ArangoDB
RUN git config --global --add safe.directory /work/ArangoDB/enterprise
RUN git config --global --add safe.directory /work/ArangoDB/docs

CMD [ "/usr/bin/fish" ]
