#!/bin/sh
set -e

# Install some packages:
apk update
apk add groff g++ make curl fish bash pcre-dev python

# Compile openssl1.1 library:
export CPPCHECK_VERSION=1.89
cd /tmp
curl -L -O https://github.com/danmar/cppcheck/archive/$CPPCHECK_VERSION.tar.gz
tar xzvf $CPPCHECK_VERSION.tar.gz
cd cppcheck-$CPPCHECK_VERSION
make -j $(nproc) MATCHCOMPILER=yes HAVE_RULES=yes FILESDIR=/usr/share/cppcheck/
make install FILESDIR=/usr/share/cppcheck/
cd /tmp
#rm -rf $CPPCHECK_VERSION.tar.gz cppcheck-$CPPCHECK_VERSION
