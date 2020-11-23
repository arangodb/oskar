FROM ubuntu:18.04
MAINTAINER Max Neunhoeffer <max@arangodb.com>

ENV COMPILER_VERSION 9

RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:jonathonf/gcc-9.2 && \
    add-apt-repository ppa:ubuntu-toolchain-r && \
    apt-get update && \
    apt-get upgrade -y

RUN apt-get install -y build-essential gcc-${COMPILER_VERSION} g++-${COMPILER_VERSION} cmake make bison flex python ccache git libjemalloc-dev vim exuberant-ctags gdb fish ruby ruby-httparty ruby-rspec psmisc sudo debhelper debconf jq wget libdb-dev curl gnupg2 gcovr && gem install persistent_httparty && apt-get clean

RUN curl -L https://github.com/mozilla/sccache/releases/download/0.2.12/sccache-0.2.12-x86_64-unknown-linux-musl.tar.gz | tar xvz -C /tmp && mv /tmp/sccache-0.2.12-x86_64-unknown-linux-musl/sccache /usr/bin/sccache

COPY ./tools/* /tools/

RUN [ "/tools/install.sh", "1.1.1", "h" ]

COPY ./scripts /scripts

CMD [ "/usr/bin/fish" ]
