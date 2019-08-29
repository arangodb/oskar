#!/bin/sh
set -e

# Compile openssl library:
export OPENSSLVERSION=$1
test -n "$OPENSSLVERSION"
export OPENSSLPATH=`echo $OPENSSLVERSION | tr -d "a-zA-Z"`
cd /tmp
curl -O https://www.openssl.org/source/openssl-$OPENSSLVERSION.tar.gz
tar xzvf openssl-$OPENSSLVERSION.tar.gz
cd openssl-$OPENSSLVERSION
./config --prefix=/opt/openssl-$OPENSSLPATH no-async no-shared
make build_libs
make install_dev
cd /tmp
rm -rf openssl-$OPENSSLVERSION.tar.gz openssl-$OPENSSLVERSION
