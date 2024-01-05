#!/bin/sh
cd $HOME
tar xzvf /apkbuild/aports_main_musl.tar.gz
cd aports/main/musl
abuild -r
