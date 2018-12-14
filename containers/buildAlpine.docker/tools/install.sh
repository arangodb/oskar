#!/bin/sh
set -e

# Install some packages:
apk update
apk add groff g++ bison flex make cmake ccache python libldap git linux-vanilla-dev linux-headers vim boost-dev ctags man gdb fish openssh db-dev libexecinfo-dev libexecinfo file libltdl zlib-dev curl coreutils texinfo

# Compile newer GCC versions
mkdir /gcc

for v in 7.3.0 8.2.0; do
    mkdir /tmp/gcc
    cd /tmp/gcc
    wget https://ftp.gnu.org/gnu/gcc/gcc-$v/gcc-$v.tar.gz
    tar xzvf gcc-$v.tar.gz
    cd gcc-$v
    ./contrib/download_prerequisites
    cd ..
    mkdir objdir
    cd objdir
    ./../gcc-$v/configure --prefix=/gcc/$v --build=x86_64-alpine-linux-musl --host=x86_64-alpine-linux-musl --target=x86_64-alpine-linux-musl --with-pkgversion="Alpine $v" --enable-checking=release --disable-fixed-point --disable-libstdcxx-pch --disable-multilib --disable-nls --disable-werror --disable-symvers --enable-__cxa_atexit --enable-default-pie --enable-cloog-backend --enable-languages=c,c++ --disable-libssp --disable-libmpx --disable-libmudflap --disable-libsanitizer --enable-shared --enable-threads --enable-tls --with-system-zlib --with-linker-hash-style=gnu
    make -j 64 all
    make install

    for file in gcc g++; do
        (
	    cd /usr/bin
            ln -s /gcc/$v/bin/$file $file-$v

	    cd /usr/lib/ccache/bin
	    ln -s /usr/bin/ccache $file-$v
	)
    done

    cd /tmp
    rm -rf gcc
done
    
# Compile openssl1.1 library:
export OPENSSLVERSION=1.1.0j
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
