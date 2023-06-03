FROM ubuntu:22.04
MAINTAINER Max Neunhoeffer <max@arangodb.com>

ARG ARCH "x86_64"

ENV COMPILER_VERSION 11

ENV CLANG_VERSION 14

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update --fix-missing && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get upgrade -y --fix-missing && \
    apt-get install -y build-essential gcc-${COMPILER_VERSION} g++-${COMPILER_VERSION} cmake make bison flex python3 ccache git libjemalloc-dev vim exuberant-ctags gdb fish psmisc sudo debhelper debconf jq wget libdb-dev curl gnupg2 gcovr prometheus bc tcpdump python3.11 python3.11-venv && apt-get clean 

RUN curl -L https://github.com/mozilla/sccache/releases/download/v0.2.15/sccache-v0.2.15-${ARCH}-unknown-linux-musl.tar.gz | tar xvz -C /tmp && mv /tmp/sccache-v0.2.15-${ARCH}-unknown-linux-musl/sccache /usr/bin/sccache && chmod +x /usr/bin/sccache && rm -rf /tmp/sccache-v0.2.15-${ARCH}-unknown-linux-musl

COPY ./tools/* /tools/

RUN [ "/tools/install.sh", "1.1.1", "u" ]

RUN [ "/tools/install.sh", "3.0", ".9" ]

RUN [ "/tools/install.sh", "3.1", ".1" ]

COPY ./scripts /scripts

RUN export LC_ALL="C" && wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | sudo apt-key add - && add-apt-repository -s "deb http://apt.llvm.org/jammy/ llvm-toolchain-jammy-${CLANG_VERSION} main" && apt install -y clang-${CLANG_VERSION} lldb-${CLANG_VERSION} lld-${CLANG_VERSION} libc++-${CLANG_VERSION}-dev libc++abi-${CLANG_VERSION}-dev libclang-common-${CLANG_VERSION}-dev libclang-rt-${CLANG_VERSION}-dev

RUN update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-${CLANG_VERSION} 100 && update-alternatives --install /usr/bin/clang clang /usr/bin/clang-${CLANG_VERSION} 100

RUN LC_ALL="C" update-ccache-symlinks

RUN git config --global --add safe.directory '*'

RUN python3.11 -m ensurepip
RUN pip3.11 install py7zr psutil
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 110 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 100 && \
    echo 2 | update-alternatives --config python3


CMD [ "/usr/bin/fish" ]
