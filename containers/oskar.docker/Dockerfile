FROM ubuntu:18.04
MAINTAINER ArangoDB <info@arangodb.com>

RUN apt-get update && \
    apt-get install -y software-properties-common && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y git fish sudo curl unzip docker.io psmisc make gcc pkg-config librdkafka-dev && \
    apt-get clean && \
    (cd /tmp ; curl -O https://dl.google.com/go/go1.12.6.linux-amd64.tar.gz) && \
    (cd /tmp ; tar -xf go1.12.6.linux-amd64.tar.gz) && \
    (cd /tmp ; mv go /usr/local)

RUN cd / && git clone https://github.com/arangodb/oskar && rm -rf oskar/.git

CMD [ "/usr/bin/fish" ]
