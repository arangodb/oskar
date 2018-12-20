FROM ubuntu:18.04
MAINTAINER Max Neunhoeffer <max@arangodb.com>

RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y fish sudo apt-utils debhelper debconf expect rpm createrepo gnupg2 && \
  ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime && \
  dpkg-reconfigure --frontend noninteractive tzdata && \
  apt-get clean

COPY ./scripts /scripts

CMD [ "/usr/bin/fish" ]
