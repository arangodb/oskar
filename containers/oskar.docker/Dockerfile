ARG ARCH=
FROM ${ARCH}ubuntu

MAINTAINER ArangoDB <info@arangodb.com>

RUN apt update && \
    apt upgrade --yes && \
    apt install --yes \
                apt-transport-https && \
    apt install --yes \
                apt-utils \
		bash-completion \
		cpufrequtils \
		curl \
		docker.io \
		fish \
		sudo \
		vim \
		wget


copy entrypoint.sh /

ENTRYPOINT [ "/entrypoint.sh" ]
