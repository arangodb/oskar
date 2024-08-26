FROM ubuntu:22.04
MAINTAINER Max Neunhoeffer <max@arangodb.com>

ARG ARCH "x86_64"

RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y fish sudo apt-utils debhelper debconf expect rpm createrepo-c  gnupg2 && \
  ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime && \
  dpkg-reconfigure --frontend noninteractive tzdata && \
  apt-get clean

COPY ./scripts /scripts

CMD [ "/usr/bin/fish" ]
