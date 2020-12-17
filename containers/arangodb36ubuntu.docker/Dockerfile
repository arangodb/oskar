FROM ubuntu:18.04
MAINTAINER Max Neunhoeffer <max@arangodb.com>

ENV COMPILER_VERSION 9

RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:ubuntu-toolchain-r && \
    add-apt-repository ppa:ubuntu-toolchain-r/test && \
    apt-get update && \
    apt-get upgrade -y

RUN apt-get install -y git libjemalloc-dev vim gdb fish sudo jq wget curl libatomic1 gcc-${COMPILER_VERSION} g++-${COMPILER_VERSION} graphviz ghostscript psmisc

# only if foxx is requires
# apt-get install -y nodejs npm && npm install -g foxx-cli && apt remove npm && apt autoremove

ADD install.tar.gz /
COPY setup.sh /setup.sh
RUN /setup.sh && rm /setup.sh

ENV GLIBCXX_FORCE_NEW=1

COPY entrypoint.sh /entrypoint.sh
RUN ["chmod", "+x", "/entrypoint.sh"]
ENTRYPOINT [ "/entrypoint.sh" ]

EXPOSE 8529
CMD ["arangod"]
