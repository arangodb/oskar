#!/bin/sh
set -e

# Compile openssl library:
export OPENSSLBRANCH=$1
export OPENSSLPATCH=$2
export OPENSSLVERSION="${OPENSSLBRANCH}.${OPENSSLPATCH}"

echo $OPENSSLBRANCH

if [ "$OPENSSLBRANCH" != "3.1" ]; then
  OLD="old/${OPENSSLBRANCH}/"
fi;

echo "https://www.openssl.org/source/${OLD}openssl-$OPENSSLVERSION.tar.gz"

test -n "$OPENSSLVERSION"
export OPENSSLPATH=`echo $OPENSSLVERSION | sed 's/\.[0-9]*$//g'`
cd /tmp
curl -O https://www.openssl.org/source/${OLD}openssl-$OPENSSLVERSION.tar.gz
tar xzvf openssl-$OPENSSLVERSION.tar.gz
cd openssl-$OPENSSLVERSION
export CC=clang-16
export CXX=clang++-16
./config --prefix=/opt/openssl-$OPENSSLPATH no-async no-shared
make build_libs
make install_dev
cd /tmp
rm -rf openssl-$OPENSSLVERSION.tar.gz openssl-$OPENSSLVERSION
