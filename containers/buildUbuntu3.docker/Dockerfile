FROM ubuntu:18.04
MAINTAINER Max Neunhoeffer <max@arangodb.com>

ENV COMPILER_VERSION 9

RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:ubuntu-toolchain-r/test && \
    apt-get update && \
    apt-get upgrade -y

RUN apt-get install -y build-essential gcc-${COMPILER_VERSION} g++-${COMPILER_VERSION} cmake make bison flex python ccache git libjemalloc-dev vim exuberant-ctags gdb fish ruby ruby-httparty ruby-rspec psmisc sudo debhelper debconf jq wget libdb-dev curl gnupg2 gcovr && gem install persistent_httparty && apt-get clean

RUN curl -L https://github.com/mozilla/sccache/releases/download/v0.2.15/sccache-v0.2.15-x86_64-unknown-linux-musl.tar.gz | tar xvz -C /tmp && mv /tmp/sccache-v0.2.15-x86_64-unknown-linux-musl/sccache /usr/bin/sccache && chmod +x /usr/bin/sccache && rm -rf /tmp/sccache-v0.2.15-x86_64-unknown-linux-musl

COPY ./tools/* /tools/

RUN [ "/tools/install.sh", "1.1.1", "k" ]

COPY ./scripts /scripts

CMD [ "/usr/bin/fish" ]
