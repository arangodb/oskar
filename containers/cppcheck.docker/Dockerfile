FROM alpine:3.18
MAINTAINER Max Neunhoeffer <max@arangodb.com>

ARG ARCH "x86_64"

COPY ./tools/* /tools/

RUN /tools/install.sh

CMD [ "/usr/bin/fish" ]
