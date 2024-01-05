#!/bin/sh
set -e

export OPENSSLVERSION=$1
test -n "$OPENSSLVERSION"
export OPENSSLPATH=`echo $OPENSSLVERSION | sed 's/\.[0-9]*$//g'`

# Compile openldap library:
export OPENLDAPVERSION=2.6.6
cd /tmp
curl -O ftp://ftp.openldap.org/pub/OpenLDAP/openldap-release/openldap-$OPENLDAPVERSION.tgz
tar xzf openldap-$OPENLDAPVERSION.tgz
cd openldap-$OPENLDAPVERSION
# cp -a /tools/config.* ./build
[ "$ARCH" = "x86_64" ] && X86_64_SUFFIX="64"
CC=clang-16 \
CXX=clang++-16 \
CPPFLAGS=-I/opt/openssl-$OPENSSLPATH/include \
LDFLAGS=-L/opt/openssl-$OPENSSLPATH/lib$X86_64_SUFFIX \
./configure --prefix=/opt/openssl-$OPENSSLPATH --with-threads --with-tls=openssl --enable-static --disable-shared
make depend && make -j64
make install
cd /tmp
rm -rf openldap-$OPENLDAPVERSION.tgz openldap-$OPENLDAPVERSION

