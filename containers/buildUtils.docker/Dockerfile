FROM alpine:3.24
LABEL org.opencontainers.image.authors="hackers@arangodb.com"

ARG ARCH "x86_64"

RUN apk update && apk add git bash fish curl openssh coreutils jq
# The work tree mounts are owned by the host user while git runs as root
# in here; git >= 2.35.2 refuses that ("dubious ownership") without this.
RUN git config --system --add safe.directory '*'


COPY ./scripts /scripts

CMD [ "/usr/bin/fish" ]
