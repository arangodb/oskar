FROM alpine:3.9
MAINTAINER Max Neunhoeffer <max@arangodb.com>

COPY ./tools/* /tools/

RUN /tools/install.sh

RUN apk add valgrind

COPY ./scripts /scripts

CMD [ "/usr/bin/fish" ]
