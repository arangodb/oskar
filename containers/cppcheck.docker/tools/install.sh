#!/bin/sh
set -e

# Install some packages:
apk update
apk add groff g++ make curl fish bash pcre-dev python

# Compile openssl1.1 library:
export CPPCHECK_VERSION=1.88
cd /tmp
curl -L -O https://github.com/danmar/cppcheck/archive/$CPPCHECK_VERSION.tar.gz
tar xzvf $CPPCHECK_VERSION.tar.gz
cd cppcheck-1.88
make -j 16 MATCHCOMPILER=yes HAVE_RULES=yes CFGDIR=/usr/share/cppcheck/
make install CFGDIR=/usr/share/cppcheck/
cd /tmp
#rm -rf $CPPCHECK_VERSION.tar.gz cppcheck-$CPPCHECK_VERSION
