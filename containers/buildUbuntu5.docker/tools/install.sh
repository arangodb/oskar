#!/bin/sh

# Set links for GCC
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-${COMPILER_VERSION} 10 \
	--slave /usr/bin/gcc-ar gcc-ar /usr/bin/gcc-ar-${COMPILER_VERSION} \
  --slave /usr/bin/gcc-nm gcc-nm /usr/bin/gcc-nm-${COMPILER_VERSION} \
  --slave /usr/bin/gcc-ranlib gcc-ranlib /usr/bin/gcc-ranlib-${COMPILER_VERSION} \
  --slave /usr/bin/gcov gcov /usr/bin/gcov-${COMPILER_VERSION}

update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-${COMPILER_VERSION} 10

update-alternatives --install /usr/bin/cc cc /usr/bin/gcc 30
update-alternatives --set cc /usr/bin/gcc

update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++ 30
update-alternatives --set c++ /usr/bin/g++

# Compile openssl library:
export OPENSSLBRANCH=$1
export OPENSSLREVISION=$2
export OPENSSLVERSION=${OPENSSLBRANCH}${OPENSSLREVISION}

if [ "$OPENSSLBRANCH" != "1.1.1" ]; then
  OLD="old/${OPENSSLBRANCH}/"
fi;

export OPENSSLPATH=`echo $OPENSSLVERSION | tr -d "a-zA-Z"`
cd /tmp
curl -O https://www.openssl.org/source/openssl-$OPENSSLVERSION.tar.gz
tar xzf openssl-$OPENSSLVERSION.tar.gz
cd openssl-$OPENSSLVERSION
./config --prefix=/opt/openssl-$OPENSSLPATH no-async no-dso
make
make install_dev
cd /tmp
rm -rf openssl-$OPENSSLVERSION.tar.gz openssl-$OPENSSLVERSION

# Compile openldap library:
export OPENLDAPVERSION=2.6.6
cd /tmp
curl -O ftp://ftp.openldap.org/pub/OpenLDAP/openldap-release/openldap-$OPENLDAPVERSION.tgz
tar xzf openldap-$OPENLDAPVERSION.tgz
cd openldap-$OPENLDAPVERSION
CPPFLAGS=-I/opt/openssl-$OPENSSLPATH/include \
LDFLAGS=-L/opt/openssl-$OPENSSLPATH/lib \
./configure -prefix=/opt/openssl-$OPENSSLPATH --enable-static
make depend && make -j64
make install
cd /tmp
rm -rf openldap-$OPENLDAPVERSION.tgz openldap-$OPENLDAPVERSION

# Clean up any strange cores
rm -rf /core.*
