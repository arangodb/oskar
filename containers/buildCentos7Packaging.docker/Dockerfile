FROM centos:7
MAINTAINER Max Neunhoeffer <max@arangodb.com>

ARG ARCH "x86_64"

RUN yum update -y && yum install -y gcc make rpm-build wget && cd /etc/yum.repos.d && wget http://download.opensuse.org/repositories/shells:fish:release:3/CentOS_7/shells:fish:release:3.repo && yum update -y && yum install -y fish

RUN yum install -y elfutils-libelf-devel git && git clone -b dwz-0.14 git://sourceware.org/git/dwz.git && pushd dwz && ./configure && make && make install && popd

RUN yum remove -y fipscheck fipscheck-lib libedit openssh openssh-clients perl-Error perl-Git perl-TermReadKey rsync git && rm -rf dwz

COPY ./scripts /scripts

CMD [ "/bin/bash" ]
