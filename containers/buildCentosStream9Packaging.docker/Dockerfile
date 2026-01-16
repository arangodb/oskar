FROM quay.io/centos/centos:stream9-minimal
MAINTAINER Max Neunhoeffer <max@arangodb.com>

ARG ARCH "x86_64"

RUN microdnf upgrade -y && \
    microdnf install -y epel-release && \
    microdnf install -y gcc make rpm-build wget fish dwz && \
    microdnf clean all

COPY ./scripts /scripts

CMD [ "/bin/bash" ]
