FROM debian:buster
MAINTAINER ArangoDB Hackers <hacker@arangodb.com>

#set proper shell
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# install base dependencies
RUN apt-get update && apt-get install -y -q --no-install-recommends \
        apt-transport-https \
        build-essential \
        ca-certificates \
        gnupg2 \
        libssl-dev \
        wget \
        curl \
        tar \
        git \
        rsync \
        parallel \
        tree \
        jq \
        && apt-get clean

## install packages for python
RUN apt-get update && apt-get install -y -q --no-install-recommends \
        python \
        python-setuptools \
        python-pip \
        python-argparse \
        && apt-get clean

RUN apt-get update && apt-get install -y -q --no-install-recommends \
        python3 \
        python3-setuptools \
        python3-pip \
        python3-configargparse \
        && apt-get clean

RUN echo "deb http://apt.llvm.org/buster/ llvm-toolchain-buster main" >> /etc/apt/sources.list; \
    echo "deb-src http://apt.llvm.org/buster/ llvm-toolchain-buster main" >> /etc/apt/sources.list

RUN echo "deb http://apt.llvm.org/buster/ llvm-toolchain-buster-8 main" >> /etc/apt/sources.list; \
    echo "deb-src http://apt.llvm.org/buster/ llvm-toolchain-buster-8 main" >> /etc/apt/sources.list

RUN wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -

RUN apt-get update && apt-get install -y -q --no-install-recommends \
        cmake \
        clang-8 \
        clang-format-8 \
        clang-tools-8 \
        && apt-get clean

#arango extra libs
RUN apt-get update && apt-get install -y -q --no-install-recommends \
        libldap2-dev \
        && apt-get clean

## set env
ENV ARANGO_INSTALL "/install"
ENV HOME "$ARANGO_INSTALL"
RUN mkdir "$ARANGO_INSTALL" && chmod 777 "$ARANGO_INSTALL"

## other setup - ditaa, lockfile, bash_lib
COPY setup /setup
RUN /setup

WORKDIR "$ARANGO_INSTALL"

## setup entrypoint
COPY entrypoint /entrypoint
ENTRYPOINT [ "/entrypoint" ]
