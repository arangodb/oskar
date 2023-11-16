#!/bin/sh
cd $HOME
tar xzvf /apkbuild/aports_main_gcc.tar.gz
cd aports/main/gcc
export LANG_CXX=true
export LANG_D=false
export LANG_OBJC=false
export LANG_GO=false
export LANG_FORTRAN=false
export LANG_ADA=false
export LANG_JIT=false
abuild -r
rm -rf pkg src
