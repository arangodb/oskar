FROM alpine:3.10
MAINTAINER Max Neunhoeffer <max@arangodb.com>

RUN apk update && apk add git bash fish curl openssh coreutils jq

COPY ./scripts /scripts

CMD [ "/usr/bin/fish" ]
