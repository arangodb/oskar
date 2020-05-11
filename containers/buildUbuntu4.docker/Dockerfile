FROM ubuntu:20.04
MAINTAINER Max Neunhoeffer <max@arangodb.com>

ENV COMPILER_VERSION 9

RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:jonathonf/gcc-9.2 \
    add-apt-repository ppa:ubuntu-toolchain-r \
    apt-get update \
    apt-get upgrade -y

RUN apt-get install -y build-essential gcc-${COMPILER_VERSION} g++-${COMPILER_VERSION} cmake make bison flex python ccache git libjemalloc-dev vim exuberant-ctags gdb fish ruby ruby-httparty ruby-rspec psmisc sudo debhelper debconf jq wget libdb-dev curl gnupg2 && gem install persistent_httparty && apt-get clean

COPY ./tools/* /tools/

RUN [ "/tools/install.sh", "1.1.1", "g" ]

COPY ./scripts /scripts

CMD [ "/usr/bin/fish" ]
