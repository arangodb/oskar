FROM fedora:43
MAINTAINER Max Neunhoeffer <max@arangodb.com>

ARG ARCH "x86_64"

RUN yum update -y && yum install -y gcc make rpm-build wget fish elfutils-libelf-devel git dwz

RUN yum remove -y fipscheck fipscheck-lib libedit openssh openssh-clients perl-Error perl-Git perl-TermReadKey rsync git

COPY ./scripts /scripts

CMD [ "/bin/bash" ]
