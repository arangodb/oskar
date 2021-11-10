FROM alpine:3.10
MAINTAINER Max Neunhoeffer <max@arangodb.com>

ARG ARCH "x86_64"

RUN apk update && apk add git bash fish curl openssh coreutils jq

COPY ./scripts /scripts

CMD [ "/usr/bin/fish" ]
