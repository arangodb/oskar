#!/bin/sh
mkdir -p aports/core/glibc-string
cd aports/core/glibc-string
cp /apkbuild/APKBUILD.glibc-string APKBUILD
abuild -r
