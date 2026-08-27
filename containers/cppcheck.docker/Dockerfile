FROM alpine:3.24
LABEL org.opencontainers.image.authors="hackers@arangodb.com"

ARG ARCH "x86_64"

COPY ./tools/* /tools/

RUN /tools/install.sh

CMD [ "/usr/bin/fish" ]
