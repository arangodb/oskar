#!/bin/sh
set -e

# Install some packages:
apk update
apk add groff g++ bison flex make cmake ccache python libldap git linux-vanilla-dev linux-headers vim boost-dev ctags man gdb fish openssh db-dev libexecinfo-dev libexecinfo file libltdl zlib-dev curl coreutils texinfo

# Compile openssl1.1 library:
export OPENSSLVERSION=1.1.0k
cd /tmp
curl -O https://www.openssl.org/source/openssl-$OPENSSLVERSION.tar.gz
tar xzvf openssl-$OPENSSLVERSION.tar.gz
cd openssl-$OPENSSLVERSION
./config --prefix=/usr no-async
make build_libs
make install_dev
cd /tmp
rm -rf openssl-$OPENSSLVERSION.tar.gz openssl-$OPENSSLVERSION

# Compile openldap library:
export OPENLDAPVERSION=2.4.46
cd /tmp
curl -O ftp://ftp.openldap.org/pub/OpenLDAP/openldap-release/openldap-$OPENLDAPVERSION.tgz
tar xzvf openldap-$OPENLDAPVERSION.tgz
cd openldap-$OPENLDAPVERSION
cp -a /tools/config.* ./build
./configure --prefix=/usr --enable-static
make depend && make -j64
make install
cd /tmp
rm -rf openldap-$OPENLDAPVERSION.tgz openldap-$OPENLDAPVERSION

# Make some warnings go away:
echo "#include <poll.h>" > /usr/include/sys/poll.h
