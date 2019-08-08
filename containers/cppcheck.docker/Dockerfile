FROM alpine:3.10
MAINTAINER Max Neunhoeffer <max@arangodb.com>

COPY ./tools/* /tools/

RUN /tools/install.sh

CMD [ "/usr/bin/fish" ]
